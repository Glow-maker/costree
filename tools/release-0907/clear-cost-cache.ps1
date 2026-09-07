param(
    [Parameter(Mandatory=$true)][string]$KeysFile,
    [Parameter(Mandatory=$true)][string]$RedisHost,
    [Parameter(Mandatory=$true)][int]$Database,
    [Parameter(Mandatory=$true)][long]$TenantId,
    [int]$Port=6379,
    [string]$Prefix='',
    [ValidateSet('tenant','global')][string]$CacheMode='tenant',
    [switch]$Execute,
    [switch]$Tls
)
$ErrorActionPreference='Stop'
if ($Database -lt 0 -or $TenantId -le 0) { throw 'Invalid database or tenant' }
if ($Prefix -notmatch '^[A-Za-z0-9_:-]*$') { throw 'Invalid prefix' }
$permissions = @('cost:project:query','cost:project-basic:query','cost:project-basic:create','cost:project-basic:update',
 'cost:project-basic:approve','cost:project-basic:delete','cost:project-basic:import','cost:project-basic:export',
 'cost:work-order:query','cost:work-order:create','cost:work-order:update','cost:work-order:approve',
 'cost:work-order:delete','cost:work-order:import','cost:work-order:export','cost:warning:query','cost:warning:push',
 'cost:warning:feedback','cost:warning:close','cost:model-comparison:query','cost:model-comparison:export')
$templates = @('COST_WARNING_PENDING_DISPOSITION','COST_WARNING_FEEDBACK_SUBMITTED','COST_WARNING_RETURNED','COST_WARNING_CLOSED')
$suffix = if ($CacheMode -eq 'tenant') { "${TenantId}:" } else { '' }
$idPattern = '^' + [regex]::Escape($Prefix) + '(role|menu_role_ids):' + [regex]::Escape($suffix) + '[0-9]+$'
$keys = @(Get-Content -LiteralPath $KeysFile -Encoding UTF8 | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
if ($keys.Count -eq 0 -or $keys.Count -gt 100) { throw 'Empty or unexpectedly large key list; export only CACHE_KEY values without header' }
foreach ($key in $keys) {
    $allowed = $key -match $idPattern
    if ($permissions | Where-Object { $key -ceq "${Prefix}permission_menu_ids:$_" }) { $allowed = $true }
    if ($templates | Where-Object { $key -ceq "${Prefix}notify_template:$_" }) { $allowed = $true }
    if (-not $allowed) { throw "Key outside cost cache allowlist: $key" }
}
$cli=Get-Command redis-cli -ErrorAction Stop
$cliArgs=@('-h',$RedisHost,'-p',"$Port",'-n',"$Database",'--raw')
if ($Tls) { $cliArgs += '--tls' }
# Password must be supplied by REDISCLI_AUTH, never included in command arguments or logs.
foreach ($key in $keys) {
    $exists = & $cli.Source @cliArgs EXISTS $key
    if ($LASTEXITCODE -ne 0 -or "$exists" -notmatch '^[01]$') { throw "Redis check failed: $exists" }
    Write-Host "$(if ($Execute) {'EXECUTE'} else {'PREVIEW'}) exists=$exists $key"
    if ($Execute -and "$exists" -eq '1') {
        $deleted = & $cli.Source @cliArgs UNLINK $key
        if ("$deleted" -match 'unknown command') { $deleted = & $cli.Source @cliArgs DEL $key }
        if ($LASTEXITCODE -ne 0 -or "$deleted" -notmatch '^[01]$') { throw "Redis delete failed: $deleted" }
    }
}
if (-not $Execute) { Write-Host 'Preview only. Verify database/prefix/key IDs, then repeat with -Execute.' }
