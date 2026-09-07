const fs = require('fs')
const path = require('path')
const crypto = require('crypto')
const root = path.resolve(__dirname, '../..')
const backend = path.resolve(root, '../sqlbot_with_bcback/baback')
const read = p => fs.readFileSync(p, 'utf8').replace(/^\uFEFF/, '').replace(/\r\n/g, '\n')
const hash = text => crypto.createHash('sha256').update(text).digest('hex')
const inputs = {}
function source(relative) {
  const text = read(path.join(backend, relative)); inputs[relative] = hash(text); return text
}
// Only standalone transaction commands outside dollar-quoted function bodies.
function withoutTransactions(sql) {
  let dollar = null
  return sql.split('\n').filter(line => {
    if (!dollar && /^(BEGIN|COMMIT);\s*$/.test(line)) return false
    const code = line.replace(/--.*$/, '')
    for (const match of code.matchAll(/\$(?:[A-Za-z_][A-Za-z_0-9]*)?\$/g)) {
      if (dollar === match[0]) dollar = null
      else if (!dollar) dollar = match[0]
    }
    return true
  }).join('\n')
}
const deploy = 'sql/postgresql92/costree-deploy/'
const header = `-- Costree 发布 20260907；仅执行于已备份、停止写入的成本库。\nSET search_path TO "@@COST_SCHEMA@@", public;\nDO $guard$ BEGIN\n IF current_schema() <> '@@COST_SCHEMA@@' THEN RAISE EXCEPTION '成本 schema 不存在或不可访问'; END IF;\nEND $guard$;\n`
const check = source(deploy+'00-dws-precheck.sql') + '\n' + source(deploy+'00-precheck.sql')
const duplicateGuard = `DO $dup$ BEGIN
 IF EXISTS (SELECT 1 FROM cost_work_order GROUP BY tenant_id, project_code, unit_name, work_order_no HAVING count(*)>1)
 OR EXISTS (SELECT 1 FROM cost_unit_cost_detail GROUP BY tenant_id, project_code, unit_name HAVING count(*)>1) THEN
 RAISE EXCEPTION '存在重复业务键，禁止自动合并或删除填报数据；请保留本次只读检查结果'; END IF;
 IF NOT EXISTS (SELECT 1 FROM cost_project WHERE tenant_id=@@TENANT@@) THEN
 RAISE EXCEPTION '此成本 schema 内没有所填租户的项目，请确认租户及 schema'; END IF;
END $dup$;`
const files = fs.readdirSync(path.join(backend, deploy)).filter(n => /^1[0-5]-.*\.sql$/.test(n)).sort()
let upgrade = 'BEGIN;\n' + header + check + '\n' + duplicateGuard + `
CREATE TABLE IF NOT EXISTS cost_schema_migration (
 version varchar(32) PRIMARY KEY, description varchar(255) NOT NULL,
 installed_on timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, installed_by varchar(128) NOT NULL DEFAULT CURRENT_USER);
`
for (const file of files) {
  const version = file.match(/to-(\d{8})/)[1]
  const body = withoutTransactions(source(deploy + file))
  upgrade += `\n-- ${file}: 已达到此版本则跳过，避免重跑旧数据归并。\nDO $gate${version}$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM cost_schema_migration WHERE version >= '${version}') THEN
 EXECUTE $migration${version}$${body}$migration${version}$;
 END IF;
END $gate${version}$;\n`
}
const verify = withoutTransactions(source(deploy+'20-verify.sql'))
upgrade += '\n' + withoutTransactions(source(deploy+'16-repair-warning-indexes-20260907.sql'))
upgrade += '\n' + verify + "\nCOMMIT;\n-- 只有没有任何 ERROR 且 COMMIT 成功，本次升级才完成。\n"
const dmRole = source('sql/dm/costree-access-role-menu-20260817.sql')
const dmNotify = source('sql/dm/cost-warning-notify-template-20260820.sql')
const dmCheck = source('sql/dm/check-cost-permissions-20260817.sql')
const dmReplace = text => text.replace(/\bMQB\b/g, '@@DM_SCHEMA@@').replace(/\b124\b/g, '@@TENANT@@')
const permissions = [...new Set([...dmRole.matchAll(/'((?:cost:)[a-z:-]+)'/g)].map(m=>m[1]))].sort()
if (permissions.length!==21) throw Error('Expected 21 permission definitions')
const roles = ['cost_global_viewer','cost_research_department','cost_project_office','cost_unit_user']
const notify = ['COST_WARNING_PENDING_DISPOSITION','COST_WARNING_FEEDBACK_SUBMITTED','COST_WARNING_RETURNED','COST_WARNING_CLOSED']
const literals = values => values.map(x=>`'${x}'`).join(',')
const dmPrecheck = `-- 在达梦客户端整段执行；结果必须存在所填租户，并且所需表可读。
SELECT USER AS LOGIN_USER FROM DUAL;
SELECT ID, NAME FROM @@DM_SCHEMA@@.SYSTEM_TENANT WHERE ID=@@TENANT@@ AND DELETED=0;
SELECT OWNER,TABLE_NAME,COLUMN_NAME,DATA_TYPE,DATA_DEFAULT FROM ALL_TAB_COLUMNS
 WHERE OWNER='@@DM_SCHEMA@@' AND TABLE_NAME IN
 ('SYSTEM_MENU','SYSTEM_ROLE','SYSTEM_ROLE_MENU','SYSTEM_USERS','SYSTEM_USER_ROLE','SYSTEM_NOTIFY_TEMPLATE')
 ORDER BY TABLE_NAME,COLUMN_ID;
-- 在客户端表设计中确认 SYSTEM_MENU/ROLE/ROLE_MENU/NOTIFY_TEMPLATE 的 ID 是 IDENTITY 自增。
-- 本包匹配当前中台的 IDENTITY 结构；不是自增时停止，禁止随手用 MAX(ID)+1 替代。
SELECT ID,CODE,STATUS FROM @@DM_SCHEMA@@.SYSTEM_ROLE WHERE TENANT_ID=@@TENANT@@ AND CODE IN (${literals(roles)}) AND DELETED=0;
`
// Templates use only DML before COMMIT; wrap in a single DM anonymous block.
function dmDml(text) { return text.split(/^COMMIT;\s*$/m)[0] }
const dmInit = `-- DM8 原生 SQL 脚本模式，整段执行此匿名块；关闭自动提交，遇错停止。
-- 不创建用户、不分配用户角色；权限和通知模板同一个事务。
DECLARE V_COUNT INTEGER;
BEGIN
 SELECT COUNT(*) INTO V_COUNT FROM @@DM_SCHEMA@@.SYSTEM_TENANT WHERE ID=@@TENANT@@ AND DELETED=0;
 IF V_COUNT<>1 THEN RAISE_APPLICATION_ERROR(-20001,'租户不存在或重复，停止权限初始化'); END IF;
${dmReplace(dmDml(dmRole))}
${dmReplace(dmDml(dmNotify))}
 SELECT COUNT(*) INTO V_COUNT FROM @@DM_SCHEMA@@.SYSTEM_ROLE
 WHERE TENANT_ID=@@TENANT@@ AND CODE IN (${literals(roles)}) AND DELETED=0 AND STATUS=0;
 IF V_COUNT<>4 THEN RAISE_APPLICATION_ERROR(-20002,'成本角色不是4个，回滚'); END IF;
 SELECT COUNT(*) INTO V_COUNT FROM @@DM_SCHEMA@@.SYSTEM_MENU WHERE DELETED=0 AND PERMISSION IN (${literals(permissions)});
 IF V_COUNT<>21 THEN RAISE_APPLICATION_ERROR(-20003,'成本权限不是21个，回滚'); END IF;
 SELECT COUNT(*) INTO V_COUNT FROM @@DM_SCHEMA@@.SYSTEM_ROLE_MENU RM
 JOIN @@DM_SCHEMA@@.SYSTEM_ROLE R ON R.ID=RM.ROLE_ID
 JOIN @@DM_SCHEMA@@.SYSTEM_MENU M ON M.ID=RM.MENU_ID
 WHERE RM.TENANT_ID=@@TENANT@@ AND RM.DELETED=0 AND R.DELETED=0 AND R.TENANT_ID=@@TENANT@@
 AND R.CODE IN (${literals(roles)}) AND M.DELETED=0 AND (M.PERMISSION IN (${literals(permissions)}) OR M.PATH='/cost-access-permissions');
 IF V_COUNT<>42 THEN RAISE_APPLICATION_ERROR(-20004,'成本角色映射不是42条，回滚'); END IF;
 SELECT COUNT(*) INTO V_COUNT FROM @@DM_SCHEMA@@.SYSTEM_NOTIFY_TEMPLATE
 WHERE DELETED=0 AND STATUS=0 AND CODE IN (${literals(notify)});
 IF V_COUNT<>4 THEN RAISE_APPLICATION_ERROR(-20005,'预警通知模板不是4个，回滚'); END IF;
 COMMIT;
EXCEPTION WHEN OTHERS THEN
 ROLLBACK;
 RAISE;
END;
/
`
const cacheSql = `
-- 只导出最后一组 CACHE_KEY 列（无表头、每行一键）为 cache-keys.txt。
-- 当前源码 permission_menu_ids 和 notify_template 是跨租户共享缓存，不拼租户后缀。
SELECT '@@PREFIX@@role:@@CACHE_TENANT@@' || CAST(ID AS VARCHAR(32)) AS CACHE_KEY
 FROM @@DM_SCHEMA@@.SYSTEM_ROLE WHERE TENANT_ID=@@TENANT@@ AND DELETED=0 AND CODE IN (${literals(roles)})
UNION
SELECT '@@PREFIX@@menu_role_ids:@@CACHE_TENANT@@' || CAST(ID AS VARCHAR(32))
 FROM @@DM_SCHEMA@@.SYSTEM_MENU WHERE DELETED=0 AND (PERMISSION IN (${literals(permissions)}) OR PATH='/cost-access-permissions')
UNION
SELECT '@@PREFIX@@permission_menu_ids:' || PERMISSION FROM @@DM_SCHEMA@@.SYSTEM_MENU
 WHERE DELETED=0 AND PERMISSION IN (${literals(permissions)})
UNION
SELECT '@@PREFIX@@notify_template:' || CODE FROM @@DM_SCHEMA@@.SYSTEM_NOTIFY_TEMPLATE
 WHERE DELETED=0 AND CODE IN (${literals(notify)})
ORDER BY 1;
`
const templates = {
 '01-成本库只读检查.sql': header + check + '\n' + duplicateGuard,
 '02-成本库合并升级.sql':upgrade,
 '03-成本库升级验收.sql':'BEGIN;\n'+header+verify+'\nCOMMIT;\n',
 '04-中台只读检查.sql':dmPrecheck,
 '05-成本权限与站内信初始化.sql':dmInit,
 '06-中台验收与缓存清单.sql':dmReplace(dmCheck)+ '\nSELECT CODE,COUNT(*) AS ACTIVE_COUNT FROM @@DM_SCHEMA@@.SYSTEM_NOTIFY_TEMPLATE WHERE DELETED=0 AND STATUS=0 AND CODE IN ('+literals(notify)+') GROUP BY CODE;\n'+cacheSql
}
const runtime = read(path.join(__dirname,'parameter-runtime.js'))
const html = `<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>0907 部署参数生成器（离线）</title>
<style>body{font:16px/1.7 system-ui;color:#20314d;background:#f1f5f9;max-width:920px;margin:32px auto;padding:20px}section{background:white;padding:24px;border-radius:14px;margin:18px 0}label{display:block;margin:12px 0}input,select,button{font:inherit;padding:8px;border:1px solid #abc;border-radius:6px}input{width:260px}button,a{margin:8px}a{display:block;color:#165ad1}#error{color:#b91c1c}.notice{color:#9a5b00}textarea{width:100%;height:180px}</style>
<h1>0907 内网部署参数生成器</h1><p>仅在本机生成文件，不联网、不执行 SQL、不保存密码。先阅读《0907内网操作卡》。</p>
<section><label>真实租户 ID <input id="tenant" placeholder="必填，不使用示例值"></label>
<label>成本 schema <input id="cost" placeholder="必填，例如 costree_mvp"></label>
<label>中台 schema <input id="dm" placeholder="必填，例如 MQB"></label>
<label>Redis 完整前缀 <input id="prefix" placeholder="无前缀留空，有前缀含末尾冒号"></label>
<label>role / menu_role_ids 缓存模式 <select id="cacheMode"><option value="">请按中台实际配置选择</option><option value="tenant">启用租户缓存（当前源码默认）</option><option value="global">未启用租户缓存</option></select></label>
<p class="notice">permission_menu_ids、notify_template 按当前源码为全局缓存。内网若自定义了 ignore-caches，先按实际配置核对，不可盲删。</p>
<button id="generate">生成六份 SQL</button><p id="error"></p><div id="downloads"></div></section>
<section><h2>拿不准参数？先识别，不要猜</h2><p>成本库运行包内“00-识别成本schema.sql”；DM8 运行“00-识别中台schema.sql”。在查到的中台 schema 中打开 SYSTEM_TENANT 表或现有管理员的 SYSTEM_USERS 记录，查看租户 ID。</p>
<p>下载后按 01→02→03（成本库）、04→05→06（DM8）执行。一个数据库窗口不能混跑两种 SQL。任一 ERROR 停止；全部验收通过后才清缓存、换应用。</p></section>
<script>${runtime}</script><script>const templates=${JSON.stringify(templates).replace(/</g,'\\u003c')};
document.getElementById('generate').onclick=()=>{const area=document.getElementById('downloads');area.replaceChildren();document.getElementById('error').textContent='';try{const input={};for(const key of ['tenant','cost','dm','prefix','cacheMode'])input[key]=document.getElementById(key).value;const result=CostRelease.render(templates,input);for(const [name,text] of Object.entries(result)){const a=document.createElement('a');a.textContent='下载 '+name;a.download=name;a.href=URL.createObjectURL(new Blob(['\\ufeff'+text],{type:'text/plain;charset=utf-8'}));area.appendChild(a)}}catch(e){document.getElementById('error').textContent=e.message}};</script></html>`
function write(dir,name,text){fs.mkdirSync(dir,{recursive:true});fs.writeFileSync(path.join(dir,name),text)}
function generate(dir) {
  write(dir,'部署参数生成器.html',html)
  write(dir,'sql-templates.json',JSON.stringify(templates,null,2))
  write(dir,'SOURCE-SHA256.json',JSON.stringify(inputs,null,2))
  write(dir,'00-识别成本schema.sql',"SELECT version();\nSELECT table_schema,table_name FROM information_schema.tables WHERE table_name IN ('cost_project','cost_schema_migration') ORDER BY table_schema,table_name;\n")
  write(dir,'00-识别中台schema.sql',"SELECT USER AS LOGIN_USER FROM DUAL;\nSELECT OWNER,TABLE_NAME FROM ALL_TABLES WHERE TABLE_NAME IN ('SYSTEM_TENANT','SYSTEM_USERS','SYSTEM_MENU') ORDER BY OWNER,TABLE_NAME;\n")
}
if(require.main===module)generate(path.resolve(process.argv[2]))
module.exports={generate,templates,withoutTransactions,inputs}
