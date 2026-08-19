param(
    [string]$PsqlPath = 'psql',
    [string]$Server = '127.0.0.1',
    [int]$Port = 5432,
    [Parameter(Mandatory = $true)][string]$Database,
    [Parameter(Mandatory = $true)][string]$User,
    [Parameter(Mandatory = $true)][long]$TenantId,
    [Parameter(Mandatory = $true)][string]$ReloadSql,
    [Parameter(Mandatory = $true)][switch]$BackupVerified,
    [Parameter(Mandatory = $true)]
    [ValidateSet('I_UNDERSTAND_COST_BUSINESS_RESET')]
    [string]$ConfirmBusinessReset,
    [string]$BatchCode = (Get-Date -Format 'MANUAL-yyyyMMdd-HHmmss')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($ConfirmBusinessReset -ne 'I_UNDERSTAND_COST_BUSINESS_RESET') {
    throw 'Explicit reset confirmation is required.'
}
if (-not $BackupVerified) {
    throw 'A verified full database backup is required before the legacy reset flow.'
}
$ReloadSql = [IO.Path]::GetFullPath($ReloadSql)
if (-not (Test-Path -LiteralPath $ReloadSql -PathType Leaf)) {
    throw "ReloadSql file not found: $ReloadSql"
}
$reloadText = Get-Content -LiteralPath $ReloadSql -Raw -Encoding UTF8
if ($reloadText -match '<[^>]+>') {
    throw "ReloadSql still contains an unreplaced placeholder: $ReloadSql"
}

Write-Warning 'This compatibility flow may clear cost business tables. A verified full database backup is mandatory.'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

function Invoke-SqlFile {
    param([string]$Path, [switch]$ManualVariables)
    Write-Host "[manual-protection] Running $Path"
    $arguments = @('-X', '-v', 'ON_ERROR_STOP=1', '-h', $Server, '-p', $Port, '-U', $User, '-d', $Database)
    if ($ManualVariables) {
        $arguments += @('-v', "manual_batch=$BatchCode", '-v', "manual_tenant=$TenantId")
    }
    $arguments += @('-f', $Path)
    & $PsqlPath @arguments
    if ($LASTEXITCODE -ne 0) { throw "SQL failed: $Path" }
}

Invoke-SqlFile (Join-Path $root '01-创建手工快照表.sql')
Invoke-SqlFile (Join-Path $root '02-生成清库前快照.sql') -ManualVariables
Invoke-SqlFile (Join-Path $root '03-清库前验收.sql')
Invoke-SqlFile $ReloadSql
Invoke-SqlFile (Join-Path $root '04-清库后恢复.sql')
Invoke-SqlFile (Join-Path $root '05-恢复后验收.sql')

Write-Host "[manual-protection] Completed batch $BatchCode. Review restore_exception and keep the database backup."
