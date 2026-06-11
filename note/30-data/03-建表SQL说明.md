# 建表 SQL 说明

状态：初稿

最后执行：2026-05-22，外网 MySQL `costree_mvp` 已重灌业务方建表参考调整后的 MVP 测试数据。

## SQL 文件

| 文件 | 说明 |
|---|---|
| `schema-mvp.sql` | 创建 `costree_mvp` schema 和 MVP 表结构 |
| `seed-mvp.sql` | 外网测试数据，会清空并重灌成本库 MVP 表 |

## 当前表清单

| 表 | 说明 |
|---|---|
| `cost_source_project_tree` | 源主业项目树，保留业务方 `xmnm`、父路径、级数、自定义字段和源最后修改时间 |
| `cost_model_node` | 领域/系列/型号树 |
| `cost_project` | 主业项目锚定信息 |
| `cost_unit_dict` | 单位字典，判断院内/院外 |
| `cost_project_basic` | 项目基本情况，项目办维护 |
| `cost_work_order` | 工作令基础信息，研制单位维护 |
| `cost_work_order_project_ref` | 工作令关联主业项目字典，保留源工作令与主业项目映射 |
| `cost_work_order_ledger_detail` | 工作令账面成本凭证明细，保留业务方维勤账面成本源字段 |
| `cost_unit_cost_detail` | 研制单位/院外单位成本结构明细 |
| `cost_import_batch` | 导入批次 |
| `cost_import_error` | 导入错误明细 |
| `cost_warning_record` | 预警记录 |

## 外网执行结果

| 表 | 记录数 |
|---|---:|
| `cost_source_project_tree` | 8 |
| `cost_model_node` | 20 |
| `cost_project` | 8 |
| `cost_unit_dict` | 21 |
| `cost_project_basic` | 10 |
| `cost_work_order` | 22 |
| `cost_work_order_project_ref` | 10 |
| `cost_work_order_ledger_detail` | 12 |
| `cost_unit_cost_detail` | 29 |
| `cost_import_batch` | 5 |
| `cost_import_error` | 1 |
| `cost_warning_record` | 6 |

补充验证：

- `cost_source_project_tree` 已按业务方“主业项目树”字段补充源项目 ID、父路径、级数、自定义字段和最后修改时间样例。
- `cost_work_order_project_ref` 已按业务方“工作令关联主业项目字典”字段补充 10 条工作令映射样例。
- `cost_work_order_ledger_detail` 已按业务方“项目工作令账面成本明细数据”字段补充 12 条凭证明细样例，含贷方冲销负数样例。
- `cost_unit_dict` 按业务截图字段构造院内、院外单位样例。
- `ZY-2026-LA-001` 已扩充为多院内单位、多 M/C/Z 阶段、多工作令和院外单位样例。
- 本次通过 PyMySQL 执行 `schema-mvp.sql` 和 `seed-mvp.sql`，共执行 42 条 SQL 语句。
- `cost_warning_record` 中 `warning_level = 'OVER'` 的工作令超支样本为 4 条，另有项目级 `NORMAL` 样本 1 条。

## 维护规则

- 建表 SQL 只放结构，不放测试数据。
- 测试数据只放 `seed-mvp.sql`。
- 每次变更表结构，同步更新 `01-数据模型-MVP.md`。
- 每次变更枚举或测试数据，同步更新 `02-枚举与测试数据方案.md`。
- 外网测试库允许重复执行 `seed-mvp.sql` 重置测试数据；内网真实环境不得直接执行清空数据脚本。
