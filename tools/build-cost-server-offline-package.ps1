param(
    [string]$BackendRoot,
    [string]$FrontendRoot,
    [string]$OutputDirectory,
    [int]$FrontendMaxOldSpaceMb = 8000,
    [switch]$SkipBuild,
    [switch]$IncludeSeed,
    [switch]$IncludeDemo,
    [switch]$AllowDirty
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$BackendRoot = if ($BackendRoot) { [IO.Path]::GetFullPath($BackendRoot) } else {
    [IO.Path]::GetFullPath((Join-Path $Root '..\sqlbot_with_bcback\baback'))
}
$FrontendRoot = if ($FrontendRoot) { [IO.Path]::GetFullPath($FrontendRoot) } else {
    [IO.Path]::GetFullPath((Join-Path $Root '..\sqlbot_with_bcback\costree-frontend'))
}
$OutputDirectory = if ($OutputDirectory) { [IO.Path]::GetFullPath($OutputDirectory) } else {
    Join-Path $Root 'cost-server-offline-package'
}
$TemplateRoot = Join-Path $Root 'deploy\cost-server-offline-template'
$SchemaVersion = '20260819'

function Assert-Directory([string]$Path, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { throw "$Label not found: $Path" }
}

function Invoke-External([string]$Label, [scriptblock]$Command) {
    Write-Host "==> $Label"
    & $Command
    if ($LASTEXITCODE -ne 0) { throw "$Label failed with exit code $LASTEXITCODE" }
}

function Get-GitState([string]$Repository) {
    $commit = (& git -C $Repository rev-parse HEAD).Trim()
    $branch = (& git -C $Repository branch --show-current).Trim()
    $status = @(& git -C $Repository status --porcelain)
    [pscustomobject]@{ Commit = $commit; Branch = $branch; Status = $status; Dirty = $status.Count -gt 0 }
}

function Copy-DirectoryContents([string]$Source, [string]$Destination) {
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force
    }
}

Assert-Directory $BackendRoot 'Backend repository'
Assert-Directory $FrontendRoot 'Frontend repository'
Assert-Directory $TemplateRoot 'Offline package template'

& (Join-Path $BackendRoot 'sql\postgresql92\costree-deploy\verify-dws82-compatibility.ps1')

$rootState = Get-GitState $Root
$backendState = Get-GitState $BackendRoot
$frontendState = Get-GitState $FrontendRoot
$dirtyRepositories = @()
if ($rootState.Dirty) { $dirtyRepositories += 'docs-root' }
if ($backendState.Dirty) { $dirtyRepositories += 'backend' }
if ($frontendState.Dirty) { $dirtyRepositories += 'frontend' }
if ($dirtyRepositories.Count -gt 0 -and -not $AllowDirty) {
    throw "Dirty repositories: $($dirtyRepositories -join ', '). Commit first or use -AllowDirty for a candidate package."
}

if (-not $SkipBuild) {
    $oldMavenOpts = $env:MAVEN_OPTS
    try {
        $env:MAVEN_OPTS = '-Xms128m -Xmx768m -XX:MaxMetaspaceSize=256m'
        Push-Location $BackendRoot
        Invoke-External 'Backend package' { mvn -pl yudao-module-cost/yudao-module-cost-biz -am -DskipTests package }
        Pop-Location
    } finally {
        if ((Get-Location).Path -eq $BackendRoot) { Pop-Location }
        $env:MAVEN_OPTS = $oldMavenOpts
    }

    Push-Location $FrontendRoot
    try {
        $oldNodeOptions = $env:NODE_OPTIONS
        $env:NODE_OPTIONS = '--max-old-space-size=2048'
        Invoke-External 'Frontend cost type check' { pnpm run ts:check:cost }
        $node = (Get-Command node -ErrorAction Stop).Source
        $vite = Join-Path $FrontendRoot 'node_modules\vite\bin\vite.js'
        if (-not (Test-Path -LiteralPath $vite)) { throw "Vite not installed: $vite" }
        Invoke-External 'Frontend production build' { & $node "--max_old_space_size=$FrontendMaxOldSpaceMb" $vite build --mode prod }
        $env:NODE_OPTIONS = $oldNodeOptions
    } finally {
        if ((Get-Location).Path -eq $FrontendRoot) { Pop-Location }
        $env:NODE_OPTIONS = $oldNodeOptions
    }
}

$jar = Get-ChildItem -LiteralPath (Join-Path $BackendRoot 'yudao-module-cost\yudao-module-cost-biz\target') -Filter '*.jar' -File |
    Where-Object { $_.Name -notmatch 'original|sources|javadoc' } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $jar) { throw 'Backend jar was not found after build.' }
$frontendDist = Join-Path $FrontendRoot 'dist-prod'
if (-not (Test-Path -LiteralPath (Join-Path $frontendDist 'index.html'))) { throw "Frontend dist is missing: $frontendDist" }

$output = [IO.Path]::GetFullPath($OutputDirectory)
$outputLeaf = Split-Path $output -Leaf
$outputRoot = [IO.Path]::GetPathRoot($output)
if ($output.TrimEnd('\') -eq $outputRoot.TrimEnd('\') -or $outputLeaf -notlike 'cost-server-offline-package*') {
    throw "Unsafe output directory: $output"
}
if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Recurse -Force }
New-Item -ItemType Directory -Force -Path $output | Out-Null
Copy-DirectoryContents $TemplateRoot $output

New-Item -ItemType Directory -Force -Path (Join-Path $output 'backend\app') | Out-Null
Copy-Item -LiteralPath $jar.FullName -Destination (Join-Path $output 'backend\app\cost-server.jar') -Force
Copy-DirectoryContents $frontendDist (Join-Path $output 'frontend\dist')
$frontendZip = Join-Path $output 'frontend\costree-frontend-dist-prod.zip'
Compress-Archive -Path (Join-Path $output 'frontend\dist\*') -DestinationPath $frontendZip -Force

$pgRoot = Join-Path $output 'database\postgresql'
New-Item -ItemType Directory -Force -Path (Join-Path $pgRoot '01-new-database') | Out-Null
Copy-Item -LiteralPath (Join-Path $BackendRoot 'sql\postgresql\costree-cost.sql') `
    -Destination (Join-Path $pgRoot '01-new-database\costree-cost.sql') -Force
Copy-DirectoryContents (Join-Path $BackendRoot 'sql\postgresql\costree-deploy') (Join-Path $pgRoot '02-upgrade-existing')
Copy-DirectoryContents (Join-Path $BackendRoot 'sql\postgresql\costree-integration') (Join-Path $pgRoot '03-data-integration')

$pg92Root = Join-Path $output 'database\postgresql92'
New-Item -ItemType Directory -Force -Path (Join-Path $pg92Root '01-new-database') | Out-Null
Copy-Item -LiteralPath (Join-Path $BackendRoot 'sql\postgresql92\costree-cost.sql') `
    -Destination (Join-Path $pg92Root '01-new-database\costree-cost.sql') -Force
Copy-Item -LiteralPath (Join-Path $BackendRoot 'sql\postgresql92\README.md') `
    -Destination (Join-Path $pg92Root 'README.md') -Force
Copy-DirectoryContents (Join-Path $BackendRoot 'sql\postgresql92\costree-deploy') (Join-Path $pg92Root '02-upgrade-existing')
Copy-DirectoryContents (Join-Path $BackendRoot 'sql\postgresql92\costree-integration') (Join-Path $pg92Root '03-data-integration')
$pg92ResetSource = Join-Path $BackendRoot 'sql\postgresql92\costree-reset'
if (Test-Path -LiteralPath $pg92ResetSource) {
    Copy-DirectoryContents $pg92ResetSource (Join-Path $pg92Root '04-reset-and-reload')
}

$platformRoot = Join-Path $output 'database\platform'
New-Item -ItemType Directory -Force -Path $platformRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $BackendRoot 'sql\mysql\costree-access-role-menu-20260817.sql') `
    -Destination (Join-Path $platformRoot 'costree-access-role-menu-mysql-20260817.sql') -Force
Copy-Item -LiteralPath (Join-Path $BackendRoot 'sql\postgresql\costree-access-role-menu-20260817.sql') `
    -Destination (Join-Path $platformRoot 'costree-access-role-menu-postgresql-20260817.sql') -Force
Copy-Item -LiteralPath (Join-Path $BackendRoot 'sql\postgresql92\costree-access-role-menu-20260817.sql') `
    -Destination (Join-Path $platformRoot 'costree-access-role-menu-postgresql92-20260817.sql') -Force
Copy-Item -LiteralPath (Join-Path $BackendRoot 'sql\dm\costree-access-role-menu-20260817.sql') `
    -Destination (Join-Path $platformRoot 'costree-access-role-menu-dm8-20260817.sql') -Force
Copy-Item -LiteralPath (Join-Path $BackendRoot 'sql\dm\check-cost-permissions-20260817.sql') `
    -Destination (Join-Path $platformRoot 'check-cost-permissions-dm8.sql') -Force

if ($IncludeSeed) {
    $seedTarget = Join-Path $pgRoot '90-optional-test-seed'
    New-Item -ItemType Directory -Force -Path $seedTarget | Out-Null
    Copy-Item -LiteralPath (Join-Path $BackendRoot 'sql\postgresql\costree-cost-seed.sql') -Destination $seedTarget -Force
}
if ($IncludeDemo) {
    $demoTarget = Join-Path $pgRoot '91-optional-demo'
    New-Item -ItemType Directory -Force -Path $demoTarget | Out-Null
    $demoSource = Join-Path $BackendRoot 'sql\postgresql\costree-demo-source'
    if (Test-Path -LiteralPath $demoSource) { Copy-DirectoryContents $demoSource (Join-Path $demoTarget 'source-chain') }
    foreach ($name in @('costree-unit-hierarchy-demo.sql', 'costree-two-model-pilot-import.sql')) {
        $source = Join-Path $BackendRoot ('sql\postgresql\' + $name)
        if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination $demoTarget -Force }
    }

    $pg92DemoSource = Join-Path $BackendRoot 'sql\postgresql92\costree-demo-source'
    if (Test-Path -LiteralPath $pg92DemoSource) {
        Copy-DirectoryContents $pg92DemoSource (Join-Path $pg92Root '91-optional-demo\source-chain')
    }
}

$appendix = Join-Path $output 'docs\appendix-data-design'
New-Item -ItemType Directory -Force -Path $appendix | Out-Null
foreach ($name in @(
    '05-内网源表与成本库业务表关系实施方案.md',
    '06-内网原表-主业项目树-ads_lc_lshsxm2022.md',
    '07-内网原表-工作令关联主业项目字典-dwd_bd_bfcustomitem_gzl.md',
    '08-内网原表-项目工作令账面成本明细-dws_bu_pz_pzmx_gzl.md',
    '09-成本库内网数据对接总设计方案.md',
    '10-成本库数据源与测试导入闭环.md',
    '11-外部源全量快照中间表幂等同步.md'
)) {
    $source = Join-Path $Root ('note\30-data\' + $name)
    if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination $appendix -Force }
}

Copy-Item -LiteralPath (Join-Path $Root 'note\80-deployment\03-成本树三级权限与双库初始化.md') `
    -Destination (Join-Path $output 'docs\12-成本树三级权限与双库初始化.md') -Force

$releaseType = if ($dirtyRepositories.Count -gt 0) { 'candidate' } else { 'formal' }
$releaseLines = @(
    'package=cost-server-offline-package',
    "releaseType=$releaseType",
    "buildTime=$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))",
    "schemaVersion=$SchemaVersion",
    "rootCommit=$($rootState.Commit)",
    "rootBranch=$($rootState.Branch)",
    "backendCommit=$($backendState.Commit)",
    "backendBranch=$($backendState.Branch)",
    "frontendCommit=$($frontendState.Commit)",
    "frontendBranch=$($frontendState.Branch)",
    "backendJar=$($jar.Name)",
    "dirtyRepositories=$($dirtyRepositories -join ',')",
    'databaseDialects=PostgreSQL 14+; PostgreSQL 9.2; GaussDB(DWS) 8.2.1 compatibility profile',
    'platformDatabaseDialects=Dameng DM8 (MQB); PostgreSQL 14+; PostgreSQL 9.2; MySQL 8',
    'postgresql92Validation=prior baseline passed PostgreSQL 9.2.23 Docker; 20260819 manual-field/subsystem upgrade requires target-database acceptance',
    'gaussdbDwsValidation=DWS 8.2.1 distribution-key compatibility implemented; onsite precheck and acceptance required',
    'amountUnit=business amounts in 10000 yuan; ledger amount in yuan and amount_wan in 10000 yuan'
)
[IO.File]::WriteAllLines((Join-Path $output 'RELEASE-INFO.txt'), $releaseLines, [Text.UTF8Encoding]::new($false))

if ($dirtyRepositories.Count -gt 0) {
    $stateDirectory = Join-Path $output 'source-state'
    New-Item -ItemType Directory -Force -Path $stateDirectory | Out-Null
    foreach ($entry in @(
        @{ Name = 'docs-root'; Path = $Root; State = $rootState },
        @{ Name = 'backend'; Path = $BackendRoot; State = $backendState },
        @{ Name = 'frontend'; Path = $FrontendRoot; State = $frontendState }
    )) {
        if (-not $entry.State.Dirty) { continue }
        @(& git -C $entry.Path status --short) | Set-Content -LiteralPath (Join-Path $stateDirectory ($entry.Name + '-status.txt')) -Encoding utf8
        $patchFile = Join-Path $stateDirectory ($entry.Name + '-working-tree.patch')
        if ($entry.Name -eq 'backend') {
            @(& git -C $entry.Path diff --binary HEAD -- . `
                ':(exclude)yudao-module-cost/yudao-module-cost-biz/src/main/resources/application-jt.yml' `
                ':(exclude)yudao-module-cost/yudao-module-cost-biz/src/main/resources/application-local.yml') |
                Set-Content -LiteralPath $patchFile -Encoding utf8
        } else {
            @(& git -C $entry.Path diff --binary HEAD) | Set-Content -LiteralPath $patchFile -Encoding utf8
        }
    }
    @(
        'This directory records uncommitted source state for candidate-package traceability.',
        'Credential-bearing application-jt.yml and application-local.yml diffs are intentionally omitted.',
        'Runtime configuration is provided by backend/config/application-intranet.yml and cost-server.env.'
    ) | Set-Content -LiteralPath (Join-Path $stateDirectory 'README.txt') -Encoding utf8
}

$manifestPath = Join-Path $output 'SHA256SUMS.txt'
$manifestLines = Get-ChildItem -LiteralPath $output -Recurse -File |
    Where-Object { $_.FullName -ne $manifestPath } |
    Sort-Object FullName |
    ForEach-Object {
        $relative = $_.FullName.Substring($output.Length + 1).Replace('\', '/')
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        "$hash *$relative"
    }
[IO.File]::WriteAllLines($manifestPath, $manifestLines, [Text.UTF8Encoding]::new($false))

& (Join-Path $output 'tools\verify-package.ps1') -PackageRoot $output

$zipPath = $output.TrimEnd('\') + '.zip'
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
Compress-Archive -Path $output -DestinationPath $zipPath -Force
Write-Host "Offline package created: $output"
Write-Host "Offline package zip: $zipPath"
Write-Host "Release type: $releaseType"
