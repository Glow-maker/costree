# 数据模型 - MVP

状态：初稿

## 命名口径

- `Table 2`、`Table 3` 是原型追溯编号，数据库表不使用 `table2`、`table3` 命名。
- 项目办维护的数据对象命名为“项目基本情况”，表名草案 `cost_project_basic`。
- 研制单位维护的数据对象命名为“工作令基础信息”，表名草案 `cost_work_order`。

## 数据对象草案

| 对象 | 表名草案 | MVP |
|---|---|---|
| 源主业项目树 | `cost_source_project_tree` | 是 |
| 领域/系列/型号树 | `cost_model_node` | 是 |
| 成本项目主表/主业项目锚定 | `cost_project` | 是 |
| 单位字典 | `cost_unit_dict` | 是 |
| 项目基本情况 | `cost_project_basic` | 是 |
| 工作令基础信息 | `cost_work_order` | 是 |
| 工作令关联主业项目字典 | `cost_work_order_project_ref` | 是 |
| 工作令账面成本明细 | `cost_work_order_ledger_detail` | 是 |
| 研制单位成本结构明细 | `cost_unit_cost_detail` | 是 |
| 导入批次 | `cost_import_batch` | 是 |
| 导入错误 | `cost_import_error` | 是 |
| 预警记录 | `cost_warning_record` | 简版 |

## 关系草案

| 父对象 | 子对象 | 关系 | 说明 |
|---|---|---|---|
| `cost_source_project_tree` | `cost_project` | 1:1 或 1:N | 源主业项目树到成本库项目锚定，正式转换规则【需确认】 |
| `cost_project` | `cost_project_basic` | 1:N | 一个主业项目下可有多条项目基本情况记录 |
| `cost_project` | `cost_work_order` | 1:N | 一个主业项目下可有多条工作令基础信息记录 |
| `cost_work_order_project_ref` | `cost_work_order` | 1:1 或 1:N | 源工作令映射到成本库工作令，正式匹配键【需确认】 |
| `cost_work_order_project_ref` | `cost_work_order_ledger_detail` | 1:N | 账面成本明细通过工作令源 ID 或工作令编号归属项目 |
| `cost_work_order` | `cost_work_order_ledger_detail` | 1:N | 账面成本明细匹配后可写入 `work_order_id` |
| `cost_project` | `cost_unit_cost_detail` | 1:N | 一个主业项目下可有多条项目/阶段/研制单位成本结构明细 |
| `cost_unit_dict` | `cost_work_order` | 1:N | 通过单位名称/单位 ID 对齐，用于判断院内单位【需确认正式关联键】 |
| `cost_unit_dict` | `cost_unit_cost_detail` | 1:N | 通过单位名称/单位 ID 对齐，用于判断院外单位【需确认正式关联键】 |
| `cost_project_basic` | `cost_import_batch` | N:1 | 导入批次记录来源，具体关联方式【需确认】 |
| `cost_work_order` | `cost_import_batch` | N:1 | 导入批次记录来源，具体关联方式【需确认】 |
| `cost_project` | `cost_warning_record` | 1:N | 预警按项目或工作令生成【需确认】 |

## 关键字段草案

### `cost_source_project_tree`

业务方“主业项目树”源数据表，用于保留院 cloud / 治理数据原始字段，不直接替代成本库展示树。

| 字段 | 说明 |
|---|---|
| `source_project_id` | 源项目主键 ID，业务参考字段 `xmnm` |
| `project_code` / `project_name` | 主业项目编号/名称 |
| `project_category` | 主业项目所属类别 |
| `domain_code` / `domain_name` | 所属领域 |
| `parent_source_id` / `parent_path` | 上级节点 ID 和父路径 |
| `level_no` | 级数，业务参考字段 `JS` |
| `source_lastmodify` | 源系统最后修改时间，用于增量同步 |
| `custom_01` 至 `custom_10` | 业务方预留自定义字段 |

唯一约束：`tenant_id + source_project_id`。

### `cost_project`

| 字段 | 说明 |
|---|---|
| `id` | 主键 |
| `project_code` | 主业项目编号 |
| `project_name` | 主业项目名称 |
| `domain_code` / `domain_name` | 所属领域 |
| `category_code` / `category_name` | 所属类别/系列 |
| `unit_id` / `unit_name` | 单位 |
| `unit_type` | 单位属性 |
| `project_office_status` | 项目办填报状态 |
| `unit_fill_status` | 研制单位填报状态 |
| `audit_status` | 审批/提交状态 |
| `dept_id` | 数据权限预留字段【需确认】 |
| `owner_user_id` | 项目负责人或填报负责人【需确认】 |

### `cost_project_basic`

项目办维护，原型 `Table 2`。核心字段来自原型：分系统/产品配套、用户、项目获取方式、批次/类别、所属平台/系列、承研单位、投标/目标价格、竞争项目合同金额、型号项目目标成本、研制周期、阶段、审定金额、基本情况、备注。

### `cost_work_order`

研制单位维护，原型 `Table 3`。核心字段来自原型：工作令编号、工作令名称、研制产品目标成本、阶段、所属分系统、产品简称、配套数量、是否属于纵向分工、审定金额、备注。

待分配池口径：

| 字段 | 说明 |
|---|---|
| `product_short_name` | 产品简称允许为空；为 `NULL`、去空格后为空字符串或填写 `待分配` 时，该工作令进入“待分配池” |
| `book_cost_amount` | 工作令基础信息中的账面成本兜底字段；如存在 `cost_work_order_ledger_detail` 明细，页面和接口优先使用明细聚合金额 |
| `status` | 工作令业务状态；待分配池不改变该字段，只做展示和穿透 |

本轮不新增待分配状态字段，也不新增待分配汇总表。后续如果业务要求“认领、分配、关闭”流程，再单独设计状态流转表或操作日志【需确认】。

### `cost_work_order_project_ref`

业务方“工作令关联主业项目字典”源数据表，用于保存当前工作令与主业项目的映射关系。

| 字段 | 说明 |
|---|---|
| `source_work_order_id` | 源工作令 ID |
| `accounting_unit_code` / `accounting_unit_name` | 核算单位编号/名称 |
| `fiscal_year` | 年度 |
| `work_order_no` / `work_order_name` | 工作令编号/名称 |
| `disabled` | 是否停用 |
| `linked_project_code` / `linked_project_name` | 关联主业项目编号/名称 |
| `linked_source_project_id` | 关联主业项目源 ID |
| `project_id` | 匹配后的成本库项目主键 |
| `custom_01` 至 `custom_10` | 业务方预留自定义字段 |

唯一约束：`tenant_id + source_work_order_id`。如果源系统无法保证工作令 ID 稳定，需要改用 `tenant_id + fiscal_year + work_order_no + accounting_unit_code`【需确认】。

### `cost_work_order_ledger_detail`

业务方“项目工作令账面成本明细数据”源数据表，保存凭证级账面成本，不再把凭证明细塞入 `cost_unit_cost_detail`。

| 字段 | 说明 |
|---|---|
| `source_detail_id` | 源明细内码，业务参考字段 `ysnm` |
| `fiscal_year` / `accounting_period` | 会计年度/期间 |
| `voucher_date` / `voucher_no` | 凭证日期/编号 |
| `accounting_unit_id` / `accounting_unit_code` / `accounting_unit_name` | 单位主键/编号/名称 |
| `manage_unit_name` | 管理单位 |
| `subject_id` / `subject_code` / `subject_name` | 科目主键/编号/名称 |
| `project_code` / `source_project_id` / `project_name` | 项目编号/源主键/名称 |
| `source_work_order_id` / `work_order_no` / `work_order_name` | 工作令主键/编号/名称 |
| `debit_credit` | 记账方向 |
| `amount` | 源系统金额【需确认，当前暂按元】 |
| `amount_wan` | 折算万元，用于成本库展示聚合【需确认】 |
| `summary_text` | 辅助摘要 |
| `source_lastmodify` | 源系统最后修改时间 |
| `second_subject_code` / `second_subject_name` | 二级科目编号/名称 |
| `source_timestamp` | 源时间戳 |
| `resolved_stage_code` | 按工作令最高阶段解析后的成本库归集阶段 |
| `project_id` / `work_order_id` | 匹配后的成本库业务主键 |

唯一约束：`tenant_id + source_detail_id`。后续账面成本建议从本表按工作令/阶段实时聚合或定时汇总【需确认性能口径】。

### `cost_unit_dict`

单位字典用于成本树详情页判断院内/院外，并在院外单位详情页展示单位基础信息。当前外网测试数据按业务截图构造，正式来源仍需确认。

| 字段 | 说明 |
|---|---|
| `accounting_unit_id` | 核算单位 ID |
| `accounting_unit_code` | 核算单位编号 |
| `accounting_unit_name` | 核算单位名称 |
| `manage_unit_code` | 管理单位编号 |
| `manage_unit_name` | 管理单位名称 |
| `contact_unit_code` | 往来单位编号 |
| `contact_unit_name` | 往来单位名称 |
| `inside_group` | 是否集团内 |
| `inside_institute` | 是否八院内，成本树院内/院外分类依据 |
| `unit_id` | 中台单位 ID【需确认映射来源】 |

唯一约束：`tenant_id + accounting_unit_code`。当前查询接口为只读，后续如果需要前台维护或同步任务，需要补 CRUD / 导入能力【需确认】。

### `cost_unit_cost_detail`

总体展示页的真实数据来源表，不是每日汇总表。一行表示“某项目 / 阶段 / 研制单位”的成本结构明细，后端接口按 `domain_code` 或 `domain_code + unit_name` 实时聚合。

| 字段 | 说明 |
|---|---|
| `project_id` / `project_code` / `project_name` | 归属主业项目 |
| `domain_code` / `domain_name` | 所属领域，用于总体展示按领域聚合 |
| `model_node_id` / `model_code` / `model_name` | 所属型号节点 |
| `unit_id` / `unit_name` | 研制单位 |
| `stage_code` | 阶段 |
| `contract_amount` | 合同金额，单位万元 |
| `income_amount` | 到款/收入金额，单位万元 |
| `target_cost_amount` | 目标成本，单位万元 |
| `book_cost_amount` | 账面成本，单位万元 |
| `salary_amount` | 薪酬，单位万元 |
| `material_amount` | 材料费，单位万元 |
| `outsource_amount` | 外协费，单位万元 |
| `manage_amount` | 管理费，单位万元 |
| `fuel_power_amount` | 燃料动力，单位万元 |
| `other_amount` | 其他，单位万元 |

唯一约束：`tenant_id + project_code + stage_code + unit_name`。后续如果同一项目、阶段、单位需要多版本或多批次明细，需要新增版本字段【需确认】。

## 设计原则

- 外网测试先自建 MySQL 表和数据。
- 业务方参考表按“源数据表”保存，成本库页面表按“业务展示/填报表”保存，两者不混用。
- 能复用中台用户、部门、角色、消息、预警配置的，不重复建表。
- 金额字段使用 decimal 类型。
- 状态字段先使用字符串或明确枚举值，后续再对齐字典。
- MVP 暂不做字段级权限表，通过页面、菜单、按钮、接口和数据权限拆分控制项目办/研制单位边界。
