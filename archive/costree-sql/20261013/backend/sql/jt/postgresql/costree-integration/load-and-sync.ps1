param(
    [string]$CsvDirectory = (Join-Path $PSScriptRoot 'csv'),
    [long]$TenantId = 124,
    [string]$BatchCode = ('COST-' + (Get-Date -Format 'yyyyMMddHHmmss'))
)

$ErrorActionPreference = 'Stop'

foreach ($name in @('PGHOST', 'PGUSER', 'PGDATABASE')) {
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
        throw "Environment variable $name is required."
    }
}
if ([string]::IsNullOrWhiteSpace($env:PGPORT)) { $env:PGPORT = '5432' }
if ($BatchCode -notmatch '^[A-Za-z0-9_.-]+$') {
    throw 'BatchCode may only contain letters, numbers, dot, underscore and dash.'
}

$psql = (Get-Command psql -ErrorAction Stop).Source
$csvPath = (Resolve-Path -LiteralPath $CsvDirectory).Path
$tables = @(
    'unit_dict',
    'ads_lc_lshsxm2022',
    'dwd_bd_bfcustomitem_gzl',
    'precontrol_project_unit_amount',
    'project_office_fill',
    'work_order_fill',
    'dws_bu_pz_pzmx_gzl'
)

function Invoke-PsqlFile([string]$FileName) {
    Write-Host "Running $FileName ..."
    & $psql -X -w -v ON_ERROR_STOP=1 -f (Join-Path $PSScriptRoot $FileName)
    if ($LASTEXITCODE -ne 0) { throw "$FileName failed with exit code $LASTEXITCODE." }
}

function Invoke-PsqlCommand([string]$Sql) {
    & $psql -X -w -v ON_ERROR_STOP=1 -c $Sql
    if ($LASTEXITCODE -ne 0) { throw "psql command failed with exit code $LASTEXITCODE." }
}

Invoke-PsqlFile '00-create-staging.sql'
Invoke-PsqlCommand "UPDATE cost_integration.sync_config SET tenant_id=$TenantId, batch_code='$BatchCode', update_time=CURRENT_TIMESTAMP WHERE id=1;"
Invoke-PsqlCommand ('TRUNCATE TABLE ' + (($tables | ForEach-Object { 'cost_integration.' + $_ }) -join ', ') + ';')

foreach ($table in $tables) {
    $file = Join-Path $csvPath ($table + '.csv')
    if (-not (Test-Path -LiteralPath $file)) { throw "Missing CSV file: $file" }
    $copyPath = $file.Replace('\', '/').Replace("'", "''")
    Write-Host "Loading $table ..."
    $columns = if ($table -eq 'project_office_fill') {
        '(source_record_id, project_code, product_attachment_type, subsystem_name, quantity, product_short_name, vertical_division, user_name, acquire_method, batch_category, platform_series, research_unit_name, tax_exempt, cycle_start, cycle_end, stage_code, basic_info, status, source_update_time, source_deleted)'
    } else {
        ''
    }
    Invoke-PsqlCommand "\copy cost_integration.$table$columns FROM '$copyPath' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')"
}

Invoke-PsqlFile '10-sync-to-cost.sql'
Invoke-PsqlFile '20-verify-sync.sql'
Write-Host "Cost integration batch completed: tenant=$TenantId, batch=$BatchCode"
