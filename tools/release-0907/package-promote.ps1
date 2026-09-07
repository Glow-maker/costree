param([switch]$Promote)
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$staging=Join-Path $workspace 'cost-server-offline-package-20260907-staging'
$archivePath=Join-Path $workspace 'cost-server-offline-package-20260907-staging.zip'
$final=Join-Path $workspace 'cost-server-offline-package'
$finalZip=$final+'.zip'
foreach($target in @($staging,$archivePath,$final,$finalZip)){
  if((Split-Path ([IO.Path]::GetFullPath($target)) -Parent) -ne $workspace){throw "Outside workspace: $target"}
}
if(Test-Path -LiteralPath $archivePath){throw 'Staging ZIP exists; preserve it, do not overwrite'}
& (Join-Path $staging 'tools/verify-package.ps1') -PackageRoot $staging -RequireFormal
& (Join-Path $staging 'tools/verify-0907-artifacts.ps1') -PackageRoot $staging
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=[IO.Compression.ZipFile]::Open($archivePath,[IO.Compression.ZipArchiveMode]::Create)
try{
  foreach($file in Get-ChildItem -LiteralPath $staging -Recurse -File){
    $relative=$file.FullName.Substring($staging.Length+1).Replace('\','/')
    [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$file.FullName,('cost-server-offline-package/'+$relative),[IO.Compression.CompressionLevel]::Optimal)
  }
}finally{$zip.Dispose()}
$verificationRoot=Join-Path $workspace ('.release-0907-validation/extracted-'+[guid]::NewGuid().ToString('N'))
[IO.Compression.ZipFile]::ExtractToDirectory($archivePath,$verificationRoot)
$unpacked=Join-Path $verificationRoot 'cost-server-offline-package'
& (Join-Path $unpacked 'tools/verify-package.ps1') -PackageRoot $unpacked -RequireFormal
& (Join-Path $unpacked 'tools/verify-0907-artifacts.ps1') -PackageRoot $unpacked
$env:REQUIRE_FORMAL='1'
$bashOutput=& bash (Join-Path $unpacked 'tools/verify-package.sh') $unpacked
if($LASTEXITCODE -ne 0){throw 'Extracted ZIP Bash verification failed'}
Write-Host ($bashOutput | Select-Object -Last 1)
if((Get-FileHash (Join-Path $staging 'SHA256SUMS.txt')).Hash -ne (Get-FileHash (Join-Path $unpacked 'SHA256SUMS.txt')).Hash){throw 'Extracted manifest differs'}
$hash=(Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
Write-Host "ZIP fully verified: $hash"
if(-not $Promote){Write-Host 'Not promoted. ZIP and directory retained in staging.';return}
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir=$final+'.backup-'+$stamp
$backupZip=$final+'.backup-'+$stamp+'.zip'
if((Test-Path -LiteralPath $backupDir) -or (Test-Path -LiteralPath $backupZip)){throw 'Backup names already exist'}
# Exact, validated artifact targets only. Old deliverables remain recoverable.
if(Test-Path -LiteralPath $final){Move-Item -LiteralPath $final -Destination $backupDir}
if(Test-Path -LiteralPath $finalZip){Move-Item -LiteralPath $finalZip -Destination $backupZip}
Move-Item -LiteralPath $staging -Destination $final
Move-Item -LiteralPath $archivePath -Destination $finalZip
if((Get-FileHash -LiteralPath $finalZip -Algorithm SHA256).Hash -ne $hash){throw 'Final ZIP hash changed'}
$result=[ordered]@{directory=$final;zip=$finalZip;sha256=$hash;backupDirectory=$backupDir;backupZip=$backupZip;extractedValidation=$unpacked}
[IO.File]::WriteAllText((Join-Path $workspace '.release-0907-validation/promotion-result.json'),($result|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
$result|ConvertTo-Json
