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
    'database\postgresql\02-upgrade-existing\12-upgrade-existing-to-20260817-access-scope.sql',
    'database\postgresql\02-upgrade-existing\13-upgrade-existing-to-20260818-domain-scope.sql',
    'database\postgresql\02-upgrade-existing\14-upgrade-existing-to-20260819-manual-fields-subsystem.sql',
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
    'database\postgresql92\02-upgrade-existing\12-upgrade-existing-to-20260817-access-scope.sql',
    'database\postgresql92\02-upgrade-existing\13-upgrade-existing-to-20260818-domain-scope.sql',
    'database\postgresql92\02-upgrade-existing\14-upgrade-existing-to-20260819-manual-fields-subsystem.sql',
    'database\postgresql92\02-upgrade-existing\20-verify.sql',
    'database\postgresql92\03-data-integration\load-and-sync.ps1',
    'database\postgresql92\03-data-integration\10-sync-to-cost.sql',
    'database\postgresql92\03-data-integration\30-diagnose-book-zero.sql',
    'database\postgresql92\03-data-integration\manual\00-使用前总检查.sql',
    'database\postgresql92\03-data-integration\manual\01-同步型号树-cost_model_node.sql',
    'database\postgresql92\03-data-integration\manual\02-同步项目-cost_project.sql',
    'database\postgresql92\03-data-integration\manual\03-同步单位字典-cost_unit_dict.sql',
    'database\postgresql92\03-data-integration\manual\04-同步单位金额-cost_unit_cost_detail.sql',
    'database\postgresql92\03-data-integration\manual\05-同步工作令-cost_work_order.sql',
    'database\postgresql92\03-data-integration\manual\06-同步账面明细-cost_work_order_ledger_detail.sql',
    'database\postgresql92\03-data-integration\manual\07-重算工作令账面成本.sql',
    'database\postgresql92\03-data-integration\manual\08-全链路验收.sql',
    'database\postgresql92\03-data-integration\manual\09-定时任务执行顺序.md',
    'database\postgresql92\03-data-integration\manual\README-内网字段映射说明.md',
    'database\postgresql92\03-data-integration\snapshot-upsert\00-开始这里.md',
    'database\postgresql92\03-data-integration\snapshot-upsert\01-创建标准中间表.sql',
    'database\postgresql92\03-data-integration\snapshot-upsert\02-只清空中间表.sql',
    'database\postgresql92\03-data-integration\snapshot-upsert\03-源数据全量装载模板.sql',
    'database\postgresql92\03-data-integration\snapshot-upsert\04-导入前检查.sql',
    'database\postgresql92\03-data-integration\snapshot-upsert\05-业务表幂等同步.sql',
    'database\postgresql92\03-data-integration\snapshot-upsert\06-重算工作令账面.sql',
    'database\postgresql92\03-data-integration\snapshot-upsert\07-同步后验收.sql',
    'database\postgresql92\03-data-integration\snapshot-upsert\08-缺失数据差异清单.sql',
    'database\postgresql92\03-data-integration\snapshot-upsert\09-定时任务最简顺序.md',
    'database\postgresql92\03-data-integration\snapshot-upsert\10-最简过程.ps1',
    'database\postgresql92\03-data-integration\manual-preservation\00-开始这里.md',
    'database\postgresql92\03-data-integration\manual-preservation\01-创建手工快照表.sql',
    'database\postgresql92\03-data-integration\manual-preservation\02-生成清库前快照.sql',
    'database\postgresql92\03-data-integration\manual-preservation\03-清库前验收.sql',
    'database\postgresql92\03-data-integration\manual-preservation\04-清库后恢复.sql',
    'database\postgresql92\03-data-integration\manual-preservation\05-恢复后验收.sql',
    'database\postgresql92\03-data-integration\manual-preservation\10-旧清库保护过程.ps1',
    'database\postgresql92\03-data-integration\business-upgrade\00-开始这里.md',
    'database\postgresql92\03-data-integration\business-upgrade\01-升级填报保护与分系统字典-20260819.sql',
    'database\postgresql92\03-data-integration\business-upgrade\02-检查填报保护与分系统字典-20260819.sql',
    'database\platform\costree-access-role-menu-mysql-20260817.sql',
    'database\platform\costree-access-role-menu-postgresql-20260817.sql',
    'database\platform\costree-access-role-menu-postgresql92-20260817.sql',
    'database\platform\costree-access-role-menu-dm8-20260817.sql',
    'database\platform\check-cost-permissions.sql',
    'database\platform\check-cost-permissions-dm8.sql',
    'database\platform\required-permissions.txt',
    'docs\11-三级权限升级与授权操作.md',
    'docs\12-成本树三级权限与双库初始化.md',
    'SHA256SUMS.txt'
)) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $required))) {
        throw "Missing package file: $required"
    }
}
$requiredRoleCodes = @(
    'cost_global_viewer',
    'cost_research_department',
    'cost_project_office',
    'cost_unit_user'
)
foreach ($platformScript in @(
    'database\platform\costree-access-role-menu-mysql-20260817.sql',
    'database\platform\costree-access-role-menu-postgresql-20260817.sql',
    'database\platform\costree-access-role-menu-postgresql92-20260817.sql',
    'database\platform\costree-access-role-menu-dm8-20260817.sql'
)) {
    $scriptText = Get-Content -LiteralPath (Join-Path $root $platformScript) -Raw
    foreach ($roleCode in $requiredRoleCodes) {
        if ($scriptText.IndexOf($roleCode, [StringComparison]::Ordinal) -lt 0) {
            throw "Platform role script is missing role ${roleCode}: $platformScript"
        }
    }
}
$checkerText = Get-Content -LiteralPath (Join-Path $root 'database\platform\check-cost-permissions.sql') -Raw
if ($checkerText -notmatch 'expected_mapping_count' -or $checkerText -notmatch '\b29\b') {
    throw 'PostgreSQL platform checker must validate all 29 expected role-menu mappings.'
}
$dmCheckerText = Get-Content -LiteralPath (Join-Path $root 'database\platform\check-cost-permissions-dm8.sql') -Raw
if ($dmCheckerText -notmatch 'EXPECTED_MAPPING_COUNT' -or $dmCheckerText -notmatch '\b29\b') {
    throw 'DM8 platform checker must validate all 29 expected role-menu mappings.'
}

$snapshotRoot = Join-Path $root 'database\postgresql92\03-data-integration\snapshot-upsert'
$snapshotSql = (Get-ChildItem -LiteralPath $snapshotRoot -Filter '*.sql' -File | ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
}) -join "`n"
if ($snapshotSql -match '(?im)^\s*(TRUNCATE|DELETE\s+FROM)\s+(?:TABLE\s+)?(?:"?costree_mvp"?\.)') {
    throw 'Regular snapshot-upsert must not clear costree_mvp business tables.'
}
if ($snapshotSql -match '(?im)^\s*(?:INSERT\s+INTO|UPDATE|DELETE\s+FROM|TRUNCATE(?:\s+TABLE)?)\s+(?:"?costree_mvp"?\.)?cost_project_basic\b') {
    throw 'cost_project_basic must never be an external snapshot write target.'
}
$syncText = Get-Content -LiteralPath (Join-Path $snapshotRoot '05-业务表幂等同步.sql') -Raw -Encoding UTF8
$protectedByTable = @{
    cost_project = @('batch_no', 'stage_codes', 'unit_id', 'unit_name', 'unit_type',
                     'project_office_status', 'unit_fill_status', 'audit_status',
                     'dept_id', 'owner_user_id', 'warning_status', 'remark')
    cost_unit_cost_detail = @('target_cost_amount', 'book_cost_amount', 'approved_amount',
                              'salary_amount', 'material_amount', 'outsource_amount',
                              'manage_amount', 'fuel_power_amount', 'other_amount', 'remark')
    cost_work_order = @('product_target_cost', 'contract_amount', 'income_amount',
                        'book_cost_amount', 'stage_codes', 'max_stage_code',
                        'subsystem_name', 'product_short_name', 'quantity',
                        'vertical_division', 'approved_amount', 'status', 'remark',
                        'import_batch_id', 'dept_id', 'owner_user_id')
}
foreach ($tableName in $protectedByTable.Keys) {
    $match = [regex]::Match($syncText,
        "(?is)UPDATE\s+`"costree_mvp`"\.$tableName\s+\w+\s+SET\s+(?<set>.*?)\s+FROM")
    if (-not $match.Success) { throw "Missing expected UPDATE block: $tableName" }
    foreach ($column in $protectedByTable[$tableName]) {
        if ($match.Groups['set'].Value -match "(?i)\b$column\s*=") {
            throw "External snapshot UPDATE modifies protected field: $tableName.$column"
        }
    }
}
if ($syncText -match '(?is)UPDATE\s+"costree_mvp"\.cost_unit_cost_detail\s+\w+\s+SET\s+(?:(?!FROM).)*(project_id|project_name|domain_code|model_code|unit_id|unit_name|stage_code|deleted)\s*=') {
    throw 'Unit amount UPDATE may only change contract, income and source trace fields.'
}
foreach ($token in @('manual_field_digest', 'manual_field_baseline', '手工字段或流程状态', "load_status = 'SUCCESS'")) {
    if ($snapshotSql.IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "Snapshot-upsert manual-field protection is missing token: $token"
    }
}

$manualRoot = Join-Path $root 'database\postgresql92\03-data-integration\manual-preservation'
$manualText = (Get-ChildItem -LiteralPath $manualRoot -File | ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
}) -join "`n"
foreach ($token in @('SNAPSHOT_READY', 'PRECHECK_OK', 'BackupVerified', 'I_UNDERSTAND_COST_BUSINESS_RESET',
                      'RESTORED_PENDING_VERIFY', 'restore_exception', '恢复后验收')) {
    if ($manualText.IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "Manual reset protection is missing token: $token"
    }
}
$businessUpgradeRoot = Join-Path $root 'database\postgresql92\03-data-integration\business-upgrade'
$businessUpgrade = Get-Content -LiteralPath (Join-Path $businessUpgradeRoot '01-升级填报保护与分系统字典-20260819.sql') -Raw -Encoding UTF8
$businessCheck = Get-Content -LiteralPath (Join-Path $businessUpgradeRoot '02-检查填报保护与分系统字典-20260819.sql') -Raw -Encoding UTF8
foreach ($token in @('cost_subsystem_dict', 'varchar(255)', 'vertical_division DROP DEFAULT', '20260819')) {
    if ($businessUpgrade.IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "20260819 business upgrade is missing token: $token"
    }
}
foreach ($token in @('subsystem_dict_duplicate_name', 'subsystem_dict_invalid_record',
                      'subsystem_dict_business_guard_index', '20260819')) {
    if ($businessCheck.IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "20260819 business checker is missing token: $token"
    }
}
$releaseDoc = Get-ChildItem -LiteralPath (Join-Path $root 'docs') -Filter '10-20260728*.md' -File |
    Select-Object -First 1
if (-not $releaseDoc) {
    throw 'Missing package file: docs\10-20260728*.md'
}
$checked = 0
foreach ($line in Get-Content -LiteralPath $manifest -Encoding UTF8) {
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
