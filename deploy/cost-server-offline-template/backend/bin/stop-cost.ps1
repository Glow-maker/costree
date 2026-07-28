$ErrorActionPreference = 'Stop'
$BackendRoot = Split-Path $PSScriptRoot -Parent
$PidFile = Join-Path $BackendRoot 'run\cost-server.pid'
if (-not (Test-Path -LiteralPath $PidFile)) {
    Write-Host 'cost-server is not running (pid file not found).'
    exit 0
}
$pidText = (Get-Content -LiteralPath $PidFile -Raw).Trim()
if ($pidText -notmatch '^\d+$') { throw "Invalid pid file: $PidFile" }
$process = Get-Process -Id ([int]$pidText) -ErrorAction SilentlyContinue
if ($process) {
    Stop-Process -Id $process.Id
    $process.WaitForExit(30000)
    Write-Host "cost-server stopped, pid=$pidText"
} else {
    Write-Host "Process $pidText no longer exists."
}
Remove-Item -LiteralPath $PidFile -Force
