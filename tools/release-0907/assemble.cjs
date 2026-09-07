// Assemble only; tests and a fresh Maven clean package must run before this command.
const fs=require('fs'), path=require('path'), cp=require('child_process'), crypto=require('crypto')
const {generate}=require('./generate.cjs')
const root=path.resolve(__dirname,'../..'), backend=path.resolve(root,'../sqlbot_with_bcback/baback'), frontend=path.resolve(root,'../sqlbot_with_bcback/costree-frontend')
const kit=path.join(root,'cost-intranet-data-kit/release-20260729-data-integration')
const out=path.join(root,'cost-server-offline-package-20260907-staging')
const template=path.join(root,'deploy/cost-server-offline-template')
const read=p=>fs.readFileSync(p,'utf8').replace(/^\uFEFF/,'')
const write=(p,s)=>{fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,s)}
const sha=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex')
const git=(dir,...args)=>cp.execFileSync('git',['-C',dir,...args],{encoding:'utf8'}).trim()
function copy(src,dst){fs.mkdirSync(path.dirname(dst),{recursive:true});fs.cpSync(src,dst,{recursive:true,filter:p=>!/(?:^|[\\/])(?:04-reset-and-reload|90-optional-test-seed|91-optional-demo)(?:[\\/]|$)/.test(p)})}
function files(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?files(path.join(dir,e.name)):[path.join(dir,e.name)])}
function manifest(dir){write(path.join(dir,'SHA256SUMS.txt'),files(dir).filter(p=>p!==path.join(dir,'SHA256SUMS.txt')).sort().map(p=>sha(p)+' *'+path.relative(dir,p).replace(/\\/g,'/')).join('\n')+'\n')}
function safeRemove(p){if(!p.startsWith(out+path.sep))throw Error('Unsafe removal');fs.rmSync(p,{recursive:true,force:true})}
function prepareKit(){
  generate(path.join(kit,'0907首次导入'))
  copy(path.join(backend,'sql/postgresql92/costree-deploy/16-repair-warning-indexes-20260907.sql'),path.join(kit,'postgresql92/business-upgrade/05-修补原生PG预警唯一索引-20260907.sql'))
  copy(path.join(__dirname,'clear-cost-cache.ps1'),path.join(kit,'0907首次导入/clear-cost-cache.ps1'))
  copy(path.join(__dirname,'0907内网操作卡.md'),path.join(kit,'0907内网操作卡.md'))
  // Current source is authoritative; keep old filenames as documented compatibility copies.
  for(const [src,dst] of [['costree-access-role-menu-20260817.sql','costree-access-role-menu-20260824.sql'],['check-cost-permissions-20260817.sql','check-cost-permissions-20260824.sql'],['cost-warning-notify-template-20260820.sql','cost-warning-notify-template-20260820.sql']])copy(path.join(backend,'sql/dm',src),path.join(kit,'platform/dm8',dst))
  let info=read(path.join(kit,'RELEASE-INFO.txt')).replace(/PACKAGE_REVISION=.*/,'PACKAGE_REVISION=20260907-offline-first-deploy').replace(/BUILD_DATE=.*/,'BUILD_DATE=2026-09-07').replace(/PLATFORM_PERMISSION_REVISION=.*/,'PLATFORM_PERMISSION_REVISION=20260907').replace(/SOURCE_STATE=.*/,'SOURCE_STATE=current committed application sources; release templates pinned by SOURCE-SHA256.json').replace(/BACKEND_SOURCE_BASE_COMMIT=.*/,'BACKEND_SOURCE_BASE_COMMIT='+git(backend,'rev-parse','HEAD'))
  write(path.join(kit,'RELEASE-INFO.txt'),info)
  const verifier=path.join(kit,'tools/verify-package.ps1')
  write(verifier,read(verifier).replaceAll('PACKAGE_REVISION=20260824-model-comparison-permission-first-deploy','PACKAGE_REVISION=20260907-offline-first-deploy').replaceAll('BUILD_DATE=2026-08-24','BUILD_DATE=2026-09-07').replaceAll('PLATFORM_PERMISSION_REVISION=20260824','PLATFORM_PERMISSION_REVISION=20260907'))
  write(path.join(kit,'00-开始这里.md'),'# 0907 数据集成与首次权限导入\n\n已有成本库＋DM8首次权限导入：先读 [0907内网操作卡](0907内网操作卡.md)，打开 [离线参数生成器](0907首次导入/部署参数生成器.html)。\n\n本包不含 JAR/前端；应用操作请使用完整离线包。同一升级不要重复执行合并 SQL 和旧分步 SQL。每日同步仍按 postgresql92/snapshot-upsert 和 pako-daily，旧文件保留兼容。\n')
  write(path.join(kit,'platform/README.md'),'# DM8 首次权限导入 · 20260907\n\n主入口为根目录《0907内网操作卡》和 `0907首次导入/部署参数生成器.html`，不要再补跑历史版本。\n\n4类成本角色、21权限、42映射、4通知模板。科研部按领域填写全周期经费；项目办基础填报、单位工作令填报不走旧审批，预警处置闭环保留。用户和角色分配在中台页面操作。\n\n源码兼容副本保留在 dm8；文件名的旧日期不是当前交付日期。缓存清理以新生成器输出为准，permission_menu_ids、notify_template 在当前源码中为全局缓存。\n')
  manifest(kit)
}
function assemble(){
  if(fs.existsSync(out))throw Error('Staging already exists; keep it for inspection, do not overwrite')
  const frontStatus=git(frontend,'status','--porcelain','--','.',' :(exclude)design-qa.md'.trim())
  const backendStatus=git(backend,'status','--porcelain')
  if(frontStatus||backendStatus.split('\n').filter(Boolean).some(line=>!line.replace(/^[ M?]+ /,'').startsWith('sql/postgresql92/')))throw Error('Application runtime source has uncommitted changes')
  const zip=path.join(frontend,'dist-prod.zip')
  if(sha(zip)!=='fb8da4c7a96afa63904cb7fff1a0e3e82993e5eb214786845bad781936472fac')throw Error('User ZIP hash changed')
  const jar=path.join(backend,'yudao-module-cost/yudao-module-cost-biz/target/yudao-module-cost-biz.jar')
  const systemJar=path.join(backend,'yudao-module-system/yudao-module-system-biz/target/yudao-module-system-biz.jar')
  if(Date.now()-fs.statSync(jar).mtimeMs>3600000)throw Error('JAR is not a fresh build')
  if(Date.now()-fs.statSync(systemJar).mtimeMs>3600000)throw Error('System JAR is not a fresh build')
  copy(template,out)
  copy(zip,path.join(out,'frontend/costree-frontend-dist-prod.zip'))
  copy(jar,path.join(out,'backend/app/cost-server.jar'))
  copy(systemJar,path.join(out,'backend/app/system-server.jar'))
  for(const dialect of ['postgresql','postgresql92']){
    const target=path.join(out,'database',dialect)
    copy(path.join(backend,'sql',dialect,'costree-cost.sql'),path.join(target,'01-new-database/costree-cost.sql'))
    copy(path.join(backend,'sql',dialect,'costree-deploy'),path.join(target,'02-upgrade-existing'))
    copy(path.join(backend,'sql',dialect,'costree-integration'),path.join(target,'03-data-integration'))
    if(dialect==='postgresql92')copy(path.join(backend,'sql',dialect,'README.md'),path.join(target,'README.md'))
    safeRemove(path.join(target,'03-data-integration/business-upgrade'))
  }
  for(const folder of ['snapshot-upsert','manual-preservation','pako-daily'])copy(path.join(kit,'postgresql92',folder),path.join(out,'database/postgresql92/03-data-integration',folder))
  for(const dialect of ['mysql','postgresql','postgresql92']){
    copy(path.join(backend,'sql',dialect,'costree-access-role-menu-20260817.sql'),path.join(out,'database/platform',`costree-access-role-menu-${dialect}-20260817.sql`))
    copy(path.join(backend,'sql',dialect,'cost-warning-notify-template-20260820.sql'),path.join(out,'database/platform',`cost-warning-notify-template-${dialect}-20260820.sql`))
  }
  for(const [src,dst] of [['costree-access-role-menu-20260817.sql','01-costree-role-menu-full-20260820.sql'],['cost-warning-notify-template-20260820.sql','02-cost-warning-notify-template-20260820.sql'],['check-cost-permissions-20260817.sql','03-check-cost-permissions-20260820.sql']])copy(path.join(backend,'sql/dm',src),path.join(out,'database/platform/dm8',dst))
  copy(path.join(kit,'0907首次导入'),path.join(out,'0907首次导入'))
  copy(path.join(__dirname,'0907内网操作卡.md'),path.join(out,'0907内网操作卡.md'))
  copy(path.join(root,'note/80-deployment/03-成本树三级权限与双库初始化.md'),path.join(out,'docs/12-成本树三级权限与双库初始化.md'))
  for(const file of files(path.join(out,'docs')).filter(p=>p.endsWith('.md'))){
    write(file,'> 0907 当前部署主入口为根目录《0907内网操作卡》。本页保留历史配置/排错参考，旧审批及科研部只读描述不再适用；缓存键以0907生成器为准。\n\n'+read(file))
  }
  write(path.join(out,'docs/14-内网首次部署与帕科每日运行操作手册.md'),'# 0907 内网部署\n\n请按根目录 [0907内网操作卡](../0907内网操作卡.md) 执行；旧升级链不与合并 SQL 重复执行。\n')
  write(path.join(out,'database/platform/dm8/00-开始这里.md'),'# DM8 首次导入 · 0907\n\n使用根目录0907首次导入的离线生成器，下载04—06整段执行。此目录的分步脚本是源码兼容副本，不与合并脚本重复执行。\n')
  write(path.join(out,'00-开始这里.md'),'# Costree 20260907 正式内网离线包\n\n1. 验包、停写并备份。\n2. 阅读 [0907内网操作卡](0907内网操作卡.md)。\n3. 打开 [离线部署参数生成器](0907首次导入/部署参数生成器.html)。\n\n已有成本库升级与DM8首次权限初始化分开执行。不清业务表；前端含经典、3D舱、平台舱。\n\n发布日期不是数据库结构版本；结构目标20260820。测试证据见 [0907验证结果](0907验证结果.md)。\n')
  for(const file of files(__dirname).filter(p=>!p.endsWith('test.cjs')))copy(file,path.join(out,'tools/release-source-0907',path.relative(__dirname,file)))
  const provenance={backendCommit:git(backend,'rev-parse','HEAD'),frontendCommit:git(frontend,'rev-parse','HEAD'),rootBaseCommit:git(root,'rev-parse','HEAD'),
    backendSqlWorkingTree:backendStatus,releaseTooling:'committed release-source-0907; unrelated root files excluded',excluded:['.agent-handoff','design-qa.md','test.html','test2.html'],
    files:Object.fromEntries(files(out).filter(p=>!p.includes(path.sep+'frontend'+path.sep)&&!p.endsWith('.jar')).map(p=>[path.relative(out,p).replace(/\\/g,'/'),sha(p)]))}
  write(path.join(out,'SOURCE-MANIFEST.json'),JSON.stringify(provenance,null,2))
  write(path.join(out,'RELEASE-INFO.txt'),[
    'package=cost-server-offline-package','releaseType=candidate','releaseVersion=20260907','schemaVersion=20260820',
    'buildTime='+new Date().toISOString(),'backendCommit='+provenance.backendCommit,'frontendCommit='+provenance.frontendCommit,
    'rootCommit='+provenance.rootBaseCommit,'rootSourceTracking=release-source-0907 snapshot and SOURCE-MANIFEST.json; unrelated dirty files excluded',
    'backendBranch='+git(backend,'branch','--show-current'),'frontendBranch='+git(frontend,'branch','--show-current'),
    'frontendZipSha256='+sha(zip).toUpperCase(),'backendJarSha256='+sha(jar).toUpperCase(),'backendJar=sanitized fresh clean-package output',
    'systemJarSha256='+sha(systemJar).toUpperCase(),'releaseRevision=20260907-business-authorization','permissionDeployment=platform-ui-only',
    'postgresql92Validation=pending','dm8Validation=static only; target database acceptance required','gaussdbDwsValidation=static only; target database acceptance required'
  ].join('\n')+'\n')
  manifest(out)
  console.log(out)
}
if(require.main===module){if(process.argv[2]==='kit')prepareKit();else if(process.argv[2]==='manifest')manifest(path.resolve(process.argv[3]));else assemble()}
module.exports={manifest,root,out,kit}
