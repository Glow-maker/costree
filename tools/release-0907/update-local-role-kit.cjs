// Refresh the standalone compatibility kit without copying application binaries.
const fs = require('fs'), path = require('path'), crypto = require('crypto')
const {costSql} = require('./essentials.cjs')
const root = path.resolve(__dirname, '../..')
const kit = path.join(root, 'cost-intranet-data-kit/release-20260729-data-integration')
const base = path.join(kit, '00-现场必用')
costSql(base)
fs.copyFileSync(path.join(__dirname, 'local-role-operation.md'), path.join(base, '00-先看这张操作卡.md'))
fs.copyFileSync(path.join(__dirname, 'local-role-permissions.md'), path.join(base, '02-页面权限配置/01-权限勾选与专员操作清单.md'))
fs.copyFileSync(path.join(__dirname, 'local-role-operation.md'), path.join(kit, '0907内网操作卡.md'))
fs.writeFileSync(path.join(base, '03-应用文件/00-应用替换说明.md'), '# 应用文件另取同批精简包\n\n本目录不含应用。请从同批cost-server-offline-package的00-现场必用/03-应用文件取一个cost-server.jar和一个dist-prod.zip，遵循该包配置说明。仅替换cost与前端，不替换system。先执行本包成本SQL。旧JAR不识别本地撤销记录，回退前必须核对授权；不可直接回退后开放访问。\n')
fs.copyFileSync(path.resolve(root, '../sqlbot_with_bcback/baback/sql/postgresql92/costree-deploy/17-cost-local-roles-20260907.sql'), path.join(kit, 'postgresql92/business-upgrade/17-cost-local-roles-20260907.sql'))
fs.writeFileSync(path.join(kit, '00-开始这里.md'), '# Costree 20260907 · 成本库本地授权版\n\n本次只使用 [现场操作卡](00-现场必用/00-先看这张操作卡.md) 和该目录的成本SQL生成器、权限页面清单。仅部署cost，无system JAR更新，不执行DM写入SQL。应用文件从同批精简离线包获取，本数据集成包不含应用。\n\n其余目录保留兼容参考，不逐个执行旧权限初始化或旧清库流程。日常同步保持只清中间表、业务UPDATE＋INSERT；本地角色、授权锁、角色审计不参与清空，纳入完整数据库备份。\n\n新本地授权功能仍待真实中台RPC、DWS和账号验收。\n')
const infoPath = path.join(kit, 'RELEASE-INFO.txt')
let info = fs.readFileSync(infoPath, 'utf8')
for (const [key,value] of Object.entries({PACKAGE_REVISION:'20260907-cost-local-authorization', SOURCE_STATE:'working-tree candidate; actual SQL hashes in 00-现场必用/01-成本库升级/SOURCE-SHA256.json', PLATFORM_PERMISSION_ENTRY:'00-现场必用/02-页面权限配置/01-权限勾选与专员操作清单.md', PLATFORM_DM_EXECUTION_MODE:'PAGE CONFIGURATION ONLY; DO NOT EXECUTE LEGACY DM SQL', DEFAULT_EXAMPLE_TENANT_ID:'NONE; ENTER ACTUAL TENANT', LEGACY_RESET_PROTECTION:'DO NOT USE LEGACY RESET WITH LOCAL ROLE TABLES; FULL DATABASE BACKUP REQUIRED'})) {
  info = info.replace(new RegExp('^'+key+'=.*$', 'm'), key+'='+value)
}
if (!info.includes('AUTHORIZATION_SCHEMA_VERSION=')) info += '\nAUTHORIZATION_SCHEMA_VERSION=20260907\nSYSTEM_DEPLOYMENT=not-required\nRELEASE_TYPE=validation-candidate\n'
fs.writeFileSync(infoPath, info)
const files=[]
function walk(dir){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,e.name);if(e.isDirectory())walk(p);else if(p!==path.join(kit,'SHA256SUMS.txt'))files.push(p)}}
walk(kit)
fs.writeFileSync(path.join(kit,'SHA256SUMS.txt'),files.sort().map(p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex').toUpperCase()+'  '+path.relative(kit,p).replace(/\\/g,'/')).join('\n')+'\n')
console.log('Standalone kit refreshed: '+files.length+' files hashed; no application binaries added')
