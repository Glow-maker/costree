"""No DB: exercise configuration refusal and real daily SQL rendering/parsing."""
from pathlib import Path
import json
import re
import subprocess
import sys
import tempfile
from pglast import parser

ROOT=Path(__file__).resolve().parent
checks=[]
with tempfile.TemporaryDirectory(prefix='cost-workflow-render-') as tmp:
    tmp=Path(tmp)
    def run(script,*args):
        return subprocess.run([sys.executable,str(ROOT/script),*map(str,args)],capture_output=True,text=True,encoding='utf-8',errors='replace')
    bad=run('daily-runner.py','--config',ROOT/'config.example.json','--out',tmp/'unmapped')
    assert bad.returncode!=0 and not (tmp/'unmapped').exists()
    checks.append({'name':'unconfirmed_mapping_refused_before_output','status':'PASS'})
    cfg=json.loads((ROOT/'config.example.json').read_text(encoding='utf-8'))
    cfg.update(business_schema='cost_render_business',stage_schema='cost_render_stage',source_schema='cost_render_source',source_mapping_confirmed=True)
    config=tmp/'config.json';config.write_text(json.dumps(cfg),encoding='utf-8')
    bad=run('daily-runner.py','--config',config,'--out',tmp/'unready')
    assert bad.returncode!=0 and not (tmp/'unready').exists()
    checks.append({'name':'placeholder_upstream_readiness_refused_before_output','status':'PASS'})
    ready=tmp/'fixture-readiness.sql'
    ready.write_text("SELECT 'SYNTHETIC-RENDER-ONLY'::text AS snapshot_tag,true::boolean AS is_complete;",encoding='utf-8')
    cmd=['--config',config,'--source-readiness',ready,'--out',tmp/'runs','--psql','PSQL_MUST_NOT_BE_CALLED']
    for _ in range(2):
        result=run('daily-runner.py',*cmd)
        assert result.returncode==0,result.stderr
    folders=list((tmp/'runs').iterdir());assert len(folders)==2
    for folder in folders:
        report=json.loads((folder/'result.json').read_text(encoding='utf-8'))
        assert report['status']=='RENDERED_ONLY' and report['execution_requested'] is False
        text=(folder/'daily-atomic.sql').read_text(encoding='utf-8')
        assert len(re.findall(r'^BEGIN ISOLATION LEVEL REPEATABLE READ;$',text,re.M))==1
        assert len(re.findall(r'^COMMIT;$',text,re.M))==1
        assert 'NODE 95-missing-report.sql' in text
        assert 'batch_register SET snapshot_tag=(SELECT snapshot_tag FROM cost_source_publication)' in text
        assert not re.search(r'__(?:BATCH|SOURCE|COUNT|TENANT|SNAPSHOT)\w*__',text)
        parser.parse_sql(text)
        for do in re.findall(r'DO \$\$[\s\S]*?END \$\$;',text): parser.parse_plpgsql_json(do)
    checks.append({'name':'daily_unique_batch_no_database_single_repeatable_read_transaction','status':'PASS'})
    cfg.update(batch_code='STATIC-RENDER-ONE',snapshot_tag='SYNTHETIC-RENDER-ONLY',expected_rows={k:1 for k in cfg['expected_rows']})
    config.write_text(json.dumps(cfg),encoding='utf-8')
    rendered=run('render-workflow.py','--config',config,'--out',tmp/'nodes')
    assert rendered.returncode==0,rendered.stderr
    for file in (tmp/'nodes').glob('*.sql'): parser.parse_sql(file.read_text(encoding='utf-8'))
    checks.append({'name':'all_sql_nodes_render_with_explicit_batch_counts','status':'PASS'})
report={'status':'PASS','checks':checks,'boundary':'使用合成配置与只读SQL模拟上游完成标记，仅生成/解析文件，psql未被调用。未证明真实源映射、PG9.2/GaussDB或云鲸节点运行。'}
(ROOT/'runner-smoke-result.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))
