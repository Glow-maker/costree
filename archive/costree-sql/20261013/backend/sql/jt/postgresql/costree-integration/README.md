# PostgreSQL 历史同步脚本

历史同步方案，不用于当前现场日常同步。[统一入口](../../README.md)。

适用 PostgreSQL 14+。外部数据先装入 `cost_integration` 暂存表，再同步至 `cost_*` 业务表。禁止绕过校验直接批量写入业务表。

## 执行顺序

1. 首次执行 `00-create-staging.sql` 创建独立暂存 schema。
2. 将本批数据完整装载到七张暂存表。可由数据治理工作流直接写表，也可使用 `csv/` 模板和 `load-and-sync.ps1` / `load-and-sync.sh`。
3. 执行 `10-sync-to-cost.sql`。脚本在单事务中校验、转换、UPSERT 和重建借方账面快照；任何错误都会整批回滚。
4. 执行 `20-verify-sync.sql`，确认所有错误计数为 0。
5. 用同一批数据再执行一次第 3、4 步，确认记录数和金额不增加。

## 暂存表与来源

| 暂存表 | 外部来源 | 目标表 |
|---|---|---|
| `unit_dict` | 内网单位字典 | `cost_unit_dict` |
| `ads_lc_lshsxm2022` | 主业项目树治理结果 | `cost_model_node`、`cost_project` |
| `dwd_bd_bfcustomitem_gzl` | 工作令关联主业项目字典 | `cost_work_order` |
| `precontrol_project_unit_amount` | 预分预控项目单位合同、到款 | `cost_unit_cost_detail` |
| `project_office_fill` | 项目办项目级补充信息 | `cost_project_basic` |
| `work_order_fill` | 研制单位工作令补充信息 | `cost_work_order` |
| `dws_bu_pz_pzmx_gzl` | 工作令凭证账面明细 | `cost_work_order_ledger_detail` |

## 数据口径

- `ads_lc_lshsxm2022` 在进入暂存层前应规范化为 1=领域、2=系列、3=型号三级；原始源树可保留任意层级，但抽取工作流要完成映射。
- 预分预控金额粒度为“项目编码 + 实际核算单位”，金额单位为万元；正式同步只更新合同、到款。
- 单位目标成本、审定金额由项目办在 `/cost/collect` 按单位维护。暂存表中同名列仅为旧模板兼容列，正式同步忽略，不能作为权威来源。
- 逻辑工作令粒度为“项目编码 + 实际核算单位 + 工作令编号”，不能按年度复制工作令。
- 年度只存在账面明细 `kjnd` 中。
- 账面源金额 `je` 单位为元；标准表同时保存 `amount=元`、`amount_wan=元/10000`。
- 贷方明细保留用于审计，但账面、预警和八项组成只统计 `jzfx='借'`。
- `ysnm` 必须是全局稳定的源明细 ID；重复同步同一 `ysnm` 不得重复记账。
- 账面明细优先用 `gzlnm` 关联工作令源主键 `source_work_order_id`；`dwmc` 允许为空，只有 `gzlnm` 为空时才用单位编码或单位名称兜底。
- 每次装载应是本批项目的完整快照。源端删除的数据用 `source_deleted=1` 明确传入。

## 工作流接入

工作流 UPSERT 七张暂存表后，依次执行同步、核验。文件导入使用 UTF-8 CSV；装载脚本仅清空 `cost_integration` 暂存数据，不清理业务表。

`project_office_fill` 和 `work_order_fill` 可以为空：项目、工作令和账面仍可先同步，未维护的填报字段在页面显示为空。单位字典、项目树、工作令映射和账面关联键不能缺失。

账面明细无法关联工作令时整批回滚。院内账面均为 0 时，使用只读脚本 `30-diagnose-book-zero.sql` 检查借贷方向、明细关联和工作令快照。

## 对账

先验证两个型号，再扩大范围：

- 目录树和项目卡片能定位到两个型号；
- 项目单位合同、到款与预分预控一致；目标、审定由项目办逐单位填写并在后续同步后保持不变；
- 同一工作令跨年度只显示一条，账面等于各年度借方明细之和；
- 八项组成合计等于借方账面；
- 贷方不进入账面、组成和预警；
- 第二次同步记录数和金额不增加。
