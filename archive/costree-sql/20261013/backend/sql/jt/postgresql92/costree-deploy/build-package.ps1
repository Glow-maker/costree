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

& (Join-Path $deployDir 'verify-dws82-compatibility.ps1')

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
$importDir = Join-Path $outputPath 'data-integration'
$platformInitDir = Join-Path $outputPath 'platform-init'
New-Item -ItemType Directory -Path $newDatabaseDir, $upgradeDir, $importDir, $platformInitDir | Out-Null

Copy-Item -LiteralPath (Join-Path $postgresDir 'costree-cost.sql') -Destination $newDatabaseDir
Copy-Item -LiteralPath (Join-Path $postgresDir 'README.md') -Destination $outputPath
Copy-Item -LiteralPath (Join-Path $postgresDir 'costree-access-role-menu-20260817.sql') -Destination $platformInitDir
Copy-Item -LiteralPath (Join-Path $postgresDir 'cost-warning-notify-template-20260820.sql') -Destination $platformInitDir
Copy-Item -LiteralPath (Join-Path $repositoryDir 'sql\jt\dm\costree-access-role-menu-20260817.sql') `
    -Destination (Join-Path $platformInitDir 'costree-access-role-menu-dm8-20260817.sql')
Copy-Item -LiteralPath (Join-Path $repositoryDir 'sql\jt\dm\check-cost-permissions-20260817.sql') `
    -Destination (Join-Path $platformInitDir 'check-cost-permissions-dm8.sql')
Copy-Item -LiteralPath (Join-Path $repositoryDir 'sql\jt\dm\cost-warning-notify-template-20260820.sql') `
    -Destination (Join-Path $platformInitDir 'cost-warning-notify-template-dm8-20260820.sql')
Copy-Item -Path (Join-Path $postgresDir 'costree-integration\*') -Destination $importDir -Recurse
Get-ChildItem -LiteralPath $deployDir -File |
    Where-Object { $_.Name -ne 'build-package.ps1' } |
    Copy-Item -Destination $upgradeDir

if ($IncludeSeed) {
    throw 'PostgreSQL 9.2 package does not include the old seed. Use -IncludeDemo for the validated closed-loop dataset.'
}

if ($IncludeDemo) {
    $demoDir = Join-Path $outputPath 'optional-demo-source'
    Copy-Item -LiteralPath (Join-Path $postgresDir 'costree-demo-source') -Destination $demoDir -Recurse
}

$releaseInfo = @(
    'schemaVersion=20260820'
    'databaseVersion=PostgreSQL 9.2.x / GaussDB(DWS) 8.2.1'
    'validatedVersion=PostgreSQL 9.2.23'
    'dwsCompatibility=DWS distribution-key-safe indexes, serialized sync and duplicate validation'
    'platformInitDialects=PostgreSQL 9.2/GaussDB; Dameng DM8 (MQB)'
    "backendCommit=$gitCommit"
    "repositoryDirty=$isDirty"
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
