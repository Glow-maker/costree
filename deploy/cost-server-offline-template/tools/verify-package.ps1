param(
    [string]$PackageRoot = (Split-Path $PSScriptRoot -Parent),
    [switch]$RequireFormal
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($PackageRoot)
$manifest = Join-Path $root 'SHA256SUMS.txt'
foreach ($required in @(
    'RELEASE-INFO.txt',
    'backend\app\cost-server.jar',
    'frontend\costree-frontend-dist-prod.zip',
    'frontend\dist\index.html',
    'database\postgresql\01-new-database\costree-cost.sql',
    'database\postgresql\02-upgrade-existing\00-precheck.sql',
    'database\postgresql\02-upgrade-existing\10-upgrade-existing-to-20260722.sql',
    'database\postgresql\02-upgrade-existing\11-upgrade-existing-to-20260728-project-office-form.sql',
    'database\postgresql\02-upgrade-existing\12-upgrade-existing-to-20260817-access-scope.sql',
    'database\postgresql\02-upgrade-existing\13-upgrade-existing-to-20260818-domain-scope.sql',
    'database\postgresql\02-upgrade-existing\14-upgrade-existing-to-20260819-manual-fields-subsystem.sql',
    'database\postgresql\02-upgrade-existing\15-upgrade-existing-to-20260820-warning-workflow.sql',
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
    'database\postgresql92\02-upgrade-existing\15-upgrade-existing-to-20260820-warning-workflow.sql',
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
    'database\platform\costree-access-role-menu-mysql-20260817.sql',
    'database\platform\costree-access-role-menu-postgresql-20260817.sql',
    'database\platform\costree-access-role-menu-postgresql92-20260817.sql',
    'database\platform\check-cost-permissions.sql',
    'database\platform\cost-warning-notify-template-mysql-20260820.sql',
    'database\platform\cost-warning-notify-template-postgresql-20260820.sql',
    'database\platform\cost-warning-notify-template-postgresql92-20260820.sql',
    'database\platform\dm8\00-开始这里.md',
    'database\platform\dm8\01-costree-role-menu-full-20260820.sql',
    'database\platform\dm8\02-cost-warning-notify-template-20260820.sql',
    'database\platform\dm8\03-check-cost-permissions-20260820.sql',
    'database\platform\required-permissions.txt',
    'docs\11-三级权限升级与授权操作.md',
    'docs\12-成本树三级权限与双库初始化.md',
    'docs\13-预警分析与闭环处置.md',
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
    'database\platform\dm8\01-costree-role-menu-full-20260820.sql'
)) {
    $scriptText = Get-Content -LiteralPath (Join-Path $root $platformScript) -Raw
    foreach ($roleCode in $requiredRoleCodes) {
        if ($scriptText.IndexOf($roleCode, [StringComparison]::Ordinal) -lt 0) {
            throw "Platform role script is missing role ${roleCode}: $platformScript"
        }
    }
}
$checkerText = Get-Content -LiteralPath (Join-Path $root 'database\platform\check-cost-permissions.sql') -Raw
if ($checkerText -notmatch 'expected_mapping_count' -or $checkerText -notmatch '\b34\b') {
    throw 'PostgreSQL platform checker must validate all 34 expected role-menu mappings.'
}
$dmCheckerText = Get-Content -LiteralPath (Join-Path $root 'database\platform\dm8\03-check-cost-permissions-20260820.sql') -Raw
if ($dmCheckerText -notmatch 'EXPECTED_MAPPING_COUNT' -or $dmCheckerText -notmatch '\b34\b') {
    throw 'DM8 platform checker must validate all 34 expected role-menu mappings.'
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
if ($snapshotSql -match '(?im)^\s*(?:INSERT\s+INTO|UPDATE|DELETE\s+FROM|TRUNCATE(?:\s+TABLE)?)\s+(?:"?costree_mvp"?\.)?cost_warning_(?:record|receiver|action_log)\b') {
    throw 'Regular snapshot-upsert must not modify warning workflow history tables.'
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
                      'RESTORED_PENDING_VERIFY', 'restore_exception', '恢复后验收',
                      'warning_state_v2', 'warning_receiver', 'warning_action_log')) {
    if ($manualText.IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "Manual reset protection is missing token: $token"
    }
}
$upgradeRoot = Join-Path $root 'database\postgresql92\02-upgrade-existing'
$businessUpgrade = Get-Content -LiteralPath (Join-Path $upgradeRoot '14-upgrade-existing-to-20260819-manual-fields-subsystem.sql') -Raw -Encoding UTF8
$warningUpgrade = Get-Content -LiteralPath (Join-Path $upgradeRoot '15-upgrade-existing-to-20260820-warning-workflow.sql') -Raw -Encoding UTF8
$upgradeCheck = Get-Content -LiteralPath (Join-Path $upgradeRoot '20-verify.sql') -Raw -Encoding UTF8
foreach ($token in @('cost_subsystem_dict', 'varchar(255)', 'vertical_division DROP DEFAULT', '20260819')) {
    if ($businessUpgrade.IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "20260819 business upgrade is missing token: $token"
    }
}
foreach ($token in @('cost_warning_receiver', 'cost_warning_action_log', 'workflow_status', 'active_marker', '20260820')) {
    if ($warningUpgrade.IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "20260820 warning workflow upgrade is missing token: $token"
    }
}
foreach ($token in @('subsystem_dict_duplicate_name', 'subsystem_dict_invalid_record',
                      'warning_active_duplicate_key', 'warning_receiver_duplicate_key',
                      'legacy_status_missing', '20260820')) {
    if ($upgradeCheck.IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "20260820 warning workflow checker is missing token: $token"
    }
}

$forbiddenDirectories = @(
    'database\postgresql92\04-reset-and-reload',
    'database\postgresql\90-optional-test-seed',
    'database\postgresql\91-optional-demo',
    'database\postgresql92\90-optional-test-seed',
    'database\postgresql92\91-optional-demo'
)
foreach ($relative in $forbiddenDirectories) {
    if (Test-Path -LiteralPath (Join-Path $root $relative)) {
        throw "Forbidden production package directory: $relative"
    }
}
if (Get-ChildItem -LiteralPath $root -Recurse -Directory -Force | Where-Object Name -eq 'node_modules' | Select-Object -First 1) {
    throw 'Production package must not contain node_modules.'
}

$releaseInfo = @{}
foreach ($line in Get-Content -LiteralPath (Join-Path $root 'RELEASE-INFO.txt') -Encoding UTF8) {
    if ($line -match '^([^=]+)=(.*)$') { $releaseInfo[$Matches[1]] = $Matches[2] }
}
if ($RequireFormal -and $releaseInfo.releaseType -ne 'formal') { throw 'RELEASE-INFO releaseType must be formal.' }
$jarPath = Join-Path $root 'backend\app\cost-server.jar'
$frontendZipPath = Join-Path $root 'frontend\costree-frontend-dist-prod.zip'
if ((Get-Item -LiteralPath $jarPath).Length -lt 1MB) { throw 'Backend JAR is unexpectedly small.' }
$jarHash = (Get-FileHash -LiteralPath $jarPath -Algorithm SHA256).Hash
$frontendZipHash = (Get-FileHash -LiteralPath $frontendZipPath -Algorithm SHA256).Hash
if ($releaseInfo.backendJarSha256 -ne $jarHash) { throw 'Backend JAR hash does not match RELEASE-INFO.' }
if ($releaseInfo.frontendZipSha256 -ne $frontendZipHash) { throw 'Frontend ZIP hash does not match RELEASE-INFO.' }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($frontendZipPath)
try {
    $indexEntry = $archive.GetEntry('index.html')
    if (-not $indexEntry) { throw 'Frontend ZIP must contain index.html at the archive root.' }
    $zipEntries = @{}
    foreach ($entry in $archive.Entries) { $zipEntries[$entry.FullName.TrimStart('/')] = $entry }
    $reader = [IO.StreamReader]::new($indexEntry.Open(), [Text.Encoding]::UTF8)
    try { $indexText = $reader.ReadToEnd() } finally { $reader.Dispose() }
    $references = [regex]::Matches($indexText, '(?:src|href)=["''](?<path>[^"'']+)["'']') |
        ForEach-Object { $_.Groups['path'].Value } |
        Where-Object { $_ -and $_ -notmatch '^(?:https?:|data:|//|#)' } |
        Sort-Object -Unique
    foreach ($reference in $references) {
        $relative = $reference.Split('?')[0].Split('#')[0].TrimStart('/', '.')
        if ($relative -and -not $zipEntries.ContainsKey($relative)) {
            throw "Frontend ZIP index references a missing asset: $reference"
        }
        $expanded = Join-Path (Join-Path $root 'frontend\dist') $relative.Replace('/', [IO.Path]::DirectorySeparatorChar)
        if ($relative -and -not (Test-Path -LiteralPath $expanded -PathType Leaf)) {
            throw "Expanded frontend is missing asset: $reference"
        }
        if ($relative) {
            $sha = [Security.Cryptography.SHA256]::Create()
            $entryStream = $zipEntries[$relative].Open()
            try { $zipHash = [BitConverter]::ToString($sha.ComputeHash($entryStream)).Replace('-', '') }
            finally { $entryStream.Dispose(); $sha.Dispose() }
            $expandedHash = (Get-FileHash -LiteralPath $expanded -Algorithm SHA256).Hash
            if ($zipHash -ne $expandedHash) { throw "Expanded frontend asset differs from ZIP: $reference" }
        }
    }
    $expandedIndexText = Get-Content -LiteralPath (Join-Path $root 'frontend\dist\index.html') -Raw -Encoding UTF8
    if ($indexText -ne $expandedIndexText) { throw 'Expanded frontend index.html differs from ZIP.' }
} finally {
    $archive.Dispose()
}
$releaseDoc = Get-ChildItem -LiteralPath (Join-Path $root 'docs') -Filter '10-20260728*.md' -File |
    Select-Object -First 1
if (-not $releaseDoc) {
    throw 'Missing package file: docs\10-20260728*.md'
}
$checked = 0
$manifestFiles = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($line in Get-Content -LiteralPath $manifest -Encoding UTF8) {
    if (-not $line.Trim()) { continue }
    if ($line -notmatch '^([0-9a-fA-F]{64}) \*(.+)$') { throw "Invalid manifest line: $line" }
    $expected = $Matches[1].ToLowerInvariant()
    $relative = $Matches[2].Replace('/', [IO.Path]::DirectorySeparatorChar)
    [void]$manifestFiles.Add($relative)
    $file = Join-Path $root $relative
    if (-not (Test-Path -LiteralPath $file)) { throw "Manifest file missing: $relative" }
    $actual = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expected) { throw "SHA256 mismatch: $relative" }
    $checked++
}
$unlistedFiles = Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object {
    $_.FullName -ne $manifest -and
    -not $manifestFiles.Contains($_.FullName.Substring($root.Length + 1))
}
if ($unlistedFiles) {
    throw "SHA256SUMS.txt does not cover package file: $($unlistedFiles[0].FullName.Substring($root.Length + 1))"
}
Write-Host "Package verification passed: $checked files."
