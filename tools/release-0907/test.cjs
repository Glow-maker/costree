const fs=require('fs'),path=require('path'),assert=require('assert'),cp=require('child_process'),vm=require('vm')
const {templates,withoutTransactions}=require('./generate.cjs'),{render}=require('./parameter-runtime.js')
const dir=path.resolve(__dirname,'../../.release-0907-validation/generated')
const qaDb='release0907qa_'+Date.now()
cp.execFileSync('docker',['exec','costree-release-0907-pg92','createdb','-U','postgres',qaDb])
fs.mkdirSync(dir,{recursive:true})
const params={tenant:'124',cost:'public',dm:'MQB',prefix:'',cacheMode:'tenant'}
const rendered=render(templates,params)
for(const [name,sql] of Object.entries(rendered)){assert(!sql.includes('@@'));fs.writeFileSync(path.join(dir,name),sql)}
for(const input of [{tenant:''},{tenant:'1;DROP'},{cost:'public;DROP'},{dm:'MQB\"'},{prefix:'*'},{cacheMode:''}])assert.throws(()=>render(templates,{...params,...input}))
assert(rendered['06-中台验收与缓存清单.sql'].includes("'permission_menu_ids:'"))
assert(rendered['06-中台验收与缓存清单.sql'].includes("'role:124:'"))
assert.equal(withoutTransactions('BEGIN;\nDO $$\nBEGIN\nEND $$;\nCOMMIT;'),'DO $$\nBEGIN\nEND $$;')
const html=fs.readFileSync(path.join(dir,'部署参数生成器.html'),'utf8')
for(const match of html.matchAll(/<script>([\s\S]*?)<\/script>/g))new vm.Script(match[1])
function psql(sql,ok=true){const result=cp.spawnSync('docker',['exec','-i','costree-release-0907-pg92','psql','-X','-v','ON_ERROR_STOP=1','-U','postgres','-d',qaDb],{input:sql,encoding:'utf8',maxBuffer:12e6});fs.appendFileSync(path.join(dir,'pg92-test.log'),result.stdout+'\n'+result.stderr);if(ok&&result.status!==0)throw Error(result.stderr.slice(-4500));if(!ok)assert.notEqual(result.status,0);return result}
psql(fs.readFileSync(path.resolve(__dirname,'../../../sqlbot_with_bcback/baback/sql/postgresql92/costree-cost.sql'),'utf8'))
const fixture=`
INSERT INTO cost_project(id,project_code,project_name,tenant_id,project_office_status) VALUES(1,'QA-0907','release validation',124,'SUBMITTED');
INSERT INTO cost_project_basic(project_id,project_code,tenant_id,user_name,stage_code,product_short_name,status,basic_info) VALUES(1,'QA-0907',124,'manual customer','M,Z','manual model','SUBMITTED','keep description');
INSERT INTO cost_unit_cost_detail(project_id,project_code,unit_name,tenant_id,contract_amount,income_amount,target_cost_amount,approved_amount,remark) VALUES(1,'QA-0907','unit',124,100,80,70,65,'keep manual remark');
INSERT INTO cost_unit_dict(accounting_unit_name,accounting_unit_code,manage_unit_name,manage_unit_group,inside_institute,tenant_id) VALUES('unit','U1','unit','PROFESSIONAL',true,124);
INSERT INTO cost_work_order(project_id,project_code,unit_name,work_order_no,tenant_id,product_target_cost,approved_amount,vertical_division,status,product_short_name) VALUES(1,'QA-0907','unit','WO-QA',124,70,65,NULL,'SUBMITTED','manual work order');
INSERT INTO cost_warning_record(project_id,project_code,tenant_id,workflow_status,cause_analysis,disposal_measure,close_user_name) VALUES(1,'QA-0907',124,'CLOSED','manual cause','manual action','manual closer');
CREATE TABLE qa_manual_before AS SELECT (SELECT user_name||stage_code||basic_info FROM cost_project_basic WHERE project_id=1) AS basic,
 (SELECT target_cost_amount||':'||approved_amount||':'||remark FROM cost_unit_cost_detail WHERE project_id=1) AS unit,
 (SELECT product_target_cost||':'||approved_amount||':'||status||':'||product_short_name FROM cost_work_order WHERE project_id=1) AS wo,
 (SELECT workflow_status||':'||cause_analysis||':'||disposal_measure FROM cost_warning_record WHERE project_id=1) AS warning;
DELETE FROM cost_schema_migration;
`
psql(fixture)
psql(rendered['02-成本库合并升级.sql'])
psql(rendered['02-成本库合并升级.sql'])
psql(rendered['03-成本库升级验收.sql'])
psql(`DO $$ BEGIN IF EXISTS(SELECT 1 FROM qa_manual_before WHERE basic IS DISTINCT FROM (SELECT user_name||stage_code||basic_info FROM cost_project_basic WHERE project_id=1)
 OR unit IS DISTINCT FROM (SELECT target_cost_amount||':'||approved_amount||':'||remark FROM cost_unit_cost_detail WHERE project_id=1)
 OR wo IS DISTINCT FROM (SELECT product_target_cost||':'||approved_amount||':'||status||':'||product_short_name FROM cost_work_order WHERE project_id=1)
 OR warning IS DISTINCT FROM (SELECT workflow_status||':'||cause_analysis||':'||disposal_measure FROM cost_warning_record WHERE project_id=1)) THEN RAISE EXCEPTION 'Manual data changed'; END IF; END $$;`)
psql(render(templates,{...params,cost:'schema_missing'})['02-成本库合并升级.sql'],false)
psql('SELECT 1 / 0;',false)
psql(`DROP INDEX uk_cost_warning_active; CREATE INDEX uk_cost_warning_active ON cost_warning_record(tenant_id,warning_source,project_id,responsible_unit_name,active_marker);
DROP INDEX uk_cost_warning_receiver_user; CREATE INDEX uk_cost_warning_receiver_user ON cost_warning_receiver(tenant_id,warning_record_id,user_id);`)
psql(rendered['02-成本库合并升级.sql'])
psql(rendered['03-成本库升级验收.sql'])
// Only the isolated QA database: simulate a pre-permissions installation.
psql(`DROP TABLE cost_user_project_scope; DROP TABLE cost_user_unit_scope; DROP TABLE cost_user_domain_scope;
DROP TABLE cost_subsystem_dict; DROP TABLE cost_warning_receiver; DROP TABLE cost_warning_action_log;
DELETE FROM cost_schema_migration WHERE version >= '20260817';
INSERT INTO cost_warning_record(project_id,project_code,tenant_id,workflow_status) VALUES(1,'QA-0907',124,NULL);`)
psql(rendered['02-成本库合并升级.sql'])
psql(rendered['03-成本库升级验收.sql'])
psql(`DO $$ BEGIN IF (SELECT count(*) FROM cost_warning_record WHERE workflow_status='LEGACY')<>1 THEN RAISE EXCEPTION 'Legacy warning not preserved'; END IF; END $$;`)
const roleSql=fs.readFileSync(path.resolve(__dirname,'../../../sqlbot_with_bcback/baback/sql/dm/costree-access-role-menu-20260817.sql'),'utf8')
const pairs=[...roleSql.matchAll(/SELECT '(cost_[a-z_]+)'(?: AS ROLE_CODE)?, '(cost:[a-z:-]+|__PARENT__)'/g)].map(m=>m[1]+':'+m[2])
assert.equal(pairs.length,42); assert.equal(new Set(pairs).size,42)
assert.equal(pairs.filter(p=>p.endsWith('__PARENT__')).length,4)
assert(rendered['05-成本权限与站内信初始化.sql'].includes("OR M.PATH='/cost-access-permissions'"))
console.log('PASS: parameter validation, HTML syntax, PG9.2 full-chain twice, manual-data preservation, missing-schema rejection')
console.log('PASS: native-PG index repair; missing permission/dictionary/workflow tables upgraded; legacy preserved; 42 mappings including four directory mappings')
