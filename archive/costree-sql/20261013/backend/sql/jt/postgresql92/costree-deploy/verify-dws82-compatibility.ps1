param()

$ErrorActionPreference = 'Stop'
$postgresql92Root = Split-Path $PSScriptRoot -Parent
$sqlFiles = Get-ChildItem -LiteralPath $postgresql92Root -Recurse -Filter '*.sql' -File
$executableSql = ($sqlFiles | ForEach-Object {
    Get-Content -LiteralPath $_.FullName | Where-Object { $_ -notmatch '^\s*--' }
}) -join "`n"

$forbidden = @(
    @{ Name = 'CREATE INDEX IF NOT EXISTS'; Pattern = '(?i)CREATE\s+INDEX\s+IF\s+NOT\s+EXISTS' },
    @{ Name = 'ADD COLUMN IF NOT EXISTS'; Pattern = '(?i)ADD\s+COLUMN\s+IF\s+NOT\s+EXISTS' },
    @{ Name = 'ON CONFLICT'; Pattern = '(?i)ON\s+CONFLICT' },
    @{ Name = 'ON COMMIT DROP'; Pattern = '(?i)ON\s+COMMIT\s+DROP' },
    @{ Name = 'new COPY option syntax'; Pattern = '(?i)WITH\s*\(\s*FORMAT' },
    @{ Name = 'secondary UNIQUE constraint'; Pattern = '(?i)CONSTRAINT\s+\S+\s+UNIQUE\s*\(' }
)
foreach ($rule in $forbidden) {
    if ($executableSql -match $rule.Pattern) {
        throw "DWS 8.2.1 compatibility check failed: $($rule.Name)"
    }
}

function Resolve-LayoutFile([string[]] $Candidates) {
    foreach ($candidate in $Candidates) {
        $path = Join-Path $postgresql92Root $candidate
        if (Test-Path -LiteralPath $path) { return $path }
    }
    throw "Missing file: $($Candidates -join ' or ')"
}

$required = @(
    @{ Files = @('costree-cost.sql', '01-new-database\costree-cost.sql', 'new-database\costree-cost.sql'); Text = "CREATE INDEX uk_cost_work_order_business" },
    @{ Files = @('costree-cost.sql', '01-new-database\costree-cost.sql', 'new-database\costree-cost.sql'); Text = "CREATE INDEX uk_cost_ledger_source_detail" },
    @{ Files = @('costree-cost.sql', '01-new-database\costree-cost.sql', 'new-database\costree-cost.sql'); Text = "CREATE INDEX uk_cost_unit_cost_project_unit" },
    @{ Files = @('costree-cost.sql', '01-new-database\costree-cost.sql', 'new-database\costree-cost.sql'); Text = "product_short_name varchar(255)" },
    @{ Files = @('costree-cost.sql', '01-new-database\costree-cost.sql', 'new-database\costree-cost.sql'); Text = "cost_user_project_scope" },
    @{ Files = @('costree-cost.sql', '01-new-database\costree-cost.sql', 'new-database\costree-cost.sql'); Text = "cost_user_unit_scope" },
    @{ Files = @('costree-cost.sql', '01-new-database\costree-cost.sql', 'new-database\costree-cost.sql'); Text = "cost_user_domain_scope" },
    @{ Files = @('costree-deploy\10-upgrade-existing-to-20260722.sql', '02-upgrade-existing\10-upgrade-existing-to-20260722.sql', 'upgrade-existing\10-upgrade-existing-to-20260722.sql'); Text = "IF v_is_dws THEN" },
    @{ Files = @('costree-deploy\11-upgrade-existing-to-20260728-project-office-form.sql', '02-upgrade-existing\11-upgrade-existing-to-20260728-project-office-form.sql', 'upgrade-existing\11-upgrade-existing-to-20260728-project-office-form.sql'); Text = "ALTER TABLE cost_project_basic ADD COLUMN quantity" },
    @{ Files = @('costree-deploy\12-upgrade-existing-to-20260817-access-scope.sql', '02-upgrade-existing\12-upgrade-existing-to-20260817-access-scope.sql', 'upgrade-existing\12-upgrade-existing-to-20260817-access-scope.sql'); Text = "cost_user_project_scope" },
    @{ Files = @('costree-deploy\13-upgrade-existing-to-20260818-domain-scope.sql', '02-upgrade-existing\13-upgrade-existing-to-20260818-domain-scope.sql', 'upgrade-existing\13-upgrade-existing-to-20260818-domain-scope.sql'); Text = "uk_cost_user_domain_scope_user" },
    @{ Files = @('costree-deploy\14-upgrade-existing-to-20260819-manual-fields-subsystem.sql', '02-upgrade-existing\14-upgrade-existing-to-20260819-manual-fields-subsystem.sql', 'upgrade-existing\14-upgrade-existing-to-20260819-manual-fields-subsystem.sql'); Text = "cost_subsystem_dict" },
    @{ Files = @('costree-deploy\15-upgrade-existing-to-20260820-warning-workflow.sql', '02-upgrade-existing\15-upgrade-existing-to-20260820-warning-workflow.sql', 'upgrade-existing\15-upgrade-existing-to-20260820-warning-workflow.sql'); Text = "cost_warning_receiver" },
    @{ Files = @('costree-integration\10-sync-to-cost.sql', '03-data-integration\10-sync-to-cost.sql', 'data-integration\10-sync-to-cost.sql'); Text = "pg_advisory_xact_lock" },
    @{ Files = @('costree-integration\10-sync-to-cost.sql', '03-data-integration\10-sync-to-cost.sql', 'data-integration\10-sync-to-cost.sql'); Text = "v_duplicate_count" },
    @{ Files = @('costree-integration\load-and-sync.ps1', '03-data-integration\load-and-sync.ps1', 'data-integration\load-and-sync.ps1'); Text = "gsql" },
    @{ Files = @('costree-integration\load-and-sync.ps1', '03-data-integration\load-and-sync.ps1', 'data-integration\load-and-sync.ps1'); Text = "WITH CSV HEADER" },
    @{ Files = @('costree-integration\manual\03-同步单位字典-cost_unit_dict.sql', '03-data-integration\manual\03-同步单位字典-cost_unit_dict.sql', 'data-integration\manual\03-同步单位字典-cost_unit_dict.sql'); Text = "HEAD_OFFICE" },
    @{ Files = @('costree-integration\manual\04-同步单位金额-cost_unit_cost_detail.sql', '03-data-integration\manual\04-同步单位金额-cost_unit_cost_detail.sql', 'data-integration\manual\04-同步单位金额-cost_unit_cost_detail.sql'); Text = "target_cost_amount, book_cost_amount, approved_amount" },
    @{ Files = @('costree-integration\manual\06-同步账面明细-cost_work_order_ledger_detail.sql', '03-data-integration\manual\06-同步账面明细-cost_work_order_ledger_detail.sql', 'data-integration\manual\06-同步账面明细-cost_work_order_ledger_detail.sql'); Text = "amount / 10000.0" },
    @{ Files = @('costree-integration\manual\07-重算工作令账面成本.sql', '03-data-integration\manual\07-重算工作令账面成本.sql', 'data-integration\manual\07-重算工作令账面成本.sql'); Text = "book_cost_amount = 0" }
)
foreach ($rule in $required) {
    $path = Resolve-LayoutFile $rule.Files
    if ((Get-Content -LiteralPath $path -Raw).IndexOf($rule.Text, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "DWS 8.2.1 compatibility marker missing: $path -> $($rule.Text)"
    }
}

Write-Host "GaussDB(DWS) 8.2.1 static compatibility check passed: $($sqlFiles.Count) SQL files."
