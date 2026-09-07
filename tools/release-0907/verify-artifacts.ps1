param([Parameter(Mandatory=$true)][string]$PackageRoot)
$ErrorActionPreference='Stop'
$releaseRoot=(Resolve-Path -LiteralPath $PackageRoot).Path
Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach($required in @('0907内网操作卡.md','0907首次导入/部署参数生成器.html','0907首次导入/clear-cost-cache.ps1','database/postgresql92/02-upgrade-existing/16-repair-warning-indexes-20260907.sql')) {
  if(-not(Test-Path -LiteralPath (Join-Path $releaseRoot $required))){throw "Missing 0907 delivery: $required"}
}
$zip=[IO.Compression.ZipFile]::OpenRead((Join-Path $releaseRoot 'frontend/costree-frontend-dist-prod.zip'))
$checked=0
try {
  foreach($entry in $zip.Entries) {
    if($entry.FullName -match '(^/|(^|/)\.\.(/|$)|\\)'){throw 'Unsafe ZIP entry'}
    if($entry.FullName.EndsWith('/')){continue}
    $file=Join-Path $releaseRoot ('frontend/dist/'+$entry.FullName)
    if(-not(Test-Path -LiteralPath $file)){throw "Missing ZIP asset: $($entry.FullName)"}
    $stream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create()
    try{$expected=[BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','')}finally{$stream.Dispose();$sha.Dispose()}
    if($expected -ne (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash){throw "ZIP asset differs: $($entry.FullName)"}
    $checked++
  }
}finally{$zip.Dispose()}
$dist=Join-Path $releaseRoot 'frontend/dist'
$assets=Get-ChildItem -LiteralPath (Join-Path $dist 'assets') -File
$references=0
foreach($file in $assets | Where-Object Extension -In '.js','.css') {
  $content=Get-Content -LiteralPath $file.FullName -Raw
  if(-not $content){continue}
  foreach($match in [regex]::Matches($content,'["''](?<path>(?:\./|/)?assets/[^"''\s<>]+\.(?:js|css|glb|gltf|png|svg|woff2?))["'']|["''](?<relative>\./[^"''\s/]+-[A-Za-z0-9_-]{8}\.(?:js|css))["'']')){
    $relative=$match.Groups['path'].Value.TrimStart('./')
    $target=if($relative){Join-Path $dist $relative}else{Join-Path $file.DirectoryName $match.Groups['relative'].Value}
    if(-not(Test-Path -LiteralPath $target)){throw "Missing dynamic asset in $($file.Name): $target"}
    $references++
  }
}
foreach($pattern in @('OverviewDomainWebglPod-*.js','OverviewPlatformDomainPod-*.js')){
  if(-not($assets | Where-Object Name -Like $pattern)){throw "Missing 3D chunk $pattern"}
}
$jar=[IO.Compression.ZipFile]::OpenRead((Join-Path $releaseRoot 'backend/app/cost-server.jar'))
try{
  $names=@($jar.Entries.FullName)
  foreach($name in @('CostWarningController.class','CostModelComparisonController.class','CostProjectBasicController.class')){
    if(-not($names | Where-Object {$_ -like "BOOT-INF/classes/*/$name"})){throw "Missing current interface $name"}
  }
  if($names | Where-Object {$_ -match 'BOOT-INF/classes/.*(application-(jt|local)|Test\.class|test-seed)'}){throw 'JAR contains local/test material'}
  foreach($entry in $jar.Entries | Where-Object { $_.FullName -like 'BOOT-INF/lib/*.jar' }){
    if($entry.CompressedLength -ne $entry.Length){throw "Spring Boot nested JAR is compressed: $($entry.FullName)"}
  }
  $entry=$jar.GetEntry('BOOT-INF/classes/application.yml');$reader=[IO.StreamReader]::new($entry.Open())
  try{$config=$reader.ReadToEnd()}finally{$reader.Dispose()}
  foreach($line in $config -split "`n"){
    if($line -match '^\s*(password|accessToken):\s*(.+)$' -and $Matches[2] -notmatch '^\$\{'){throw 'Hardcoded credential in packaged base configuration'}
  }
}finally{$jar.Dispose()}
if (Select-String -LiteralPath (Join-Path $releaseRoot 'RELEASE-INFO.txt') -Pattern '^releaseRevision=20260907-business-authorization$' -Quiet) {
  foreach($name in @('00-现场必用/00-先看这张操作卡.md','00-现场必用/01-成本库升级/部署参数生成器.html','00-现场必用/02-页面权限配置/01-权限勾选与专员操作清单.md','00-现场必用/02-页面权限配置/02-站内信模板逐项复制.md')) {
    if(-not(Test-Path -LiteralPath (Join-Path $releaseRoot $name))){throw "Missing essential file $name"}
  }
  foreach($pair in @(@('backend/app/cost-server.jar','cost-server.jar'),@('backend/app/system-server.jar','system-server.jar'),@('frontend/costree-frontend-dist-prod.zip','dist-prod.zip'))) {
    if((Get-FileHash -LiteralPath (Join-Path $releaseRoot $pair[0])).Hash -ne (Get-FileHash -LiteralPath (Join-Path $releaseRoot ('00-现场必用/03-应用文件/'+$pair[1]))).Hash){throw 'Essential application differs from full package'}
  }
  $sysPath=Join-Path $releaseRoot 'backend/app/system-server.jar'
  $expected=(Select-String -LiteralPath (Join-Path $releaseRoot 'RELEASE-INFO.txt') -Pattern '^systemJarSha256=').Line.Split('=')[1]
  if((Get-FileHash -LiteralPath $sysPath -Algorithm SHA256).Hash -ne $expected){throw 'System JAR hash mismatch'}
  $sys=[IO.Compression.ZipFile]::OpenRead($sysPath)
  try {
    if(-not($sys.Entries.FullName -like 'BOOT-INF/classes/*/CostRoleAssignmentController.class')){throw 'Missing authorization officer controller'}
    if($sys.Entries.FullName -match '^BOOT-INF/classes/application-.+\.ya?ml$'){throw 'System JAR environment profile leaked'}
    foreach($entry in $sys.Entries | Where-Object FullName -Match '^BOOT-INF/classes/application\.ya?ml$') {
      $reader=[IO.StreamReader]::new($entry.Open())
      try{$content=$reader.ReadToEnd()}finally{$reader.Dispose()}
      foreach($line in $content -split "`n") {
        if($line -match '^\s*(password|accessToken|secret|api-key|client-secret|secret-key):\s*(.+)$' -and $Matches[2] -notmatch '^\$\{'){throw 'Hardcoded system credential'}
      }
    }
    foreach($entry in $sys.Entries | Where-Object FullName -Like 'BOOT-INF/lib/*.jar'){
      if($entry.CompressedLength -ne $entry.Length){throw 'Compressed nested system library'}
    }
  }finally{$sys.Dispose()}
}
foreach($file in Get-ChildItem -LiteralPath $releaseRoot -Recurse -File -Filter '*.ps1'){
  $tokens=$null;$errors=$null
  [void][Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
  if($errors){throw "PowerShell syntax failed: $($file.FullName): $errors"}
}
Write-Host "0907 artifact verification passed: $checked ZIP files; $references local asset references; current JAR interfaces; external credentials; PowerShell syntax."
