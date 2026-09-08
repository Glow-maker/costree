// Build a minimal artifact from a previously verified full package; never mutate its source.
const fs = require('fs')
const path = require('path')
const crypto = require('crypto')
const root = path.resolve(__dirname, '../..')
const source = path.join(root, 'cost-server-offline-package')
const stage = path.join(root, 'cost-server-offline-package-20260907-cost-only-staging')
if (fs.existsSync(stage)) throw Error('Staging exists; do not overwrite')
const read = p => fs.readFileSync(p, 'utf8').replace(/^\uFEFF/, '')
const hash = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex').toUpperCase()
const write = (name, body) => {
  const dest = path.join(stage, '00-现场必用', name)
  fs.mkdirSync(path.dirname(dest), { recursive: true })
  fs.writeFileSync(dest, body)
}
const src = path.join(source, '00-现场必用')
const keep = [
  '01-成本库升级/部署参数生成器.html',
  '01-成本库升级/00-识别成本schema.sql',
  '01-成本库升级/SOURCE-SHA256.json',
  '02-页面权限配置/02-站内信模板逐项复制.md',
  '03-应用文件/cost-server.jar',
  '03-应用文件/dist-prod.zip'
]
const release = Object.fromEntries(read(path.join(source, 'RELEASE-INFO.txt')).trim().split(/\r?\n/).map(line => {
  const i = line.indexOf('='); return [line.slice(0, i), line.slice(i + 1)]
}))
if (hash(path.join(src, '03-应用文件/cost-server.jar')) !== release.backendJarSha256 ||
    hash(path.join(src, '03-应用文件/dist-prod.zip')) !== release.frontendZipSha256) throw Error('Input artifact hash mismatch')
for (const name of keep) {
  const dest = path.join(stage, '00-现场必用', name)
  fs.mkdirSync(path.dirname(dest), { recursive: true })
  fs.copyFileSync(path.join(src, name), dest)
  if (hash(dest) !== hash(path.join(src, name))) throw Error('Copy mismatch: ' + name)
}
write('00-先看这张操作卡.md', read(path.join(__dirname, 'cost-only-operation.md')))
const checklist = read(path.join(src, '02-页面权限配置/01-权限勾选与专员操作清单.md'))
const business = checklist.split('## 三、')[0]
if (!business.includes('cost:model-comparison:export')) throw Error('Permission matrix not found')
write('02-页面权限配置/01-权限勾选与专员操作清单.md', business + `## 三、本包由超级管理员完成授权\n\n本包仅部署cost，不更新system。**授权专员功能暂不交付，不创建或分配cost_role_allocator。**\n\n1. 超级管理员在原中台用户管理给普通用户分配上述四类角色之一。\n2. 到 /cost/back/access-scope 设置范围：科研部为单领域；项目办为项目集合；研制单位为项目与管理单位交集；全局查看无需额外范围。\n3. 用户退出重新登录，验证范围内可见、范围外拒绝。管理员保留原用户列表和角色、用户管理入口。\n\n专员页依赖新增/system/cost-role-assignment/*接口，旧system未更新时不可交付使用。当前前端ZIP原样保留，页面代码存在不代表服务器已支持。\n\n## 四、站内信\n\n管理员按同目录02清单配置四个模板；普通业务账号不授予模板管理权限。中台权限全部页面配置，不直接执行DM写库SQL。\n`)
write('03-应用文件/00-应用替换说明.md', `# 只替换成本JAR和前端\n\n1. 停止旧成本进程，备份JAR和配置，用本目录cost-server.jar替换。沿用原成本服务端口、PG、Redis、Nacos、网关及启动参数，避免重复进程。\n2. 本JAR已移除环境profile，配置必须沿用现场原值；不要覆盖已有外置配置/Nacos。若原配置仅存在旧JAR内，由运维提取到受控配置目录并按原启动方式加载，或使用 --spring.config.additional-location=file:实际配置目录/。禁止发送含密码文件到外网。\n3. 保留原mybatis-plus.encryptor.password及xxl.job.accessToken，不能生成新密钥。参数名见同目录EXTERNALIZED-CONFIG.txt；SPRING_PROFILES_ACTIVE沿用现场有效profile。\n4. dist-prod.zip解压到新的前端目录，确认根目录index.html，整体切换静态站点。保留原Nginx和代理；不安装Node.js，不单独下载Three.js。\n5. 不替换system，不部署第二个中台服务。本包不包含其JAR。中台登录、角色、站内信接口必须为现场已有可用服务；授权专员新接口不在交付范围。\n6. 启动后先验证管理员登录、原数据授权页与其他既有模块，再按操作卡验证成本功能；失败恢复旧应用和原配置，数据库回退走备份审批流程。\n`)
write('03-应用文件/EXTERNALIZED-CONFIG.txt', read(path.join(source, 'backend/config/EXTERNALIZED-CONFIG.txt')).split(/\r?\n/).filter(x => x.startsWith('cost-server ')).join('\n') + '\n')
write('RELEASE-INFO.txt', [
  'package=cost-server-offline-package', 'releaseType=formal', 'releaseVersion=20260907',
  'releaseRevision=20260907-cost-only-essential', 'schemaVersion=' + release.schemaVersion,
  'packagedAt=' + new Date().toISOString(), 'backendCommit=' + release.backendCommit,
  'frontendCommit=' + release.frontendCommit, 'sourceReleaseRootCommit=' + release.rootCommit,
  'packagingScriptSha256=' + hash(__filename), 'backendJarSha256=' + release.backendJarSha256,
  'frontendZipSha256=' + release.frontendZipSha256, 'systemDeployment=excluded',
  'roleAllocatorDelivery=deferred; requires system endpoints', 'permissionDeployment=administrator-platform-ui',
  'runtimeAcceptance=pending real intranet cost-only integration',
  'postgresql92Validation=inherited from verified source release', 'dm8DwsValidation=target acceptance required'
].join('\n') + '\n')
write('验包说明.md', '# 验包与验证范围\n\n同目录SHA256SUMS.txt覆盖除自身外全部交付文件。构建时目录及ZIP解压后逐文件核对；cost JAR和原始前端ZIP哈希与原验证包一致，无system JAR、重复前端展开目录。\n\n沿用前一完整包的成本69项测试、前端检查与独立PG9.2升级保护测试；本次仅精简包装，不重构代码，也不声称验证了旧system与新cost的现场联调。上线前按操作卡完成五类账号和站内信验收。\n')
const base = path.join(stage, '00-现场必用')
function files(dir) { return fs.readdirSync(dir, { withFileTypes: true }).flatMap(e => e.isDirectory() ? files(path.join(dir, e.name)) : [path.join(dir, e.name)]) }
const manifest = files(base).sort().map(p => hash(p) + '  ' + path.relative(base, p).replace(/\\/g, '/')).join('\n') + '\n'
write('SHA256SUMS.txt', manifest)
console.log(JSON.stringify({ stage, files: files(base).length, bytes: files(base).reduce((n, p) => n + fs.statSync(p).size, 0) }))
