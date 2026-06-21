# 07-内网原表-工作令关联主业项目字典 dwd_bd_bfcustomitem_gzl

状态：原表字段整理草案
更新时间：2026-06-21
来源：用户提供的内网截图，字段以数据库 `COMMENT ON COLUMN` 为准，后续需用正式 DDL 和样例数据复核。

交接总览：先读 `09-成本库内网数据对接总设计方案.md`，再按本文核对工作令映射字段和关联细节。

## 1. 表定位

原表：

```text
schema: 【需确认】
table : dwd_bd_bfcustomitem_gzl
comment: 明细层工作令项目
```

业务口径：

- 该表是内网“工作令关联主业项目字典”的原始来源之一。
- 表中同时保存工作令自身信息、核算组织信息、分类树信息、停用/完工状态、密级和关联主业项目信息。
- 截图中可见字段均按 `varchar(255)` 保存，不能直接按数字、日期、布尔使用。
- 成本库不建议前端直接查这张原表，应先镜像或标准化到 `cost_work_order_project_ref`，再解析生成或更新 `cost_work_order` 的项目归属字段。

## 2. 字段清单

以下字段来自截图中可读的字段注释。

| 原字段 | 注释 | 类型 | 初步理解 | 备注 |
|---|---|---|---|---|
| `id` | 内码 | `varchar(255)` | 原工作令项目内码 | 推荐作为 `source_work_order_id` 的首选来源 |
| `accountorg` | 核算组织ID | `varchar(255)` | 核算组织源 ID | 可保留为源字段，和单位字典核对 |
| `cusitemcategory` | 项目类别ID | `varchar(255)` | 工作令项目类别 ID | 可能用于分类或筛选，需样例确认 |
| `cusitemcode` | 工作令编号 | `varchar(255)` | 工作令编号 | 推荐映射到 `work_order_no` |
| `cusitemname` | 工作令名称 | `varchar(255)` | 工作令名称 | 推荐映射到 `work_order_name` |
| `cusitemproperty` | 项目类型 | `varchar(255)` | 工作令项目类型 | 可保留或用于后续业务筛选 |
| `accountorgcode` | 核算组织编码 | `varchar(255)` | 核算单位/组织编码 | 推荐映射到 `accounting_unit_code` |
| `accountorgname` | 核算组织名称 | `varchar(255)` | 核算单位/组织名称 | 推荐映射到 `accounting_unit_name` |
| `ejname` | 二级分类名称 | `varchar(255)` | 二级分类 | 可保留，用于理解工作令分类树 |
| `yjname` | 一级分类名称 | `varchar(255)` | 一级分类 | 可保留，用于理解工作令分类树 |
| `ifstopname` | 是否停用 | `varchar(255)` | 停用状态展示文本 | 需确认取值，如 `是/否` |
| `iscompleted` | 完工否 | `varchar(255)` | 是否完工 | 可用于状态或过滤，需确认取值 |
| `isdisabled` | 停用标记 | `varchar(255)` | 停用标记 | 推荐优先用于生成 `disabled`，但需确认和 `ifstopname` 的关系 |
| `timestamp_createdby` | 创建人 | `varchar(255)` | 源创建人 | 可保留为源字段 |
| `timestamp_createdon` | 创建时间 | `varchar(255)` | 源创建时间 | 字符型，使用前需解析格式 |
| `timestamp_lastchangedby` | 最后修改人 | `varchar(255)` | 源最后修改人 | 可保留为源字段 |
| `timestamp_lastchangedon` | 最后修改时间 | `varchar(255)` | 源最后修改时间 | 候选 `source_lastmodify` |
| `treeinfo_isdetail` | 明细 | `varchar(255)` | 是否明细/叶子节点 | 可能用于只抽取工作令明细记录 |
| `treeinfo_layer` | 级数 | `varchar(255)` | 工作令分类树级数 | 字符型，需转换 |
| `treeinfo_path` | 分级码 | `varchar(255)` | 工作令分类路径 | 可用于识别分类层级 |
| `dwts` | 时间戳 | `varchar(255)` | 源时间戳 | 候选增量字段，需和最后修改时间比较 |
| `zyxmid` | 关联主业项目id | `varchar(255)` | 关联主业项目源 ID | 推荐映射到 `linked_source_project_id` |
| `zyxmcode` | 关联主业项目编码 | `varchar(255)` | 关联主业项目编号 | 推荐映射到 `linked_project_code` |
| `zyxmname` | 关联主业项目名称 | `varchar(255)` | 关联主业项目名称 | 推荐映射到 `linked_project_name` |
| `seccode` | 密级编码 | `varchar(255)` | 密级编码 | 可保留，后续决定是否参与权限/脱敏 |
| `secname` | 密级名称 | `varchar(255)` | 密级名称 | 可保留，后续决定是否展示 |
| `note` | 备注 | `varchar(255)` | 源备注 | 推荐映射到 `remark` 或保留原备注 |
| `timestamp_lastchangedon2` | 修改时间2 | `varchar(255)` | 第二个修改时间字段 | 需确认和 `timestamp_lastchangedon`、`dwts` 的区别 |

## 3. 当前能直接确认的关系

从字段名和注释看，这张表至少包含三组关键关系：

| 关系 | 可用字段 | 说明 |
|---|---|---|
| 工作令身份 | `id`、`cusitemcode`、`cusitemname` | `id` 更适合作源唯一键，`cusitemcode` 用于页面和财务明细匹配 |
| 核算组织 | `accountorg`、`accountorgcode`、`accountorgname` | 可对齐单位字典和账面明细中的核算单位 |
| 关联主业项目 | `zyxmid`、`zyxmcode`、`zyxmname` | 用于把工作令归属到主业项目 |

当前不能直接确认：

- `zyxmid` 是否等于主业项目树 `ads_lc_lshsxm2022.lshsxm_xmnm`、`lshsxm_id`，还是另一个源系统 ID。
- `cusitemcode` 在全库是否唯一，还是需要加 `accountorgcode`、年度共同唯一。
- 原表截图未看到“年度”字段；而成本库 `cost_work_order_project_ref` 当前有 `fiscal_year`，年度来源需要确认。
- `isdisabled`、`ifstopname`、`iscompleted` 的取值和优先级需要确认。
- `timestamp_lastchangedon`、`timestamp_lastchangedon2`、`dwts` 哪个适合增量同步需要确认。
- `treeinfo_isdetail` 是否可作为“只抽取工作令叶子/明细记录”的过滤条件。

## 4. 与成本库源表的初步映射

当前成本库已有 `cost_work_order_project_ref` 作为“工作令关联主业项目字典”的标准源表。若继续使用该表，可先按以下方式映射。

| `dwd_bd_bfcustomitem_gzl` | `cost_work_order_project_ref` | 规则 |
|---|---|---|
| `id` | `source_work_order_id` | 首选；用于导入幂等和后续匹配账面明细 |
| `accountorgcode` | `accounting_unit_code` | 核算组织编码 |
| `accountorgname` | `accounting_unit_name` | 核算组织名称 |
| 暂无可见字段 | `fiscal_year` | 原表截图未看到年度；需从其他表、批次或工作令规则获取 |
| `cusitemcode` | `work_order_no` | 工作令编号 |
| `cusitemname` | `work_order_name` | 工作令名称 |
| `isdisabled` / `ifstopname` | `disabled` | 推荐先用 `isdisabled`，再用 `ifstopname` 校验；取值待确认 |
| `zyxmcode` | `linked_project_code` | 关联主业项目编号 |
| `zyxmname` | `linked_project_name` | 关联主业项目名称 |
| `zyxmid` | `linked_source_project_id` | 需确认是否能匹配主业项目树源 ID |
| 匹配 `cost_project` 后写入 | `project_id` | 由解析任务根据 `zyxmid/zyxmcode` 匹配后写入 |
| `timestamp_lastchangedon` 或 `timestamp_lastchangedon2` 或 `dwts` | `source_lastmodify` | 三者优先级需确认 |
| `note` | `remark` | 源备注 |
| `accountorg` | `custom_01` | 核算组织源 ID |
| `cusitemcategory` | `custom_02` | 项目类别 ID |
| `cusitemproperty` | `custom_03` | 项目类型 |
| `yjname` | `custom_04` | 一级分类名称 |
| `ejname` | `custom_05` | 二级分类名称 |
| `iscompleted` | `custom_06` | 完工否 |
| `treeinfo_isdetail` | `custom_07` | 明细标识 |
| `treeinfo_layer` | `custom_08` | 级数 |
| `treeinfo_path` | `custom_09` | 分级码 |
| `seccode`、`secname` | `custom_10` 或扩展字段 | 两个字段同时塞入一个 custom 不利于维护，正式建议扩展源表字段 |

## 5. 推荐承接方式

### 5.1 首轮验证

首轮内网验证建议先建原表镜像，字段保持与原表一致，全部 `varchar(255)`：

```text
cost_source_dwd_bd_bfcustomitem_gzl
```

用途：

- 原样保存内网原表，便于和 DBA/业务方核对。
- 不丢失一级/二级分类、密级、完工状态、分级码等当前标准源表字段未完整覆盖的信息。
- 后续用 SQL 或解析任务写入标准化的 `cost_work_order_project_ref`。

### 5.2 正式维护

正式建议使用“两段式”：

```text
dwd_bd_bfcustomitem_gzl 原表/镜像
  -> cost_work_order_project_ref 标准工作令映射源表
  -> cost_work_order 成本库工作令业务表
```

这样做的原因：

- 原表字段名和类型完全按内网系统走，成本库不直接耦合。
- `cost_work_order_project_ref` 只承担“当前工作令归属哪个主业项目”的标准化映射。
- `cost_work_order` 继续作为页面、填报、预警和成本树使用的业务表。
- 映射同步时不应覆盖研制单位已经填报的目标成本、阶段、分系统、产品简称等业务字段，除非导入时明确选择覆盖。

## 6. 解析到成本库工作令的初步规则

输入：`cost_work_order_project_ref`

输出：`cost_work_order`

推荐规则：

1. 按 `source_work_order_id = id` 查找或创建工作令。
2. 用 `linked_source_project_id = zyxmid` 优先匹配 `cost_project`；匹配不到时用 `linked_project_code = zyxmcode` 兜底。
3. 回填 `project_id`、`project_code`、`project_name`、`accounting_unit_code`、`accounting_unit_name`、`work_order_no`、`work_order_name`、`disabled`。
4. 如果 `treeinfo_isdetail` 表示非明细节点，默认不生成 `cost_work_order`，只作为分类节点保留在原表镜像【需确认】。
5. 如果 `isdisabled` 或 `ifstopname` 表示停用，默认同步为 `disabled=true`；是否仍在页面显示需业务确认。
6. 如果原表没有年度字段，暂不把 `fiscal_year` 作为唯一键的一部分，直到确认年度来源；但要保留跨年重复风险。
7. 不从这张表推导目标成本、阶段、分系统、产品简称，这些仍由 `cost_work_order` 填报/导入维护。

## 7. 与主业项目树的关联验证

这张表必须和上一张主业项目树原表一起验证：

| 工作令映射字段 | 主业项目树候选字段 | 验证目标 |
|---|---|---|
| `zyxmid` | `ads_lc_lshsxm2022.lshsxm_xmnm` | 优先验证是否一一匹配 |
| `zyxmid` | `ads_lc_lshsxm2022.lshsxm_id` | 如果不能匹配 `xmnm`，验证是否匹配主键 |
| `zyxmcode` | `ads_lc_lshsxm2022.lshsxm_xmbh` | 编号兜底匹配 |
| `zyxmname` | `ads_lc_lshsxm2022.lshsxm_xmmc` | 名称仅作校验，不建议作为唯一匹配键 |

如果 `zyxmid` 和主业项目树任一 ID 都无法稳定匹配，应要求 DBA 提供正式关联口径或中间映射表。

## 8. 需要业务或 DBA 补充确认

| 问题 | 为什么重要 |
|---|---|
| 原表 schema 名称 | 内网同步和授权需要完整表名 |
| `id` 是否稳定唯一 | 决定导入幂等键 |
| `cusitemcode` 是否跨年度/跨单位重复 | 决定是否必须引入年度和核算组织作为复合唯一键 |
| 年度字段从哪里来 | 当前截图未看到年度，但成本库标准源表需要 `fiscal_year` |
| `zyxmid` 对应主业项目树哪个字段 | 决定工作令能否稳定挂到项目 |
| `isdisabled`、`ifstopname`、`iscompleted` 的取值范围 | 决定停用、完工和页面过滤规则 |
| `timestamp_lastchangedon`、`timestamp_lastchangedon2`、`dwts` 哪个是可靠增量字段 | 决定后续增量同步 |
| `treeinfo_isdetail` 的取值含义 | 决定是否只导入明细/叶子工作令 |
| 密级字段是否影响成本库权限或展示 | 决定是否要接中台密级/脱敏规则 |

## 9. 下一步

1. 请 DBA 导出 `dwd_bd_bfcustomitem_gzl` 的完整 DDL，不只截图。
2. 抽取 20 至 50 行真实样例，至少覆盖正常、停用、完工、非明细节点、有关联主业项目和无关联主业项目的记录。
3. 和 `ads_lc_lshsxm2022` 样例做关联校验，优先检查 `zyxmid -> lshsxm_xmnm`。
4. 确认年度来源，避免工作令编号跨年重复时混账。
5. 已新增第三张“项目工作令账面成本明细数据”原表整理，下一步用样例数据确认 `gzlnm -> id`、`gzllb -> cusitemcode`、`dwbh -> accountorgcode` 的关联关系。
