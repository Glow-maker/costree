# PostgreSQL 内网升级与版本一致性

> 当前成本库数据库结构版本：`20260722`。本文件是 PostgreSQL 内网迁移的当前入口。

## 1. 上线时必须同时对齐三项

| 交付物 | 必须记录 | 原因 |
|---|---|---|
| 后端 JAR | 后端 Git 提交号 | 后端会直接查询新增字段，数据库未升级会报缺列 |
| 前端资源 | 前端 Git 提交号 | 页面字段和接口参数必须与后端一致 |
| PostgreSQL 脚本 | `schemaVersion=20260722` | 确认字段、唯一键和金额口径已经迁移 |

不能只替换 JAR。近期出现的 `product_attachment_type does not exist`、`income_amount does not exist`，都属于“代码已更新、数据库未升级”。

## 2. 正式脚本位置

以后只从后端仓库以下位置生成数据库交付包：

```text
sql/postgresql/costree-cost.sql
sql/postgresql/costree-amount-sync-template.sql
sql/postgresql/costree-deploy/
```

其中：

- `costree-cost.sql`：新建空库使用。
- `costree-deploy/00-precheck.sql`：旧库升级前检查，不改数据。
- `costree-deploy/10-upgrade-existing-to-20260722.sql`：旧库一次升级到当前版本。
- `costree-deploy/20-verify.sql`：升级后自动对账，发现问题会报错。
- `costree-deploy/build-package.ps1`：生成正式交付目录、zip 和 SHA-256 清单。

历史 `20260626`、`20260713`、`20260721`、`20260722` 增量脚本仍保留追溯，但内网旧库不再逐个挑选执行。

## 3. 空库和旧库的执行路径

### 新建空库

1. 执行 `costree-cost.sql`。
2. 执行 `20-verify.sql`。
3. 真实数据环境不执行 seed 和 demo 脚本。

### 已运行过成本库的旧库

1. 停止成本后端和所有同步工作流。
2. 备份成本库表。
3. 执行 `00-precheck.sql`，处理检查出的业务键或固定金额冲突。
4. 执行 `10-upgrade-existing-to-20260722.sql`。
5. 执行 `20-verify.sql`，所有 `error_count` 必须为 `0`。
6. 再替换同一发布批次的后端 JAR 和前端资源。

统一升级脚本使用单事务。任一步失败会回滚，不会保留半套结构或半批合并数据。

## 4. 本版本会补齐什么

| 表 | 关键变更 |
|---|---|
| `cost_project_basic` | 产品/附件/发射车类型、是否免税、周期年月字段 |
| `cost_unit_cost_detail` | 审定金额、源记录 ID、源更新时间；唯一粒度统一为项目+单位 |
| `cost_unit_dict` | 管理单位分类 `manage_unit_group` |
| `cost_work_order` | 源工作令、核算单位、合同、到款、审定等字段；跨年度行合并为逻辑工作令 |
| `cost_work_order_ledger_detail` | 稳定源明细 ID 唯一约束；元/万元校正 |
| `cost_schema_migration` | 记录数据库结构版本 |

账面快照会从全部年度明细重建，只统计借方：

```text
amount     = 原始金额（元）
amount_wan = amount / 10000（万元）
账面成本   = debit_credit = '借' 的明细合计
```

贷方明细保留用于核对，但不进入账面、预警和八项组成。

## 5. 数据导入和结构升级要分开

数据库结构升级只保证表、字段、索引和历史数据转换正确，不替代业务数据同步。

业务数据按以下稳定键 UPSERT，不能无条件 INSERT：

| 数据 | 稳定键 |
|---|---|
| 项目单位金额 | 租户 + 项目编码 + 单位名称 |
| 逻辑工作令 | 租户 + 项目编码 + 实际单位 + 工作令编号 |
| 账面明细 | 租户 + `source_detail_id` |

预分预控金额使用 `cost_unit_cost_detail`；账面明细使用 `cost_work_order_ledger_detail`。工作流重复执行时，记录数和金额不得增加。

## 6. 交付包生成

后端仓库执行：

```powershell
.\sql\postgresql\costree-deploy\build-package.ps1 `
  -OutputDirectory 'H:\delivery\costree-postgresql-20260722'
```

正式包要求 Git 工作区干净。包内 `RELEASE-INFO.txt` 记录后端提交号，`SHA256SUMS.txt` 用于检查文件是否遗漏或损坏。内网解压后先运行：

```powershell
.\upgrade-existing\verify-package.ps1
```

seed 和演示数据默认不打入正式包，防止误写真实库。

## 7. 上线验收

- 数据库存在结构版本 `20260722`。
- `20-verify.sql` 没有失败项。
- 后端启动无缺表、缺列和唯一键异常。
- `/cost/index`、`/cost/catalog`、`/cost/tree-detail`、`/cost/tree-unit-detail`、`/cost/project-detail`、`/cost/collect` 可正常访问。
- 抽查一个项目：单位合同/到款/目标/审定与预分预控一致。
- 抽查一个跨年工作令：页面只有一条逻辑工作令，账面等于各年度借方明细之和。
- 八项组成合计等于借方账面，贷方不计入。

## 8. 回滚边界

- 升级脚本执行中失败：事务会自动回滚，修复预检查问题后重新执行。
- 升级提交后发现业务数据不符合预期：停止应用，保留现场并使用升级前备份恢复；不要手工反向删除字段。
- 后端报缺列：先检查 `cost_schema_migration`，不要反复重启或临时改 Java 映射。
