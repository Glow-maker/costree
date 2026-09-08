const fs = require('fs'), path = require('path')
const {templates, inputs} = require('./generate.cjs')
const root = path.resolve(__dirname, '../..')
const read = p => fs.readFileSync(p, 'utf8').replace(/^\uFEFF/, '')
const write = (p, text) => { fs.mkdirSync(path.dirname(p), {recursive:true}); fs.writeFileSync(p, text) }
function costSql(dest) {
  const cost = Object.fromEntries(Object.entries(templates).filter(([name]) => /^[0][123]-成本/.test(name)))
  const runtime = read(path.join(__dirname, 'parameter-runtime.js'))
  const html = `<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>成本库最简升级（离线）</title>
<style>body{max-width:880px;margin:40px auto;padding:20px;font:17px/1.8 system-ui;color:#20314d}label,a{display:block;margin:16px 0}input,button{font:inherit;padding:8px}#error{color:#b91c1c}</style>
<h1>成本库最简升级</h1><p>只生成 PG9.2/DWS 成本 SQL，不联网、不执行数据库操作。DM 权限全部按页面清单操作。</p>
<label>真实租户 ID <input id="tenant" placeholder="必填，不猜测"></label><label>成本 schema <input id="cost" placeholder="必填，如 public"></label>
<button id="generate">生成三份 SQL</button><p id="error"></p><div id="downloads"></div>
<p>先备份停写；在成本库按 01检查 → 02合并升级 → 03验收执行。遇第一条 ERROR 立即停止并回滚，不继续其他文件。不要再重复执行备用升级链。</p>
<script>${runtime}</script><script>const templates=${JSON.stringify(cost).replace(/</g,'\\u003c')};
document.getElementById('generate').onclick=()=>{const box=document.getElementById('downloads');box.replaceChildren();document.getElementById('error').textContent='';try{const data=CostRelease.render(templates,{tenant:document.getElementById('tenant').value,cost:document.getElementById('cost').value,dm:'MQB',prefix:'',cacheMode:'tenant'});for(const [name,text] of Object.entries(data)){const a=document.createElement('a');a.download=name;a.textContent='下载 '+name;a.href=URL.createObjectURL(new Blob(['\\ufeff'+text],{type:'text/plain;charset=utf-8'}));box.appendChild(a)}}catch(e){document.getElementById('error').textContent=e.message}};</script></html>`
  write(path.join(dest,'01-成本库升级/部署参数生成器.html'),html)
  write(path.join(dest,'01-成本库升级/00-识别成本schema.sql'),"SELECT version();\nSELECT table_schema,table_name FROM information_schema.tables WHERE table_name IN ('cost_project','cost_schema_migration') ORDER BY table_schema,table_name;\n")
  write(path.join(dest,'01-成本库升级/SOURCE-SHA256.json'),JSON.stringify(inputs,null,2))
}
function essentials(packageRoot, withApps = false) {
  const dest = path.join(packageRoot, '00-现场必用')
  costSql(dest)
  write(path.join(dest,'02-页面权限配置/01-权限勾选与专员操作清单.md'),read(path.join(root,'note/80-deployment/0907-成本权限页面勾选清单.md')))
  const notify = read(path.join(root,'../sqlbot_with_bcback/baback/sql/dm/cost-warning-notify-template-20260820.sql'))
  const rows=[...notify.matchAll(/SELECT '([^']+)'(?: AS NAME)?, '(COST_WARNING_[A-Z_]+)'(?: AS CODE)?,\s*'([^']+)'(?: AS CONTENT)? FROM DUAL/g)]
  if(rows.length!==4)throw Error('Expected four notification templates')
  write(path.join(dest,'02-页面权限配置/02-站内信模板逐项复制.md'), '# 四个站内信模板：只用页面，不执行 DM SQL\n\n由平台管理员打开「系统管理 → 站内信 → 模板管理」。按编码查询；存在则编辑，不重复创建。发送人昵称统一为“成本预警中心”，类型为系统通知（字典值2），状态开启。正文中的花括号参数原样保留。\n\n'+rows.map(r=>`## ${r[1]}\n\n编码：\`${r[2]}\`\n\n正文：\n\n\`\`\`text\n${r[3]}\n\`\`\`\n`).join('\n')+'\n模板参数由页面按正文解析。保存后重新打开核对四个编码和启用状态，再以项目办推送、研制单位反馈验证。\n')
  write(path.join(dest,'00-先看这张操作卡.md'),read(path.join(__dirname,'现场操作卡.md')))
  write(path.join(dest,'03-应用文件/00-应用替换说明.md'),read(path.join(__dirname,'中台服务更新说明.md')))
  if(withApps)for(const [src,name] of [['backend/app/cost-server.jar','cost-server.jar'],['backend/app/system-server.jar','system-server.jar'],['frontend/costree-frontend-dist-prod.zip','dist-prod.zip']])fs.copyFileSync(path.join(packageRoot,src),path.join(dest,'03-应用文件',name))
  write(path.join(packageRoot,'0907内网操作卡.md'),read(path.join(__dirname,'现场操作卡.md')))
  write(path.join(packageRoot,'0907首次导入/00-备用流程-本次不要执行.md'),'# 备用：DBA直接修改DM的旧流程\n\n本次默认使用00-现场必用中的页面权限清单，不执行此目录DM写入SQL，不和页面配置重复操作。成本库只使用现场必用中的三步生成器。\n')
  const legacyHtml=path.join(packageRoot,'0907首次导入/部署参数生成器.html')
  if(fs.existsSync(legacyHtml))write(legacyHtml,read(legacyHtml).replace('<h1>0907 内网部署参数生成器</h1>','<h1>备用：DBA直接写库流程，本次不要使用</h1><p>请返回00-现场必用，使用成本库三步生成器及页面权限清单。</p>'))
  write(path.join(packageRoot,'00-开始这里.md'),'# Costree 20260907 · 业务部门授权版\n\n**本次只看 [00-现场必用/00-先看这张操作卡.md](00-现场必用/00-先看这张操作卡.md)。**\n\n该目录集中最简成本 SQL 生成器、页面权限清单、四个站内信正文'+(withApps?'以及两个 JAR 和原样前端 ZIP':'；本数据集成子包不含应用 JAR/ZIP')+'。不需要执行 DM 写入 SQL。\n\n其余 database、docs、0907首次导入目录为兼容和排错备用，不要逐个执行，不与主流程混用。日常同步原任务正常运行则保持不变。\n')
}
if(require.main===module)essentials(path.resolve(process.argv[2]),process.argv.includes('--apps'))
module.exports={essentials,costSql}
