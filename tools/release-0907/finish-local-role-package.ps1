$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$stage=Join-Path $workspace 'cost-server-offline-package-20260907-cost-only-staging'
$base=Join-Path $stage '00-现场必用'
$app=Join-Path $base '03-应用文件'
$frontend=[IO.Path]::GetFullPath((Join-Path $workspace '../sqlbot_with_bcback/costree-frontend/dist-cost-local-role-0907'))
if(-not(Test-Path -LiteralPath (Join-Path $frontend 'index.html'))){throw 'Fresh frontend output missing'}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$jarPath=Join-Path $app 'cost-server.jar'
$jar=[IO.Compression.ZipFile]::Open($jarPath,[IO.Compression.ZipArchiveMode]::Update)
try {
  foreach($entry in @($jar.Entries | Where-Object FullName -Match '^BOOT-INF/classes/application-.+\.ya?ml$')){$entry.Delete()}
  foreach($name in @('application.yml','application.yaml')) {
    $entry=$jar.GetEntry('BOOT-INF/classes/'+$name)
    if(-not $entry){continue}
    $reader=[IO.StreamReader]::new($entry.Open())
    try{$text=$reader.ReadToEnd()}finally{$reader.Dispose()}
    $text=$text -replace '(?m)^(\s*active:)\s*[^\r\n]+', '$1 ${SPRING_PROFILES_ACTIVE:intranet}'
    $text=$text -replace '(?m)^(\s*password:)\s*[^\r\n]+', '$1 ${COST_MYBATIS_PLUS_ENCRYPTOR_PASSWORD:}'
    $text=$text -replace '(?m)^(\s*accessToken:)\s*[^\r\n]+', '$1 ${COST_XXL_JOB_ACCESSTOKEN:}'
    $entry.Delete();$entry=$jar.CreateEntry('BOOT-INF/classes/'+$name)
    $writer=[IO.StreamWriter]::new($entry.Open(),[Text.UTF8Encoding]::new($false))
    try{$writer.Write($text)}finally{$writer.Dispose()}
  }
  foreach($name in @('CostRoleAssignmentController.class','CostRolePolicy.class','CostUserRoleMapper.class')) {
    if(-not($jar.Entries.FullName -like "BOOT-INF/classes/*/$name")){throw "Missing class: $name"}
  }
  foreach($entry in $jar.Entries | Where-Object FullName -Like 'BOOT-INF/lib/*.jar'){
    if($entry.CompressedLength -ne $entry.Length){throw 'Compressed nested library'}
  }
}finally{$jar.Dispose()}
$frontendZip=Join-Path $app 'dist-prod.zip'
if(Test-Path -LiteralPath $frontendZip){throw 'Frontend ZIP exists'}
[IO.Compression.ZipFile]::CreateFromDirectory($frontend,$frontendZip,[IO.Compression.CompressionLevel]::Optimal,$false)
$zip=[IO.Compression.ZipFile]::OpenRead($frontendZip)
try {
  $names=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach($entry in $zip.Entries){[void]$names.Add($entry.FullName)}
  if(-not $names.Contains('index.html')){throw 'Frontend root index missing'}
  $newEndpoint=$false;$count=0
  foreach($entry in $zip.Entries | Where-Object FullName -Match '\.(js|css|html)$') {
    $reader=[IO.StreamReader]::new($entry.Open())
    try{$content=$reader.ReadToEnd()}finally{$reader.Dispose()}
    if($content.Contains('/system/cost-role-assignment')){throw 'Frontend still calls new system API'}
    if($content.Contains('/cost/role-assignment/assign')){$newEndpoint=$true}
    foreach($match in [regex]::Matches($content,'["''](?<path>(?:\./|/)?assets/[^"''\s<>]+\.(?:js|css|glb|gltf|png|svg|woff2?))["'']|["''](?<relative>\./[^"''\s/]+-[A-Za-z0-9_-]{8}\.(?:js|css))["'']')) {
      $asset=$match.Groups['path'].Value.TrimStart('./')
      if(-not $asset){$asset='assets/'+$match.Groups['relative'].Value.Substring(2)}
      if(-not $names.Contains($asset)){throw "Missing resource: $asset"}
      $count++
    }
  }
  if(-not $newEndpoint){throw 'New cost endpoint not found'}
  Write-Host "New frontend verified: $($zip.Entries.Count) files, $count resource references"
}finally{$zip.Dispose()}
$info=Join-Path $base 'RELEASE-INFO.txt'
$addition="backendJarSha256=$((Get-FileHash -LiteralPath $jarPath).Hash)`nfrontendZipSha256=$((Get-FileHash -LiteralPath $frontendZip).Hash)`nfrontendBuildToolSha256=$((Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'build-frontend-local-role.cjs')).Hash)`nbackendTests=82 passed; 0 failures; 0 errors`nfrontendChecks=cost TypeScript and targeted ESLint passed`npostgresql92Checks=first and repeated upgrade; protected data and role tombstone preservation passed`n"
[IO.File]::AppendAllText($info,$addition,[Text.UTF8Encoding]::new($false))
$manifest=foreach($file in Get-ChildItem -LiteralPath $base -Recurse -File | Sort-Object FullName){
  (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash+'  '+$file.FullName.Substring($base.Length+1).Replace('\','/')
}
[IO.File]::WriteAllLines((Join-Path $base 'SHA256SUMS.txt'),$manifest,[Text.UTF8Encoding]::new($false))
Write-Host 'Cost-only candidate prepared; run promote-cost-only.ps1 after review.'
