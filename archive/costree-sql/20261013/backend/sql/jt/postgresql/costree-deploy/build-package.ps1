param(
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,
    [switch]$IncludeSeed,
    [switch]$IncludeDemo,
    [switch]$AllowDirty
)

$ErrorActionPreference = 'Stop'

$deployDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$postgresDir = Split-Path -Parent $deployDir
$repositoryDir = (Resolve-Path (Join-Path $postgresDir '..\..\..')).Path
$outputPath = [System.IO.Path]::GetFullPath($OutputDirectory)
$zipPath = "$outputPath.zip"

if (Test-Path -LiteralPath $outputPath) {
    throw "Output directory already exists: $outputPath"
}
if (Test-Path -LiteralPath $zipPath) {
    throw "Output archive already exists: $zipPath"
}

$gitCommit = (git -C $repositoryDir rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to read the backend Git commit.'
}
$gitStatus = git -C $repositoryDir status --porcelain
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to read the backend Git status.'
}
$isDirty = $null -ne $gitStatus -and @($gitStatus).Count -gt 0
if ($isDirty -and -not $AllowDirty) {
    throw 'Repository has uncommitted changes. Commit them first or use -AllowDirty for a non-release test package.'
}

$newDatabaseDir = Join-Path $outputPath 'new-database'
$upgradeDir = Join-Path $outputPath 'upgrade-existing'
$importDir = Join-Path $outputPath 'import-templates'
$platformInitDir = Join-Path $outputPath 'platform-init'
New-Item -ItemType Directory -Path $newDatabaseDir, $upgradeDir, $importDir, $platformInitDir | Out-Null

Copy-Item -LiteralPath (Join-Path $postgresDir 'costree-cost.sql') -Destination $newDatabaseDir
Copy-Item -LiteralPath (Join-Path $postgresDir 'costree-amount-sync-template.sql') -Destination $importDir
Copy-Item -LiteralPath (Join-Path $postgresDir 'costree-access-role-menu-20260817.sql') -Destination $platformInitDir
Copy-Item -LiteralPath (Join-Path $postgresDir 'cost-warning-notify-template-20260820.sql') -Destination $platformInitDir
Copy-Item -LiteralPath (Join-Path $repositoryDir 'sql\jt\dm\costree-access-role-menu-20260817.sql') `
    -Destination (Join-Path $platformInitDir 'costree-access-role-menu-dm8-20260817.sql')
Copy-Item -LiteralPath (Join-Path $repositoryDir 'sql\jt\dm\check-cost-permissions-20260817.sql') `
    -Destination (Join-Path $platformInitDir 'check-cost-permissions-dm8.sql')
Copy-Item -LiteralPath (Join-Path $repositoryDir 'sql\jt\dm\cost-warning-notify-template-20260820.sql') `
    -Destination (Join-Path $platformInitDir 'cost-warning-notify-template-dm8-20260820.sql')
Get-ChildItem -LiteralPath $deployDir -File |
    Where-Object { $_.Name -ne 'build-package.ps1' } |
    Copy-Item -Destination $upgradeDir

if ($IncludeSeed) {
    $seedDir = Join-Path $outputPath 'optional-test-data'
    New-Item -ItemType Directory -Path $seedDir | Out-Null
    Copy-Item -LiteralPath (Join-Path $postgresDir 'costree-cost-seed.sql') -Destination $seedDir
}

if ($IncludeDemo) {
    $demoDir = Join-Path $outputPath 'optional-demo-source'
    Copy-Item -LiteralPath (Join-Path $postgresDir 'costree-demo-source') -Destination $demoDir -Recurse
}

$releaseInfo = @(
    'schemaVersion=20260820'
    "backendCommit=$gitCommit"
    "repositoryDirty=$isDirty"
    'platformInitDialects=PostgreSQL 14+; Dameng DM8 (MQB)'
    "generatedAt=$([DateTimeOffset]::Now.ToString('o'))"
    "seedIncluded=$IncludeSeed"
    "demoIncluded=$IncludeDemo"
)
Set-Content -LiteralPath (Join-Path $outputPath 'RELEASE-INFO.txt') -Value $releaseInfo -Encoding utf8

$manifestPath = Join-Path $outputPath 'SHA256SUMS.txt'
$manifest = Get-ChildItem -LiteralPath $outputPath -File -Recurse |
    Where-Object { $_.FullName -ne $manifestPath } |
    Sort-Object FullName |
    ForEach-Object {
        $relativePath = $_.FullName.Substring($outputPath.TrimEnd('\').Length + 1).Replace('\', '/')
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        "$hash  $relativePath"
    }
Set-Content -LiteralPath $manifestPath -Value $manifest -Encoding ascii

Compress-Archive -LiteralPath $outputPath -DestinationPath $zipPath -CompressionLevel Optimal

Write-Host "Package directory: $outputPath"
Write-Host "Package archive:   $zipPath"
