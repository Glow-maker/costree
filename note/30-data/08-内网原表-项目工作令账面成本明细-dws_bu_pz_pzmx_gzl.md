# 08-内网原表-项目工作令账面成本明细 dws_bu_pz_pzmx_gzl

状态：原表字段整理草案
更新时间：2026-06-21
来源：用户提供的内网截图，字段以数据库 `COMMENT ON COLUMN` 为准，后续需用正式 DDL 和样例数据复核。

交接总览：先读 `09-成本库内网数据对接总设计方案.md`，再按本文核对账面明细字段、金额口径和关联细节。

## 1. 表定位

原表：

```text
schema: sc_8001_fidw
table : dws_bu_pz_pzmx_gzl
comment: 工作令凭证明细
```

业务口径：

- 该表是内网“项目工作令账面成本明细数据”的原始来源。
- 行粒度是凭证/科目/项目/工作令明细，不是项目汇总，也不是单位成本结构汇总。
- 截图中可见字段均按 `varchar(255)` 保存，金额、日期、期间、时间戳都需要在导入或解析时转换。
- 成本库当前已有 `cost_work_order_ledger_detail` 用于承接账面明细并支撑账面成本聚合、工作令组成 Top8、预警执行率。

## 2. 字段清单

以下字段来自截图中可读的字段注释。

| 原字段 | 注释 | 类型 | 初步理解 | 备注 |
|---|---|---|---|---|
| `id` | 主键 | `varchar(255)` | 原表技术主键 | 需确认是否稳定唯一；若稳定可作为导入幂等键候选 |
| `ysnm` | 内码 | `varchar(255)` | 源明细内码 | 当前成本库建议优先映射为 `source_detail_id` |
| `kjnd` | 会计年度 | `varchar(255)` | 会计年度 | 推荐映射到 `fiscal_year` |
| `kjqj` | 会计期间 | `varchar(255)` | 会计期间/月 | 推荐映射到 `accounting_period` |
| `pzrq` | 凭证日期 | `varchar(255)` | 凭证日期 | 样例为 `20251231`、`20250702`，需按 `yyyyMMdd` 解析 |
| `pzbh` | 凭证编号 | `varchar(255)` | 凭证编号 | 推荐映射到 `voucher_no` |
| `dwid` | 单位主键 | `varchar(255)` | 核算单位源 ID | 推荐映射到 `accounting_unit_id` |
| `dwbh` | 单位编号 | `varchar(255)` | 核算单位编号 | 推荐映射到 `accounting_unit_code` |
| `dwmc` | 单位名称 | `varchar(255)` | 核算单位名称 | 推荐映射到 `accounting_unit_name` |
| `gldw` | 管理单位 | `varchar(255)` | 管理单位名称 | 推荐映射到 `manage_unit_name` |
| `gldwpxh` | 管理单位排序号 | `varchar(255)` | 管理单位排序 | 当前标准明细表未单独保存，建议源镜像保留 |
| `kmid` | 科目主键 | `varchar(255)` | 会计科目源 ID | 推荐映射到 `subject_id` |
| `kmbh` | 科目编号 | `varchar(255)` | 一级/主科目编号 | 推荐映射到 `subject_code` |
| `kmmc` | 科目名称 | `varchar(255)` | 一级/主科目名称 | 推荐映射到 `subject_name` |
| `bmid` | 部门主键 | `varchar(255)` | 部门源 ID | 当前标准明细表未单独保存，建议源镜像保留 |
| `bmbh` | 部门编号 | `varchar(255)` | 部门编号 | 当前标准明细表未单独保存，建议源镜像保留 |
| `bmmc` | 部门名称 | `varchar(255)` | 部门名称 | 当前标准明细表未单独保存，建议源镜像保留 |
| `xmbh` | 项目编号 | `varchar(255)` | 主业项目编号 | 推荐映射到 `project_code` |
| `xmnm` | 项目主键 | `varchar(255)` | 主业项目源 ID | 推荐映射到 `source_project_id` |
| `xmmc` | 项目名称 | `varchar(255)` | 主业项目名称 | 推荐映射到 `project_name` |
| `gzlnm` | 工作令主键 | `varchar(255)` | 工作令源 ID | 推荐映射到 `source_work_order_id` |
| `gzllb` | 工作令编号 | `varchar(255)` | 工作令编号 | 推荐映射到 `work_order_no` |
| `gzlmc` | 工作令名称 | `varchar(255)` | 工作令名称 | 推荐映射到 `work_order_name` |
| `wldwid` | 往来单位主键 | `varchar(255)` | 往来单位源 ID | 当前标准明细表未单独保存，建议源镜像保留 |
| `wldwbh` | 往来单位编号 | `varchar(255)` | 往来单位编号 | 当前标准明细表未单独保存，建议源镜像保留 |
| `wldwmc` | 往来单位名称 | `varchar(255)` | 往来单位名称 | 当前标准明细表未单独保存，建议源镜像保留 |
| `jzfx` | 记账方向 | `varchar(255)` | 借/贷方向 | 推荐映射到 `debit_credit`；正负规则需财务确认 |
| `je` | 金额 | `varchar(255)` | 源金额 | 推荐解析为 `amount`；单位和换算万元规则需确认 |
| `yt` | 辅助摘要 | `varchar(255)` | 凭证摘要/辅助摘要 | 推荐映射到 `summary_text` |
| `lastmodifiedtime` | 最后修改时间 | `varchar(255)` | 源最后修改时间 | 推荐映射到 `source_lastmodify` |
| `bizcode` | 业务号 | `varchar(255)` | 业务编号 | 当前标准明细表未单独保存，建议源镜像保留 |
| `bizdate` | 业务日期 | `varchar(255)` | 业务日期 | 当前标准明细表未单独保存，建议源镜像保留 |
| `settlementdate` | 结算日期 | `varchar(255)` | 结算日期 | 当前标准明细表未单独保存，建议源镜像保留 |
| `settlementnumber` | 结算号 | `varchar(255)` | 结算编号 | 当前标准明细表未单独保存，建议源镜像保留 |
| `dwts` | 时间戳 | `varchar(255)` | 源时间戳 | 推荐映射到 `source_timestamp` |
| `ejkmbh` | 二级科目编号 | `varchar(255)` | 二级科目编号 | 推荐映射到 `second_subject_code` |
| `ejkmmc` | 二级科目名称 | `varchar(255)` | 二级科目名称 | 推荐映射到 `second_subject_name` |

## 3. 当前能直接确认的关系

从字段名、注释和样例看，这张表至少包含四组关键关系：

| 关系 | 可用字段 | 说明 |
|---|---|---|
| 凭证明细身份 | `id`、`ysnm`、`pzbh`、`pzrq` | `ysnm` 更适合作成本库明细幂等键，`id` 是否可用需确认 |
| 项目归属 | `xmnm`、`xmbh`、`xmmc` | 应与主业项目树 `ads_lc_lshsxm2022` 交叉验证 |
| 工作令归属 | `gzlnm`、`gzllb`、`gzlmc` | 应与工作令映射表 `dwd_bd_bfcustomitem_gzl` 交叉验证 |
| 账面组成 | `kmbh`、`kmmc`、`ejkmbh`、`ejkmmc`、`je`、`jzfx` | 支撑工作令账面组成 Top8 和科目明细列表 |

当前不能直接确认：

- `ysnm` 与 `id` 哪个才是稳定明细唯一键。
- `gzlnm` 是否等于 `dwd_bd_bfcustomitem_gzl.id`。
- `gzllb` 是否等于 `dwd_bd_bfcustomitem_gzl.cusitemcode`，以及是否跨年度/单位重复。
- `xmnm` 是否等于 `ads_lc_lshsxm2022.lshsxm_xmnm` 或 `lshsxm_id`。
- `je` 的单位是元、万元还是其他口径。
- `jzfx=借/贷` 在成本聚合中是否需要转正负。
- `lastmodifiedtime` 和 `dwts` 哪个是可靠增量同步字段。
- 部门、往来单位、业务号、结算信息是否需要在成本库标准明细表中长期保留。

## 4. 与成本库明细表的初步映射

当前成本库已有 `cost_work_order_ledger_detail` 作为“工作令账面成本明细”的标准表。该表已经覆盖凭证、单位、科目、项目、工作令、金额和二级科目等核心字段。

| `dws_bu_pz_pzmx_gzl` | `cost_work_order_ledger_detail` | 规则 |
|---|---|---|
| `ysnm` | `source_detail_id` | 推荐优先；用于导入幂等 |
| `kjnd` | `fiscal_year` | 原样保存，必要时校验 4 位年度 |
| `kjqj` | `accounting_period` | 原样保存，样例为 `12`、`07` |
| `pzrq` | `voucher_date` | 从 `yyyyMMdd` 转 `DATE` |
| `pzbh` | `voucher_no` | 原样保存 |
| `dwid` | `accounting_unit_id` | 原样保存 |
| `dwbh` | `accounting_unit_code` | 原样保存，并用于匹配单位字典 |
| `dwmc` | `accounting_unit_name` | 原样保存 |
| `gldw` | `manage_unit_name` | 原样保存 |
| `kmid` | `subject_id` | 原样保存 |
| `kmbh` | `subject_code` | 原样保存 |
| `kmmc` | `subject_name` | 原样保存 |
| `xmbh` | `project_code` | 原样保存；可作为项目兜底匹配键 |
| `xmnm` | `source_project_id` | 推荐优先匹配项目树源 ID |
| `xmmc` | `project_name` | 原样保存；只作展示和校验，不建议作为唯一匹配键 |
| `gzlnm` | `source_work_order_id` | 推荐优先匹配工作令源 ID |
| `gzllb` | `work_order_no` | 原样保存；兜底匹配工作令 |
| `gzlmc` | `work_order_name` | 原样保存 |
| `jzfx` | `debit_credit` | 原样保存，正负规则后置确认 |
| `je` | `amount` | 字符转 `DECIMAL`，清理逗号、空格等格式 |
| `je` 派生 | `amount_wan` | 单位确认后写入；若 `je` 是元则 `/10000`，若已是万元则原值 |
| `yt` | `summary_text` | 原样保存 |
| `lastmodifiedtime` | `source_lastmodify` | 字符转 `DATETIME`；格式需样例确认 |
| `ejkmbh` | `second_subject_code` | 原样保存 |
| `ejkmmc` | `second_subject_name` | 原样保存 |
| `dwts` | `source_timestamp` | 原样保存 |
| 匹配 `cost_project` 后写入 | `project_id` | 解析任务写入，不从原表直接提供 |
| 匹配 `cost_work_order` 后写入 | `work_order_id` | 解析任务写入，不从原表直接提供 |
| 工作令阶段派生 | `resolved_stage_code` | 从匹配到的 `cost_work_order.max_stage_code` 或阶段规则派生 |

当前标准表未覆盖但原表有价值的字段：

| 原字段 | 建议处理 |
|---|---|
| `gldwpxh` | 源镜像保留；如需要管理单位排序，再扩展标准表或单位字典 |
| `bmid`、`bmbh`、`bmmc` | 源镜像保留；后续若要按部门分析，再扩展标准表 |
| `wldwid`、`wldwbh`、`wldwmc` | 源镜像保留；后续若要按往来单位分析，再扩展标准表 |
| `bizcode`、`bizdate` | 源镜像保留；用于凭证追溯 |
| `settlementdate`、`settlementnumber` | 源镜像保留；用于结算追溯 |

## 5. 推荐承接方式

### 5.1 首轮验证

首轮内网验证建议先建原表镜像，字段保持与原表一致，全部 `varchar(255)`：

```text
cost_source_dws_bu_pz_pzmx_gzl
```

用途：

- 原样保存内网凭证明细，便于和 DBA/财务方核对。
- 不丢失部门、往来单位、业务号、结算号等当前标准明细表没有的字段。
- 后续用 SQL 或解析任务写入标准化的 `cost_work_order_ledger_detail`。

如果内网允许成本库直接读 `sc_8001_fidw.dws_bu_pz_pzmx_gzl`，也可以用视图过渡。但正式建议成本库保留自己的明细标准表，页面和接口只读 `cost_work_order_ledger_detail`。

### 5.2 正式维护

正式建议使用“两段式”：

```text
dws_bu_pz_pzmx_gzl 原表/镜像
  -> cost_work_order_ledger_detail 标准账面明细表
  -> 账面汇总、预警、Top8 科目组成接口
```

这样做的原因：

- 原表所有字段都是字符串，不能直接承担页面聚合和金额计算。
- 标准明细表可以补 `project_id`、`work_order_id`、`resolved_stage_code`，提高查询和聚合性能。
- 原表镜像保留追溯信息，标准明细表服务成本库业务查询。

## 6. 解析到账面明细标准表的初步规则

输入：`cost_source_dws_bu_pz_pzmx_gzl` 或内网原表视图
输出：`cost_work_order_ledger_detail`

推荐规则：

1. 按 `ysnm` 写入 `source_detail_id`；如果 `ysnm` 为空，再评估是否用 `id` 作为兜底唯一键【需确认】。
2. 解析 `kjnd`、`kjqj`、`pzrq`、`pzbh`，保留凭证维度。
3. 解析 `je` 为 `amount`，同时按财务确认口径写入 `amount_wan`。
4. 原样保存 `jzfx`，在借贷正负规则确认前，不在导入阶段擅自转负数。
5. 用 `gzlnm` 优先匹配 `cost_work_order.source_work_order_id`。
6. 匹配不到时，用 `gzllb + kjnd + dwbh` 兜底匹配 `cost_work_order.work_order_no + fiscal_year + accounting_unit_code`。
7. 匹配到工作令后回填 `work_order_id` 和该工作令的 `project_id`。
8. 如果工作令匹配不到，再用 `xmnm` 优先匹配 `cost_project.source_project_id`，用 `xmbh` 兜底匹配 `cost_project.project_code`。
9. `resolved_stage_code` 不从本表直接推导，优先取匹配工作令的 `max_stage_code`；如果为空，再按工作令 `stage_codes` 规则处理【需确认】。
10. 二级科目组成优先用 `ejkmbh/ejkmmc`；为空时用 `kmbh/kmmc`。
11. 解析失败的行不丢弃，应保留在标准明细表或异常表，并进入“未解析数据查询”。

## 7. 与前两张源表的关联验证

这张表必须和主业项目树、工作令关联主业项目字典一起验证。

| 账面明细字段 | 目标源表字段 | 验证目标 |
|---|---|---|
| `xmnm` | `ads_lc_lshsxm2022.lshsxm_xmnm` | 优先验证项目源 ID 是否可直接匹配 |
| `xmnm` | `ads_lc_lshsxm2022.lshsxm_id` | 如果不能匹配 `xmnm`，验证是否匹配原表主键 |
| `xmbh` | `ads_lc_lshsxm2022.lshsxm_xmbh` | 项目编号兜底匹配 |
| `gzlnm` | `dwd_bd_bfcustomitem_gzl.id` | 优先验证工作令源 ID 是否可直接匹配 |
| `gzllb` | `dwd_bd_bfcustomitem_gzl.cusitemcode` | 工作令编号兜底匹配 |
| `dwbh` | `dwd_bd_bfcustomitem_gzl.accountorgcode` | 核算单位维度校验 |
| `dwbh` | `cost_unit_dict.accounting_unit_code` | 院内/院外和单位名称校验 |

如果 `gzlnm` 无法匹配工作令字典，需要重新确认“工作令主键”是不是同一套内码；否则账面明细只能按编号兜底，跨年/跨单位重复风险会明显增加。

## 8. 对页面和接口的影响

当前成本库页面和接口应该继续按标准明细表读取：

| 功能 | 依赖字段 | 说明 |
|---|---|---|
| 成本树账面成本 | `amount_wan`、`work_order_id`、`project_id`、`resolved_stage_code` | 按项目/单位/阶段/工作令聚合 |
| 预警执行率 | 工作令目标成本 + 明细聚合账面成本 | 账面成本优先来自明细，无明细时用工作令兜底字段 |
| 工作令组成穿透 | `second_subject_code/name`、`subject_code/name`、`amount_wan` | Top8 科目组成，优先二级科目 |
| 待分配池账面成本 | `work_order_no` 或 `work_order_id` | 当前页工作令聚合 |
| 总体展示 | 项目、领域、单位聚合 | 真实数据量上来后需关注索引和聚合性能 |

## 9. 性能和索引建议

如果内网账面明细达到百万级，不能在 Java 内存中全量加载后再聚合。当前标准明细表已经有项目、工作令、单位、科目、期间、最后修改时间索引。正式数据量上来后建议重点检查：

| 查询场景 | 建议索引方向 |
|---|---|
| 按工作令汇总账面成本 | `tenant_id + source_work_order_id`，或 `tenant_id + fiscal_year + accounting_unit_code + work_order_no` |
| 按项目/阶段/单位汇总 | `tenant_id + project_id + resolved_stage_code + accounting_unit_code` |
| 按科目 Top8 | `tenant_id + work_order_id + second_subject_code` |
| 增量同步 | `tenant_id + source_lastmodify` 或源镜像表上的 `lastmodifiedtime/dwts` |
| 会计期间查询 | `tenant_id + fiscal_year + accounting_period` |

是否需要按年度或期间分区，等拿到真实行数、查询频率和数据库版本后再决定。

## 10. 需要业务或 DBA 补充确认

| 问题 | 为什么重要 |
|---|---|
| `ysnm` 和 `id` 哪个是稳定唯一明细键 | 决定导入幂等和重复明细处理 |
| `gzlnm` 是否等于工作令字典 `id` | 决定能否稳定匹配工作令 |
| `gzllb` 是否等于工作令字典 `cusitemcode`，是否跨年/跨单位重复 | 决定兜底匹配键 |
| `xmnm` 对应主业项目树哪个字段 | 决定项目归属 |
| `je` 的单位 | 决定 `amount_wan` 换算和页面金额展示 |
| `jzfx` 借/贷在成本聚合中如何转正负 | 决定账面成本、超支预警和组成金额 |
| `pzrq`、`lastmodifiedtime`、`dwts` 的实际格式 | 决定日期时间转换 |
| `lastmodifiedtime` 和 `dwts` 哪个可用于增量同步 | 决定同步范围和漏数风险 |
| 部门、往来单位、业务号、结算号是否需要进入成本库标准明细表 | 决定是否扩展 `cost_work_order_ledger_detail` |
| 历史凭证明细按发生时项目/工作令归属，还是按当前工作令映射重算 | 决定审计追溯口径 |

## 11. 下一步

1. 请 DBA 导出 `sc_8001_fidw.dws_bu_pz_pzmx_gzl` 的完整 DDL，不只截图。
2. 抽取 20 至 50 行真实样例，至少覆盖借方、贷方、冲销、不同会计期间、不同工作令、不同二级科目。
3. 与 `dwd_bd_bfcustomitem_gzl` 样例做关联校验，优先检查 `gzlnm -> id`，再检查 `gzllb -> cusitemcode`。
4. 与 `ads_lc_lshsxm2022` 样例做关联校验，优先检查 `xmnm -> lshsxm_xmnm`。
5. 由财务确认 `je` 单位和 `jzfx` 正负规则，再定 `amount_wan` 写入规则。
6. 根据是否需要保留部门、往来单位和结算字段，决定是只用 `cost_work_order_ledger_detail`，还是新增/保留 `cost_source_dws_bu_pz_pzmx_gzl` 源镜像表。
