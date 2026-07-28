param(
    [Parameter(Mandatory = $true)][string]$WebRoot,
    [string]$BackupRoot = (Join-Path $PSScriptRoot 'backup')
)

$ErrorActionPreference = 'Stop'
$Source = Join-Path $PSScriptRoot 'dist'
if (-not (Test-Path -LiteralPath (Join-Path $Source 'index.html'))) {
    throw "Frontend artifact is incomplete: $Source"
}
$target = [IO.Path]::GetFullPath($WebRoot)
$root = [IO.Path]::GetPathRoot($target)
if ($target.TrimEnd('\') -eq $root.TrimEnd('\') -or $target.Length -lt 8) {
    throw "Unsafe WebRoot: $target"
}
New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
if (Test-Path -LiteralPath $target) {
    $backupFile = Join-Path $BackupRoot ("frontend-" + (Get-Date -Format 'yyyyMMddHHmmss') + '.zip')
    $existing = Get-ChildItem -LiteralPath $target -Force
    if ($existing) { Compress-Archive -Path ($existing.FullName) -DestinationPath $backupFile -Force }
    Get-ChildItem -LiteralPath $target -Force | Remove-Item -Recurse -Force
} else {
    New-Item -ItemType Directory -Force -Path $target | Out-Null
}
Copy-Item -Path (Join-Path $Source '*') -Destination $target -Recurse -Force
Write-Host "Frontend deployed to $target"
Write-Host 'Reload Nginx and clear browser cache before verification.'
