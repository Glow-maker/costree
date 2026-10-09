"""SHELL daily path: one psql session/REPEATABLE READ transaction, not cross-node tx.
Without --execute only writes SQL; no database connection.
Use PGHOST/PGPORT/PGDATABASE/PGUSER or PGSERVICE + protected .pgpass for credentials.
"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import json
import re
import subprocess
import uuid

ROOT=Path(__file__).resolve().parent
TABLES=['stg_model_node','stg_project','stg_unit_dict','stg_unit_amount','stg_work_order','stg_ledger_detail']

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--config',required=True,type=Path)
    p.add_argument('--out',required=True,type=Path,help='Existing audit parent; a unique batch directory is created')
    p.add_argument('--psql',default='psql')
    p.add_argument('--execute',action='store_true')
    p.add_argument('--initialize',action='store_true',help='Explicit first-time staging setup; NOT needed for daily runs')
    p.add_argument('--source-readiness',type=Path,default=ROOT/'source-readiness.sql')
    a=p.parse_args()
    cfg=json.loads(a.config.read_text(encoding='utf-8-sig'))
    if cfg.get('source_mapping_confirmed') is not True:
        raise ValueError('尚未确认源字段映射，不生成执行SQL；核对后设置source_mapping_confirmed=true')
    for k in ['business_schema','stage_schema','source_schema']:
        if not isinstance(cfg[k],str) or not re.fullmatch(r'[a-z][a-z0-9_]{0,62}',cfg[k]):
            raise ValueError(k+': 必须适配实际小写 schema')
    if len({cfg[k] for k in ['business_schema','stage_schema','source_schema']})!=3:
        raise ValueError('源/中间/业务 schema 必须隔离')
    if type(cfg['tenant_id']) is not int or cfg['tenant_id']<=0: raise ValueError('错误tenant_id')
    batch='COST-'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')+'-'+uuid.uuid4().hex[:12]
    tag='DBTX-'+batch
    source=(ROOT/'source-mapping.sql').read_text(encoding='utf-8-sig')
    sources={}; counts={}
    for table in TABLES:
        m=re.search(r'-- BEGIN SOURCE '+table+r'\s+([\s\S]*?)-- END SOURCE '+table,source)
        if not m: raise ValueError('缺少源映射 '+table)
        sql=re.sub(r'--[^\n]*','',m[1]).strip().replace('<源系统schema>',cfg['source_schema'])
        if sql.count(';')!=1 or not sql.endswith(';') or re.search(r'\b(DELETE|TRUNCATE|UPDATE|DROP|ALTER|COMMIT|BEGIN)\b',sql,re.I):
            raise ValueError(table+': 只允许一条中间表 INSERT...SELECT')
        select=re.fullmatch(r'INSERT\s+INTO\s+cost_sync_stage\.'+table+r'\s*\([^)]*\)\s*(SELECT[\s\S]*);',sql,re.I)
        if not select: raise ValueError(table+': 保留 INSERT 列清单，只编辑 SELECT 来源')
        sources[table]=sql.replace('cost_sync_stage.',cfg['stage_schema']+'.')
        counts[table]='(SELECT count(*) FROM ('+select[1]+') source_count)'
    readiness=re.sub(r'--[^\n]*','',a.source_readiness.read_text(encoding='utf-8-sig')).strip()
    readiness=readiness.replace('<源系统schema>',cfg['source_schema'])
    if readiness.count(';')!=1 or not re.match(r'SELECT\b',readiness,re.I) or re.search(r'\b(DELETE|TRUNCATE|UPDATE|DROP|ALTER|COMMIT|BEGIN)\b',readiness,re.I):
        raise ValueError('source-readiness.sql 必须为一条只读 SELECT')
    if 'REPLACE_WITH' in readiness or '<源系统schema>' in readiness:
        raise ValueError('source-readiness.sql 尚未映射上游完成证据；禁止生成可执行日常任务')
    def render(text):
        text=text.replace('costree_mvp',cfg['business_schema']).replace('cost_sync_stage_v20261009',cfg['stage_schema'])
        text=text.replace('__TENANT_ID__',str(cfg['tenant_id'])).replace('__BATCH_CODE__',batch).replace('__SNAPSHOT_TAG__',tag)
        for table in TABLES:
            text=text.replace('__SOURCE_'+table+'__',sources[table]).replace('__COUNT_'+table+'__',counts[table])
        return text
    folder=a.out/batch
    folder.mkdir(parents=True,exist_ok=False)
    setup=folder/'00-setup.sql'
    setup.write_text(render((ROOT/'templates/00-setup.sql').read_text(encoding='utf-8')),encoding='utf-8')
    script='''-- Generated daily execution. Do not split statements across connections.
BEGIN ISOLATION LEVEL REPEATABLE READ;
SET LOCAL statement_timeout='30min';
LOCK TABLE __STAGE__.sync_control IN EXCLUSIVE MODE;
CREATE TEMP TABLE cost_source_publication ON COMMIT DROP AS
__READINESS__
DO $$ BEGIN
 IF (SELECT count(*) FROM cost_source_publication)<>1 OR EXISTS(
    SELECT 1 FROM cost_source_publication WHERE is_complete IS DISTINCT FROM true
      OR snapshot_tag IS NULL OR btrim(snapshot_tag)='' OR length(snapshot_tag)>128 OR snapshot_tag LIKE 'REPLACE%') THEN
   RAISE EXCEPTION '上游完整发布证据缺失/不完整，所有业务保持原样；先适配source-readiness.sql';
 END IF;
END $$;
'''.replace('__STAGE__',cfg['stage_schema']).replace('__READINESS__',readiness)
    names=['10-begin-batch.sql']+[next((ROOT/'templates').glob(f'{21+i}-*.sql')).name for i in range(6)]+['90-atomic-sync.template.sql','95-missing-report.sql']
    for name in names:
        text=render((ROOT/'templates'/name).read_text(encoding='utf-8'))
        text=re.sub(r'^BEGIN;\s*','',text,flags=re.M)
        text=re.sub(r'^COMMIT;\s*','',text,flags=re.M)
        script+='\n-- NODE '+name+'\n'+text
        if name=='10-begin-batch.sql':
            script+='\nUPDATE '+cfg['stage_schema']+'.batch_register SET snapshot_tag=(SELECT snapshot_tag FROM cost_source_publication) WHERE batch_code=\''+batch+'\';\n'
    script+='\nSELECT snapshot_tag AS upstream_snapshot,is_complete FROM cost_source_publication;\nCOMMIT;\n'
    sqlfile=folder/'daily-atomic.sql'
    sqlfile.write_text(script,encoding='utf-8')
    result={'batch_code':batch,'database_snapshot_tag':tag,'execution_requested':a.execute,
      'business_schema':cfg['business_schema'],'stage_schema':cfg['stage_schema'],
      'boundary':'SQL生成不代表数据库已执行。最终 SUCCESS 以psql exit=0和日志中的事务提交为准。'}
    if a.execute:
        for file in ([setup] if a.initialize else [])+[sqlfile]:
            with (folder/(file.stem+'.log')).open('w',encoding='utf-8') as log:
                proc=subprocess.run([a.psql,'-X','-v','ON_ERROR_STOP=1','-f',str(file)],stdout=log,stderr=subprocess.STDOUT)
            result[file.name+'_exit_code']=proc.returncode
            if proc.returncode!=0:
                result['status']='FAILED'
                (folder/'result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
                raise SystemExit(proc.returncode)
        result['status']='SUCCESS'
    else: result['status']='RENDERED_ONLY'
    (folder/'result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False))
    print(folder.resolve())

if __name__=='__main__': main()
