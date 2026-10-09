# 2026-10-09 全量快照差异同步与人工填报保护审计

本文记录的是修订前脚本的审计发现，不是本次最终工作流的未修复问题清单。修订后的模块位于离线包 `05-workflow`；最终执行验证与尚待现场确认的边界，以本次发布报告和 `workflow-isolated/verification-summary.json` 为准。

范围：按当前成本树源码、`snapshot-upsert`、旧 `costree-integration/manual` 和 `10-sync-to-cost.sql` 核对。只读审计；未连接真实数据库、未修改应用代码或同步脚本、未启动任何服务。本报告不证明云鲸现场任务已替换或真实 DWS 已验收。

路径记号：`<backend-root>` 为后端仓库；`<costree-root>` 为本文档仓库。下列行号依据 2026-10-09 当前文件，后续补丁可能改变行号。

## 结论

已有应用支持“全量装入独立中间表，再按业务键差异更新成本表”，不需要另建一套人工填写表。人工基本情况已经在 `cost_project_basic`；单位目标/审定与源合同/到款混在 `cost_unit_cost_detail`；工作令填写与源标识混在 `cost_work_order`。因此必须采用明确 UPDATE 列白名单，不能把源行整体覆盖到成本表，更不能清空成本业务表后重装。

现有 `snapshot-upsert` 比旧脚本更接近目标，但仍有同名异码归一后重复目标、删除状态、账面精度及重新归属的风险，见下表。旧 `10-sync-to-cost.sql` 和 `manual` 分表脚本不能不加核对地混入新任务。

## 1. 20 张表与同步责任

“17 个实体主键”不等于“17 张要外部同步的表”。当前基线 DDL 的 17 张表含迁移记录；另有本地角色、角色审计、授权锁 3 张，共 20 张。外部同步只涉及 6 张，其中多张混合人工/系统字段。

| 分类 | 表 | 处理要求 |
|---|---|---|
| 源权威明细 | `cost_work_order_ledger_detail` | 凭证源字段可以按稳定源明细 ID 更新；`resolved_stage_code`、`project_id`、`work_order_id` 是本地解析/关联字段；`id` 保留。非人工表，不代表可以每次删除重插。 |
| 源字典＋本地映射 | `cost_unit_dict` | 允许源更新核算编码对应的名称、管理映射、是否院内/集团、启停；保留本地主键、`unit_id` 和备注。相同名称不同历史编码仍保留多行字典。 |
| 源目录＋本地注释 | `cost_model_node` | 允许节点名称、类型、领域、排序、父关系、启停更新；按节点编码保持 `id`，保留备注。 |
| 混合表 | `cost_project` | 源名称/树归属可变；填报/审核/预警状态、责任归属和备注不可被源重置。 |
| 混合表 | `cost_unit_cost_detail` | 源合同/到款；人工目标/审定及已有成本细项/备注保留。 |
| 混合表 | `cost_work_order` | 源字典标识/名称；人工固定金额、阶段、配套信息和备注保留；账面只从明细重算。 |
| 人工填写独立表 | `cost_project_basic` | 整表不纳入外部同步；隐藏字段同样保留。 |
| 本地人工配置 | `cost_subsystem_dict` | 不由源快照清空/覆盖。 |
| 授权与审计 | `cost_user_role`、`cost_user_role_action`、`cost_auth_user_lock`、`cost_user_domain_scope`、`cost_user_project_scope`、`cost_user_unit_scope` | 全部排除外部同步及清库；包含角色/范围版本，不能恢复成旧版本。 |
| 业务预警流程 | `cost_warning_record`、`cost_warning_receiver`、`cost_warning_action_log` | 全部排除外部同步及清库；不因源更新清除处理人、措施、审核/关闭状态或历史日志。 |
| 本地导入审计 | `cost_import_batch`、`cost_import_error` | 保留历史，不随快照删除。新任务可写自己的批次审计，不能覆盖旧批次。 |
| 结构版本 | `cost_schema_migration` | 仅结构升级工具维护，不属于业务同步。 |

依据：`<backend-root>/sql/postgresql92/costree-cost.sql:49-607`，`costree-deploy/17-cost-local-roles-20260907.sql:19-56`；17 个 `@TableName` 实体及直接 JDBC 授权表。

## 2. 已核实的字段保护清单

以下是已存在记录的更新规则。新行可初始化 `DRAFT` 或留空，但不能把初始化规则套到老记录。

### cost_project_basic：整行保留

`quantity`、`product_short_name`、`vertical_division`、`product_attachment_type`、`subsystem_name`、`user_name`、`acquire_method`、`batch_category`、`platform_series`、`research_unit_id`、`research_unit_name`、`target_price`、`competitor_unit_1`、`competitor_price_1`、`competitor_unit_2`、`competitor_price_2`、`contract_amount`、`tax_exempt`、`target_cost_amount`、`approved_amount`、`cycle_start`、`cycle_end`、`stage_code`、`basic_info`、`status`、`remark`、`import_batch_id`、`dept_id`、`owner_user_id`，以及主键、项目关联、审计字段和软删除状态均不由源任务改写。

实际项目办保存入口：`CostProjectBasicServiceImpl.java:213-245`。当前 UI 保存数量、阶段、分系统、型号简称、用户、获取方式、竞争/价格信息、平台系列、周期和提交状态；并非所有 DO 字段都在当前 UI 展示。隐藏不代表允许同步清空。普通新增/编辑与导入入口也存在，整表保护最小且兼容。

### cost_project：源字段与状态分离

- 源更新：`project_name`、`model_node_id`、`domain_code/name`、`category_code/name`、`model_code/name`；显式删除标志须按删除策略审核。
- 保留：`id`、`project_code`、`batch_no`、`stage_codes`、`unit_id`、`unit_name`、`unit_type`、`project_office_status`、`unit_fill_status`、`audit_status`、`dept_id`、`owner_user_id`、`warning_status`、`remark`。
- 保留 `project.id` 才能让 `cost_project_basic.project_id`、单位金额、工作令、预警继续关联。不得仅凭相同项目名合并不同编号。

依据：`snapshot-upsert/05-业务表幂等同步.sql:208-241`、`04-导入前检查.sql:283-289`。

### cost_unit_cost_detail：合同/到款属于源；目标/审定属于人工

- 源更新：`source_record_id`、`source_update_time`、`contract_amount`、`income_amount`。源金额为空是否代表清空必须有固定接口口径；当前 05 是直接赋值 NULL，不是保留旧值。
- 保留：`id`、`target_cost_amount`、`approved_amount`、`salary_amount`、`material_amount`、`outsource_amount`、`manage_amount`、`fuel_power_amount`、`other_amount`、`remark`；`book_cost_amount` 不由源任务赋值，当前重算脚本也不写该字段。
- `stage_code` 和本地软删除状态不能被源默认值重置。现有同步新行阶段为 `ALL`；遇到历史分阶段多行，不能任选一行或累加成新行，需拒绝并出差异。
- `project_id/code/name`、`domain_code/name`、`model_node_id/code/name`、`unit_id/name` 是关联/展示字段。当前 05 只在新增时填，已有行没有刷新；如源主键仍相同但归属变化，必须先判定映射冲突，不能悄悄把人工金额移到另一个项目/单位。

实际人工保存：`CostProjectBasicServiceImpl.java:251-265` 的 `saveResearchFunding` 只按已存在单位金额行 ID 更新 `target_cost_amount`、`approved_amount`。此模块不存在独立的 `CostUnitCostDetailServiceImpl`。源更新白名单依据 `snapshot-upsert/05:292-319`。

### cost_work_order：源字典与研制单位填写混合

- 源更新：`source_work_order_id`、`project_id/code/name`、`unit_id/name`、`accounting_unit_code/name`、`work_order_no/name`、`disabled`；归属/业务键变化要先检查，不可绕过冲突验证。
- 人工/流程保留：`product_target_cost`、`contract_amount`、`income_amount`、`approved_amount`、`stage_codes`、`max_stage_code`、`subsystem_name`、`product_short_name`、`quantity`、`vertical_division`、`status`、`remark`、`import_batch_id`、`dept_id`、`owner_user_id`、`deleted`；主键同样保留。
- `book_cost_amount` 为跨年度借方账面快照，源工作令任务与页面保存均不得直接覆盖；用真实凭证重新汇总。
- 逻辑工作令键不含年份。服务 `fillDefaultFields` 将 `fiscal_year` 置空；历史年份属于凭证和年度展示维度，不应按每年复制工作令固定合同/到款/目标金额。

依据：`CostWorkOrderSaveReqVO.java`；`CostWorkOrderServiceImpl.java:89-119,596-607,627-652`；`snapshot-upsert/05:347-405`。Excel 导入的 `updateSupport=true` 可以主动更新人工填写字段，它属于用户导入操作，不是安全的源同步替代。

### cost_work_order_ledger_detail：稳定明细 ID 与原始金额

允许同步的源字段包括 `source_detail_id`、`fiscal_year`、`accounting_period`、`voucher_date/no`、`accounting_unit_id/code/name`、`manage_unit_name`、`subject_id/code/name`、`project_code`、`source_project_id`、`project_name`、`source_work_order_id`、`work_order_no/name`、`debit_credit`、`amount`、`amount_wan`、`summary_text`、`source_lastmodify`、`second_subject_code/name`、`source_timestamp`、明确的源删除状态。本地 `id` 不变，`project_id/work_order_id/resolved_stage_code` 由校验后的关联派生。

`amount` 原值单位元，页面万元以 `amount / 10000.0` 优先。借贷都存储，当前账面口径只统计借方；负数借方冲销保留。稳定源键必须识别同一凭证明细，不能每批重新生成，不能仅凭单位名称/金额去重。

## 3. 业务键、ID 与引用

| 表 | 同步键 | 必须保持 |
|---|---|---|
| 单位字典 | 租户＋实际核算编码 | 老/新编码独立保留，关联名称及管理归属须一致或拒绝。 |
| 型号树 | 租户＋节点编码 | 节点 `id`、按节点编码解析出的 `parent_id`。 |
| 项目 | 租户＋主业项目编号 | `id`；人工基本情况和所有业务表继续引用它。 |
| 单位金额 | 租户＋项目编号＋实际核算单位名称；稳定 `source_record_id` 辅助识别 | `id`；源 ID 与逻辑键若同时命中不同记录必须拒绝。 |
| 工作令 | 租户＋项目编号＋实际核算单位名称＋工作令编号；稳定 `source_work_order_id` 辅助识别 | `id`；不加入年份以免重复固定金额。 |
| 账面明细 | 租户＋稳定 `source_detail_id` | 明细 `id`、项目/工作令引用、原始发生年度；源 ID 跨年份是否唯一须验证。 |

说明：业务 DO 的 `ASSIGN_ID` 只适用于 Java 插入；云鲸执行 SQL 不会经过 Java 主键生成器。新行必须依赖已验证的数据库默认 sequence/identity 或显式受控生成，不能再产生 `id=NULL`。已有 `id` 不更新、不按当前批次重新编号。

## 4. 已确认的脚本问题与最小兼容处理

| 优先级 | 已确认问题 | 精确证据 | 最小处理 |
|---|---|---|---|
| P1 | 旧总同步覆盖手填/流程。 | `<backend-root>/sql/postgresql92/costree-integration/10-sync-to-cost.sql:445` 强制 FILLED/SUBMITTED；485-501 覆盖项目办字段并清空旧金额；671-675 覆盖工作令阶段、分系统、简称、数量、纵向与备注。 | 新云鲸任务禁用该整段；按本报告白名单保留现有应用表。 |
| P1 | 旧总同步根据本批缺失软删除有人工字段的记录；还改 creator，不能靠 creator 可靠区分“人工/源”。 | 同文件 559-560、584-592、676-677、705-714。 | 快照缺失只输出差异，不自动删除，不改变已有 creator/create_time。 |
| P1 | 旧 manual 分表仍覆盖备注及删除状态。 | `manual/04-同步单位金额-cost_unit_cost_detail.sql:137-138`；`manual/05-同步工作令-cost_work_order.sql:155-156`。 | 不因“金额列已保护”就认为全手填已保护；移除备注/本地删除覆盖。 |
| P1 | snapshot 源查重用编码，落库键却用名称，历史同名异码可碰撞。 | `snapshot-upsert/04:155,181` 源查重；`05:261,333` 解析名称；279-288、351-363 按名称匹配，292、367 UPDATE。 | 对归一化后的源逻辑键、非空源主键、匹配 target_id 做一对一检查。多源命中同一 target_id 立即停止。不能任意 SUM/MAX/min(id) 选一行。 |
| P1 | 归一化不一致可绕开源重复检查。 | `04:77-78` 按原编码查重，`05` 普遍先 btrim 再写。 | 校验与写入用同一规范化临时结果；先 trim 后查空/重复。 |
| P1 | 单位金额 source_deleted 语义未落实。 | `05:266-267` 解析 deleted；292-301 更新不检查/设置 deleted；319 仅控制新增。 | 不能称为已支持源删除。保护填报版本应拒绝待删除的混合记录并生成差异，或另行审定停用方案；不得把 deleted=0 自动恢复已人工删除行。 |
| P1 | 相同 source_record_id/source_work_order_id 与逻辑键冲突时，当前优先源 ID 并取 min(id)。 | `05:279-288,351-363,461-477`。 | 先拒绝多个源 ID 指向同一逻辑对象/多个目标；源 ID 与逻辑键命中不同 target_id 同样拒绝。需要改业务键时出人工迁移清单，不能悄悄搬走人工字段。 |
| P1 | 快照重算优先逐条已舍入的 amount_wan，和后端原元优先不同。 | `06-重算工作令账面.sql` 的 `sum(COALESCE(d.amount_wan, d.amount / 10000.0))`；后端 `CostWorkOrderLedgerDetailMapper.java:453,459-461` 原元优先。 | `SUM(COALESCE(amount / 10000.0, amount_wan,0))` 后再按展示/存储精度舍入；补小额凭证多行合计回归。 |
| P2 | 只重算本批工作令；若被当作真正 CDC 增量使用，只有账面变化而无工作令快照，会遗漏重算。 | `06` 的 tmp_cost_recalc_work_order 只从 stg_work_order 生成。 | 当前任务必须明确是完整快照六表；如未来支持 CDC，应将受影响工作令从变更明细和旧关联共同收集。 |
| P2 | 分文件提交：07 摘要失败不会回滚已提交的 05/06；同步期间用户编辑也会引起保护摘要不一致。 | `05`、`06` 各自 COMMIT；总说明明确分阶段状态。 | 每节点失败即停止；安排无人工编辑时间窗/短维护窗口；验收失败保留批次与差异，不能自动标成功或重装全表。 |

注：同名异码本身不会让每条凭证自动翻倍。真正风险是同一业务明细换了源 ID 被再次 INSERT，或同名多编码在非唯一 JOIN 后被放大，以及跨年重复导入同一固定累计金额。反之两张不同真实凭证应累加，不能因为同名或同金额就去重。

## 5. 推荐的最小云鲸节点链

1. 固定租户/schema，单任务串行。校验表结构和 SQL 插入所需 ID 默认值，不允许并发另一批清空共享中间表。
2. 只清 `cost_sync_stage.stg_*`，完整载入六张源快照。禁止 DELETE/TRUNCATE 成本业务表和人工/授权/预警表。
3. 规范化后检查主键、逻辑键、实际单位名称映射、target_id 一对一、金额格式、引用完整性。检查失败不更新成本表。
4. 采集人工保护摘要，按表白名单 UPDATE 已有/INSERT 新增，已有行 ID 不变。
5. 从全部有效借方明细按原元口径重算受影响逻辑工作令，不加年度到逻辑键，不改收益率公式。
6. 核对源/目标数量和借方金额、人工保护摘要、项目/工作令关联；同批重跑后数量/金额必须不变，成功后才记录 SUCCESS。
7. 源缺失/显式删除、历史同名不同归属、多源同目标、项目编号变更仅出异常清单；单独处理，不默默合并或清空手填。

现场仍需确认：云鲸源表字段映射、稳定源 ID 是否跨年唯一、预分预控金额是累计快照还是期间发生额。源码/脚本审计不能替代这些数据事实。本轮只写审计文档，未运行前后端构建或真实数据库验证。
