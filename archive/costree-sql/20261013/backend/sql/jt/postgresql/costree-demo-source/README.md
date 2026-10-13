# 成本库数据同步演示

仅用于测试，不用于真实成本库或日常同步。[统一入口](../../README.md)。

模拟外部数据源并同步到成本业务表，适用 PostgreSQL 14+。

## 前置条件

1. 目标库已执行最新版 `../costree-cost.sql`。
2. 旧库已执行：
   - `../costree-cost-20260626-add-project-basic-extra-fields.sql`
   - `../costree-cost-20260713-unify-amount-source.sql`
   - `../costree-cost-20260721-add-manage-unit-group.sql`
   - `../costree-cost-20260722-logical-work-order.sql`
3. 默认测试库为 `costree_mvp`，默认租户为 `124`。
4. 如租户不同，执行 `00` 后修改：

```sql
UPDATE cost_demo_source.demo_config SET tenant_id = <实际租户ID> WHERE id = 1;
```

## 执行顺序

使用 SQL 客户端逐文件完整执行：

```text
00-create-source-schema.sql
01-seed-two-projects.sql
02-sync-to-cost.sql
03-verify.sql
```

重复执行 `02-sync-to-cost.sql` 和 `03-verify.sql`，记录数和金额应保持不变。

每个文件单独执行。报错后停止，执行 `ROLLBACK;`，修复首个错误后从该文件开头重跑；`current transaction is aborted` 也按此处理。

## 数据流

| 模拟源表 | 业务目标 |
|---|---|
| `unit_dict` | `cost_unit_dict` |
| `ads_lc_lshsxm2022` | `cost_model_node`、`cost_project` |
| `dwd_bd_bfcustomitem_gzl` + `work_order_fill` | `cost_work_order` |
| `precontrol_project_unit_amount` | `cost_unit_cost_detail` |
| `project_office_fill` | `cost_project_basic` |
| `dws_bu_pz_pzmx_gzl` | `cost_work_order_ledger_detail`、逻辑工作令跨年度账面快照 |

预分预控金额单位为万元。账面源字段 `je` 单位为元，同步后保存：

```text
amount = je
amount_wan = je / 10000
```

贷方明细会保留，但工作令账面、预警和八项成本组成只统计 `debit_credit='借'`。

## 演示项目

| 项目编码 | 演示内容 | 预期结果 |
|---|---|---|
| `ZY-2026-DEMO-UNIT-001` | 院部直属、总体所、管理单位分组、电子所多核算单位、预警、八项组成 | 14 个院内核算单位聚合成 12 张管理单位卡片，另有 1 张院外卡片；总体所包含八部、509所；院内目标和账面均为 12,470 万元 |
| `ZY-2026-DEMO-YEAR-002` | 同编号工作令跨年度合并、贷方排除 | 只生成 1 条逻辑工作令；2023-2026 借方明细分别为 200/250/200/350 万元，工作令账面合计 1,000 万元 |

两个项目共有 16 条项目单位金额、15 条逻辑工作令、24 条账面明细。借方账面合计 13,470 万元，另有 2 条贷方明细不参与汇总。

## 页面验收

- `/cost/index`：演示领域和八项账面组成。
- `/cost/catalog?domainCode=DEMO`：两个演示项目卡片。
- `/cost/tree-detail?projectCode=ZY-2026-DEMO-UNIT-001`：院部直属、五类单位分组、12 家院内管理单位、院外汇总、使用率和黄红预警。
- 从“电子所”进入单位穿透页：应看到 3 个实际核算单位的工作令。
- `/cost/project-detail?projectCode=ZY-2026-DEMO-YEAR-002`：工作令标签只显示一条逻辑工作令，账面为 1,000 万元。
- `/cost/ledger-composition-detail?projectCode=ZY-2026-DEMO-YEAR-002`：原始明细保留年度列，可核对四个年度。

## 清理

`99-cleanup.sql` 仅清理两个演示项目、对应导入批次和模拟源数据，保留 `cost_demo_source` schema 与 `demo_config`，不处理其他 seed 或真实数据。
