param(
    [string]$PackageRoot = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath($PackageRoot)
$manifestPath = Join-Path $root 'SHA256SUMS.txt'

foreach ($required in @(
    'new-database\costree-cost.sql',
    'upgrade-existing\00-precheck.sql',
    'upgrade-existing\10-upgrade-existing-to-20260722.sql',
    'upgrade-existing\11-upgrade-existing-to-20260728-project-office-form.sql',
    'upgrade-existing\12-upgrade-existing-to-20260817-access-scope.sql',
    'upgrade-existing\13-upgrade-existing-to-20260818-domain-scope.sql',
    'upgrade-existing\14-upgrade-existing-to-20260819-manual-fields-subsystem.sql',
    'upgrade-existing\15-upgrade-existing-to-20260820-warning-workflow.sql',
    'upgrade-existing\20-verify.sql',
    'platform-init\costree-access-role-menu-20260817.sql',
    'platform-init\costree-access-role-menu-dm8-20260817.sql',
    'platform-init\check-cost-permissions-dm8.sql',
    'platform-init\cost-warning-notify-template-20260820.sql',
    'platform-init\cost-warning-notify-template-dm8-20260820.sql',
    'import-templates\costree-amount-sync-template.sql'
)) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $required))) {
        throw "Required PostgreSQL package file is missing: $required"
    }
}

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Manifest not found: $manifestPath"
}

$failed = @()
foreach ($line in Get-Content -LiteralPath $manifestPath) {
    if ([string]::IsNullOrWhiteSpace($line)) {
        continue
    }

    $parts = $line -split '\s+', 2
    if ($parts.Count -ne 2) {
        throw "Invalid manifest line: $line"
    }

    $expected = $parts[0].ToLowerInvariant()
    $relativePath = $parts[1].Trim()
    $filePath = Join-Path $root ($relativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
    if (-not (Test-Path -LiteralPath $filePath)) {
        $failed += "$relativePath (missing)"
        continue
    }

    $actual = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expected) {
        $failed += "$relativePath (hash mismatch)"
    }
}

if ($failed.Count -gt 0) {
    throw "Package verification failed: $($failed -join ', ')"
}

Write-Host 'Package verification passed.'
