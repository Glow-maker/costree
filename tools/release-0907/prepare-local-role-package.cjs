const fs = require('fs'), path = require('path'), crypto = require('crypto'), cp = require('child_process')
const root = path.resolve(__dirname, '../..'), backend = path.resolve(root, '../sqlbot_with_bcback/baback')
const {costSql} = require('./essentials.cjs')
const stage = path.join(root, 'cost-server-offline-package-20260907-cost-only-staging')
if (fs.existsSync(stage)) throw Error('Preserve existing staging; do not overwrite')
const dest = path.join(stage, '00-现场必用')
const write = (name, text) => { const p = path.join(dest,name); fs.mkdirSync(path.dirname(p),{recursive:true}); fs.writeFileSync(p,text) }
const read = p => fs.readFileSync(p,'utf8')
const hash = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex').toUpperCase()
costSql(dest)
write('00-先看这张操作卡.md',read(path.join(__dirname,'local-role-operation.md')))
write('02-页面权限配置/01-权限勾选与专员操作清单.md',read(path.join(__dirname,'local-role-permissions.md')))
write('02-页面权限配置/02-站内信模板逐项复制.md',read(path.join(root,'cost-server-offline-package/00-现场必用/02-页面权限配置/02-站内信模板逐项复制.md')))
write('03-应用文件/00-应用替换说明.md',read(path.join(root,'cost-server-offline-package/00-现场必用/03-应用文件/00-应用替换说明.md'))
  .replace('授权专员新接口不在交付范围。','授权专员接口已迁入cost，不调用新增system接口。先执行本包成本SQL，再更换本包前后端。')
  .replace('失败恢复旧应用和原配置，数据库回退走备份审批流程。','失败先停写并保留现场。旧成本JAR不识别本地角色及撤销记录，不能直接回退后开放访问；管理员核对新旧授权一致性并按审批回退，详见操作卡。'))
write('03-应用文件/EXTERNALIZED-CONFIG.txt',read(path.join(root,'cost-server-offline-package/00-现场必用/03-应用文件/EXTERNALIZED-CONFIG.txt')))
fs.copyFileSync(path.join(backend,'yudao-module-cost/yudao-module-cost-biz/target/yudao-module-cost-biz.jar'),path.join(dest,'03-应用文件/cost-server.jar'))
// Include hashes of actual working source, rather than misidentifying it as the previous commit.
const sources = {}
function record(base, dir) {
  for(const e of fs.readdirSync(dir,{withFileTypes:true})) {
    const p=path.join(dir,e.name)
    if(e.isDirectory())record(base,p)
    else sources[path.relative(path.dirname(base),p).replace(/\\/g,'/')]=hash(p)
  }
}
record(backend,path.join(backend,'yudao-module-cost/yudao-module-cost-biz/src/main'))
const frontend = path.resolve(root,'../sqlbot_with_bcback/costree-frontend')
for(const name of ['src/api/cost','src/views/cost','src/store/modules/costAccess.ts','src/permission.ts']) {
  const p=path.join(frontend,name)
  if(fs.statSync(p).isDirectory())record(frontend,p)
  else sources['costree-frontend/'+name]=hash(p)
}
write('SOURCE-SHA256.json',JSON.stringify(sources,null,2))
const git = dir => cp.execFileSync('git',['rev-parse','HEAD'],{cwd:dir,encoding:'utf8'}).trim()
write('RELEASE-INFO.txt',[
  'package=cost-server-offline-package','releaseVersion=20260907','releaseRevision=20260907-cost-local-authorization',
  'releaseType=validation-candidate','schemaVersion=20260820','authorizationSchemaVersion=20260907',
  'sourceState=working-tree; exact file hashes in SOURCE-SHA256.json',
  'backendBaseCommit='+git(backend),'frontendBaseCommit='+git(frontend),'systemDeployment=not-required',
  'frontendBuild=fresh production build; original user ZIP preserved',
  'permissionDeployment=cost-local-role-with-platform-legacy-fallback',
  'runtimeAcceptance=pending real intranet and real account testing',
  'builtAt='+new Date().toISOString()
].join('\n')+'\n')
write('验包说明.md','# 验证范围\n\n目录与压缩解压后的SHA256逐文件核对；只含一个成本JAR、一份新前端ZIP，不包含system。\n\n成本权限与Mapper定向测试、类型检查、目标ESLint及独立PG9.2升级/数据保护测试的结果记录在构建日志。真实DM/DWS、旧中台RPC、六类账号与浏览器完整流程尚需验收，因此标为validation-candidate，不冒充已完成生产验收。\n')
console.log(stage)
