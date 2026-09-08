param([switch]$Promote)
$ErrorActionPreference = 'Stop'
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$staging = Join-Path $workspace 'cost-server-offline-package-20260907-cost-only-staging'
$archive = $staging + '.zip'
$final = Join-Path $workspace 'cost-server-offline-package'
$finalZip = $final + '.zip'
foreach ($target in @($staging, $archive, $final, $finalZip)) {
    if ((Split-Path ([IO.Path]::GetFullPath($target)) -Parent) -ne $workspace) { throw 'Path outside workspace' }
}
if (Test-Path -LiteralPath $archive) { throw 'Archive already exists' }
function Test-EssentialPackage([string]$dir) {
    $base = Join-Path $dir '00-现场必用'
    $top = @(Get-ChildItem -LiteralPath $dir)
    if ($top.Count -ne 1 -or $top[0].Name -ne '00-现场必用') { throw 'Only essentials allowed' }
    $files = @(Get-ChildItem -LiteralPath $base -Recurse -File)
    $jars = @($files | Where-Object Extension -eq '.jar')
    $zips = @($files | Where-Object Extension -eq '.zip')
    if ($jars.Count -ne 1 -or $jars[0].Name -ne 'cost-server.jar') { throw 'Expected only one cost JAR' }
    if ($zips.Count -ne 1 -or $zips[0].Name -ne 'dist-prod.zip') { throw 'Expected only one frontend ZIP' }
    $manifest = @(Get-Content -LiteralPath (Join-Path $base 'SHA256SUMS.txt'))
    if ($manifest.Count -ne ($files.Count - 1)) { throw 'Manifest coverage mismatch' }
    $seen = @{}
    foreach ($line in $manifest) {
        if ($line -notmatch '^([A-Fa-f0-9]{64})  (.+)$') { throw 'Invalid manifest' }
        $expected = $Matches[1]; $relative = $Matches[2]
        $filePath = [IO.Path]::GetFullPath((Join-Path $base $relative))
        if (-not $filePath.StartsWith($base + [IO.Path]::DirectorySeparatorChar) -or $seen.ContainsKey($relative)) { throw 'Invalid manifest path' }
        $seen[$relative] = $true
        if ((Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash -ne $expected) { throw "Hash mismatch: $relative" }
    }
    Write-Host "Essential package PASS: $($files.Count) files, 1 cost JAR, 1 frontend ZIP"
}
Test-EssentialPackage $staging
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::Open($archive, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in Get-ChildItem -LiteralPath $staging -Recurse -File) {
        $name = 'cost-server-offline-package/' + $file.FullName.Substring($staging.Length + 1).Replace('\', '/')
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $name, [IO.Compression.CompressionLevel]::Optimal)
    }
} finally { $zip.Dispose() }
$verify = Join-Path $workspace ('.release-0907-validation/cost-only-' + [guid]::NewGuid().ToString('N'))
[IO.Compression.ZipFile]::ExtractToDirectory($archive, $verify)
Test-EssentialPackage (Join-Path $verify 'cost-server-offline-package')
$zipHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
if ($Promote) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupDir = $final + '.backup-' + $stamp
    $backupZip = $final + '.backup-' + $stamp + '.zip'
    if ((Test-Path -LiteralPath $backupDir) -or (Test-Path -LiteralPath $backupZip)) { throw 'Backup exists' }
    Move-Item -LiteralPath $final -Destination $backupDir
    Move-Item -LiteralPath $finalZip -Destination $backupZip
    Move-Item -LiteralPath $staging -Destination $final
    Move-Item -LiteralPath $archive -Destination $finalZip
    Test-EssentialPackage $final
    if ((Get-FileHash -LiteralPath $finalZip -Algorithm SHA256).Hash -ne $zipHash) { throw 'Promoted ZIP differs' }
    [ordered]@{ directory = $final; zip = $finalZip; sha256 = $zipHash; bytes = (Get-Item -LiteralPath $finalZip).Length; backupDirectory = $backupDir; backupZip = $backupZip } | ConvertTo-Json
}
# This exact freshly created validation directory contains only our extracted copy.
$resolvedVerify = [IO.Path]::GetFullPath($verify)
$validationRoot = [IO.Path]::GetFullPath((Join-Path $workspace '.release-0907-validation'))
if ((Split-Path $resolvedVerify -Parent) -ne $validationRoot -or (Split-Path $resolvedVerify -Leaf) -notmatch '^cost-only-[a-f0-9]{32}$') { throw 'Unsafe validation cleanup' }
Remove-Item -LiteralPath $resolvedVerify -Recurse -Force
