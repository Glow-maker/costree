param([string]$PackageRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($PackageRoot)
$manifest = Join-Path $root 'SHA256SUMS.txt'
foreach ($required in @(
    'RELEASE-INFO.txt',
    'backend\app\cost-server.jar',
    'frontend\dist\index.html',
    'database\postgresql\01-new-database\costree-cost.sql',
    'database\postgresql\02-upgrade-existing\00-precheck.sql',
    'database\postgresql\02-upgrade-existing\10-upgrade-existing-to-20260722.sql',
    'database\postgresql\02-upgrade-existing\11-upgrade-existing-to-20260728-project-office-form.sql',
    'database\postgresql\02-upgrade-existing\20-verify.sql',
    'database\postgresql\03-data-integration\10-sync-to-cost.sql',
    'database\postgresql\03-data-integration\30-diagnose-book-zero.sql',
    'database\postgresql92\01-new-database\costree-cost.sql',
    'database\postgresql92\README.md',
    'database\postgresql92\02-upgrade-existing\00-dws-precheck.sql',
    'database\postgresql92\02-upgrade-existing\run-new-database.ps1',
    'database\postgresql92\02-upgrade-existing\run-upgrade.ps1',
    'database\postgresql92\02-upgrade-existing\verify-dws82-compatibility.ps1',
    'database\postgresql92\02-upgrade-existing\10-upgrade-existing-to-20260722.sql',
    'database\postgresql92\02-upgrade-existing\11-upgrade-existing-to-20260728-project-office-form.sql',
    'database\postgresql92\02-upgrade-existing\20-verify.sql',
    'database\postgresql92\03-data-integration\load-and-sync.ps1',
    'database\postgresql92\03-data-integration\10-sync-to-cost.sql',
    'database\postgresql92\03-data-integration\30-diagnose-book-zero.sql',
    'docs\10-20260728字段与页面变更.md',
    'SHA256SUMS.txt'
)) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $required))) {
        throw "Missing package file: $required"
    }
}
$checked = 0
foreach ($line in Get-Content -LiteralPath $manifest) {
    if (-not $line.Trim()) { continue }
    if ($line -notmatch '^([0-9a-fA-F]{64}) \*(.+)$') { throw "Invalid manifest line: $line" }
    $expected = $Matches[1].ToLowerInvariant()
    $relative = $Matches[2].Replace('/', [IO.Path]::DirectorySeparatorChar)
    $file = Join-Path $root $relative
    if (-not (Test-Path -LiteralPath $file)) { throw "Manifest file missing: $relative" }
    $actual = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expected) { throw "SHA256 mismatch: $relative" }
    $checked++
}
Write-Host "Package verification passed: $checked files."
