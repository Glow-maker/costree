"""Offline syntax + forbidden-write check. Requires pglast; NEVER connects to DB.
The parser is modern PostgreSQL, not a PG9.2/GaussDB execution guarantee.
"""
from pathlib import Path
import json
import re
from pglast import parser

root=Path(__file__).resolve().parent
mapping=(root/'source-mapping.sql').read_text(encoding='utf-8')
results=[]
for f in sorted((root/'templates').glob('*.sql')):
    text=f.read_text(encoding='utf-8')
    text=text.replace('__TENANT_ID__','124').replace('__BATCH_CODE__','STATIC-AUDIT').replace('__SNAPSHOT_TAG__','STATIC-SNAPSHOT')
    for table in re.findall(r'-- BEGIN SOURCE (stg_\w+)',mapping):
        sql=re.search(r'-- BEGIN SOURCE '+table+r'\s+([\s\S]*?)-- END SOURCE '+table,mapping)[1]
        sql=sql.replace('<源系统schema>','source_fixture').replace('cost_sync_stage.','cost_sync_stage_v20261009.')
        text=text.replace('__SOURCE_'+table+'__',sql).replace('__COUNT_'+table+'__','1')
    ast=parser.parse_sql(text)
    dos=re.findall(r'DO \$\$[\s\S]*?END \$\$;',text)
    for do in dos: parser.parse_plpgsql_json(do)
    assert not re.search(r'(?:DELETE\s+FROM|TRUNCATE(?:\s+TABLE)?)\s+"?costree_mvp"?\.',text,re.I),f.name
    if 'setval(' in text:
        assert 'IF v_next<=v_max THEN' in text
        assert 'GREATEST(v_last,v_max)::bigint,true' in text
        assert text.index('IN SHARE ROW EXCLUSIVE MODE') < text.index('setval(')
    if f.name.startswith('90-'):
        assert len(re.findall(r'^BEGIN;$',text,re.M))==1
        assert len(re.findall(r'^COMMIT;$',text,re.M))==1
        assert not re.search(r'\b(INSERT\s+INTO|UPDATE|DELETE\s+FROM)\s+"costree_mvp"\.(cost_project_basic|cost_warning_record|cost_user_\w+|cost_auth_\w+)',text,re.I)
        for match in re.finditer(r'UPDATE "costree_mvp"\.(\w+) \w+\nSET ([\s\S]*?)\nFROM',text):
            table,sets=match.groups()
            columns=set(re.findall(r'(?:^|,)\s*(\w+)\s*=',sets))
            assert 'id' not in columns and 'deleted' not in columns,(table,columns)
            if table=='cost_unit_cost_detail':
                assert not columns.intersection({'target_cost_amount','approved_amount','book_cost_amount','salary_amount','material_amount','remark'})
            if table=='cost_work_order':
                assert not columns.intersection({'product_target_cost','contract_amount','income_amount','approved_amount','stage_codes','max_stage_code','subsystem_name','product_short_name','quantity','vertical_division','status','remark'})
    results.append({'file':f.name,'sql_statements':len(ast),'plpgsql_blocks':len(dos),'status':'PASS'})
report={'status':'PASS','checks':results,'boundary':'静态SQL和PL/pgSQL语法、禁写与事务结构检查；未连接数据库。现代PostgreSQL解析器不等于PG9.2/GaussDB/云鲸2.2.1运行验收。'}
(root/'static-validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))
