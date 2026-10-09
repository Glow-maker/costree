"""Render editable SQL node files only. Never connects to a database.
Usage: python render-workflow.py --config config.json --out generated/BATCH
Only config.json and source-mapping.sql are operator-editable inputs.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parent

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', required=True, type=Path)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    cfg = json.loads(args.config.read_text(encoding='utf-8-sig'))
    if cfg.get('source_mapping_confirmed') is not True:
        raise ValueError('需先核对源表/字段/金额单位/稳定源ID，再将 source_mapping_confirmed 设为 true')
    for k in ['business_schema', 'stage_schema', 'source_schema']:
        value = cfg[k]
        if not isinstance(value, str) or not re.fullmatch(r'[a-z][a-z0-9_]{0,62}', value):
            raise ValueError(k + ': 必须填写实际小写 schema，不允许占位或 SQL 片段')
    if len({cfg[k] for k in ['business_schema','stage_schema','source_schema']}) != 3:
        raise ValueError('源、业务、中间层 schema 必须隔离')
    if type(cfg['tenant_id']) is not int or cfg['tenant_id'] <= 0:
        raise ValueError('tenant_id 必须为现场确认的正整数')
    for k, maxlen in [('batch_code',64),('snapshot_tag',128)]:
        v=cfg[k]
        if not isinstance(v,str) or v.startswith('REPLACE') or not re.fullmatch(r'[A-Za-z0-9_.:-]{1,'+str(maxlen)+'}',v):
            raise ValueError(k+': 必须确认真实、唯一的批次/一致快照标识')
    mapping=(ROOT/'source-mapping.sql').read_text(encoding='utf-8-sig')
    source={}
    tables=['stg_model_node','stg_project','stg_unit_dict','stg_unit_amount','stg_work_order','stg_ledger_detail']
    for table in tables:
        count=cfg['expected_rows'][table]
        if type(count) is not int or count<0:
            raise ValueError(table+': expected_rows 必须填完整快照经核实的行数，不能用 null 代替')
        if table in ('stg_model_node','stg_project','stg_unit_dict') and count==0:
            raise ValueError(table+': 基础全量快照不允许为空')
        m=re.search(r'-- BEGIN SOURCE '+table+r'\s+([\s\S]*?)-- END SOURCE '+table,mapping)
        if not m: raise ValueError('缺少源映射块 '+table)
        sql=m[1].strip().replace('<源系统schema>',cfg['source_schema'])
        clean=re.sub(r'--[^\n]*','',sql)
        # Deliberately restrict source adapters to one INSERT...SELECT. No hidden cleanup/update.
        if clean.count(';')!=1 or not clean.rstrip().endswith(';') or not re.match(
            r'\s*INSERT\s+INTO\s+cost_sync_stage\.'+table+r'\s*\(',clean,re.I):
            raise ValueError(table+': 源块只能是一条指定中间表的 INSERT...SELECT')
        if re.search(r'\b(DELETE|TRUNCATE|UPDATE|DROP|ALTER|COMMIT|BEGIN)\b',clean,re.I):
            raise ValueError(table+': 源块含非装载语句')
        source[table]=sql.replace('cost_sync_stage.',cfg['stage_schema']+'.')
    args.out.mkdir(parents=True,exist_ok=False)
    files=[]
    for file in sorted((ROOT/'templates').glob('*.sql')):
        text=file.read_text(encoding='utf-8')
        text=text.replace('costree_mvp',cfg['business_schema']).replace('cost_sync_stage_v20261009',cfg['stage_schema'])
        for k in ['tenant_id','batch_code','snapshot_tag']:
            text=text.replace('__'+k.upper()+'__',str(cfg[k]))
        for table in tables:
            text=text.replace('__SOURCE_'+table+'__',source[table])
            text=text.replace('__COUNT_'+table+'__',str(cfg['expected_rows'][table]))
        if re.search(r'__[A-Za-z0-9_]+__|REPLACE_WITH|<源系统schema>',text):
            raise ValueError(file.name+': 仍有占位符，禁止部署')
        target=args.out/file.name.replace('.template','')
        target.write_text(text,encoding='utf-8')
        files.append({'file':target.name,'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
    (args.out/'manifest.json').write_text(json.dumps({'config':cfg,'files':files,
       'boundary':'SQL files generated only; no DB execution or source mapping verification performed'},ensure_ascii=False,indent=2),encoding='utf-8')
    print('SQL已生成，未执行数据库：',args.out.resolve())

if __name__=='__main__':
    main()
