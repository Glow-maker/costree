param(
    [string]$PsqlPath = 'psql',
    [string]$Server = '127.0.0.1',
    [int]$Port = 5432,
    [Parameter(Mandatory = $true)][string]$Database,
    [Parameter(Mandatory = $true)][string]$User,
    [string]$LoadSql = '',
    [switch]$SkipClearAndLoad
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $SkipClearAndLoad) {
    if ([string]::IsNullOrWhiteSpace($LoadSql)) {
        throw 'LoadSql is required unless SkipClearAndLoad is specified. Copy and customize 03-源数据全量装载模板.sql first.'
    }
    $LoadSql = [System.IO.Path]::GetFullPath($LoadSql)
    if (-not (Test-Path -LiteralPath $LoadSql -PathType Leaf)) {
        throw "LoadSql file not found: $LoadSql"
    }
    if ((Get-Content -LiteralPath $LoadSql -Raw -Encoding UTF8) -match '<源系统schema>') {
        throw "LoadSql still contains the <源系统schema> placeholder: $LoadSql"
    }
}

$files = @(Join-Path $scriptRoot '01-创建标准中间表.sql')
if (-not $SkipClearAndLoad) {
    $files += Join-Path $scriptRoot '02-只清空中间表.sql'
    $files += $LoadSql
}
$files += Join-Path $scriptRoot '04-导入前检查.sql'
$files += Join-Path $scriptRoot '05-业务表幂等同步.sql'
$files += Join-Path $scriptRoot '06-重算工作令账面.sql'
$files += Join-Path $scriptRoot '07-同步后验收.sql'
$files += Join-Path $scriptRoot '08-缺失数据差异清单.sql'

foreach ($file in $files) {
    if (-not (Test-Path -LiteralPath $file)) {
        throw "SQL file not found: $file"
    }
    Write-Host "[cost-sync] Running $file"
    & $PsqlPath -X -v ON_ERROR_STOP=1 -h $Server -p $Port -U $User -d $Database -f $file
    if ($LASTEXITCODE -ne 0) {
        throw "Cost sync stopped because SQL failed: $file"
    }
}

Write-Host '[cost-sync] Completed. Verify the 07 acceptance and 08 difference results.'
