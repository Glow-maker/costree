$BackendRoot = Split-Path $PSScriptRoot -Parent
$PidFile = Join-Path $BackendRoot 'run\cost-server.pid'
if (-not (Test-Path -LiteralPath $PidFile)) {
    Write-Host 'cost-server: stopped'
    exit 1
}
$pidText = (Get-Content -LiteralPath $PidFile -Raw).Trim()
$process = if ($pidText -match '^\d+$') { Get-Process -Id ([int]$pidText) -ErrorAction SilentlyContinue }
if ($process) {
    Write-Host "cost-server: running, pid=$pidText"
    exit 0
}
Write-Host "cost-server: stale pid file ($pidText)"
exit 2
