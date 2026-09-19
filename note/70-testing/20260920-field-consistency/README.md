# 成本字段一致性核查（2026-09-20）

**状态更新：F01–F08 已修复，详见 [修复及验证记录](H:/light/project/costree/note/70-testing/20260920-field-consistency/FIXES.md)。以下保留修复前核查记录，代码行号对应当时工作区。**

## 本轮完成

- “用户”选项新增“军科委”，采集页与详情基本情况页共用 costUserOptions；保存仍使用 cost_project_basic.user_name，未新增字典表。
- 经用户确认，目录卡片与列表均显示“平台/系列”，读取项目接口新增返回的 platformSeries。运载/空间按现有规则取项目名称；导弹/卫星取最新基本情况的 platform_series。无填报值显示“待完善”，不再拿 category_name 冒充。
- 左侧型号树、系列筛选仍使用型号树分类。没有修改权限、金额公式、数据库结构、真实数据、旧离线包。
- 初次核查仅实施以上两项，随后已完成 F01–F08 修复。既有后端 DDL.sql 改动保留，不属于本轮新增。

## 字段来源基线

| 概念 | 数据来源 | 注意事项 |
|---|---|---|
| 型号树系列/类别 | cost_project.category_code/category_name，目录树 SERIES 节点 | 分类筛选；不同于填报平台 |
| 平台/系列 | cost_project_basic.platform_series；运载/空间取项目名称 | 目录新增接口返回，不新增数据库列 |
| 项目类别/批次 | cost_project_basic.batch_category；运载/导弹取项目名称 | 不等于同步的 cost_project.batch_no |
| 用户（业务客户） | cost_project_basic.user_name | “军科委”属于业务选项，不是 system_users 账号或角色 |
| 型号简称 | cost_project_basic.product_short_name | 与下面工作令字段分属两张表 |
| 工作令简称 | cost_work_order.product_short_name | 不能因 Java 属性名相同就视作型号简称 |

## 检出的问题

| 编号 | 优先级 | 问题及触发影响 | 源码证据 | 建议 |
|---|---|---|---|---|
| F01 | 高 | 隐藏字段本身不是缺陷。项目详情仍有独立新增入口，该入口不携带型号简称、配套数；传统提交接口只更新状态，绕过采集页的必填规则。新增记录成为最新记录后，目录/项目标题/对比读取它，原有简称、配套数等可能显示为空；旧记录并未被删除。 | [详情表单](H:/light/project/sqlbot_with_bcback/costree-frontend/src/views/cost/projectDetail/index.vue:593)；[传统提交](H:/light/project/sqlbot_with_bcback/baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/service/projectbasic/CostProjectBasicServiceImpl.java:111)；[采集提交校验](H:/light/project/sqlbot_with_bcback/baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/service/projectbasic/CostProjectBasicServiceImpl.java:260)；[最新记录显示](H:/light/project/sqlbot_with_bcback/baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/service/project/CostProjectServiceImpl.java:95) | 统一新增/编辑/提交字段与采集页，并明确“多条基本情况”和“项目级单条填报”的关系；优先修复。 |
| F02 | 高 | 页面隐藏“是否产品附件/发射车”，运载领域不要求分系统；Excel 导入却对所有领域强制要求这两项。按现行界面口径整理的导入文件会被拒绝。 | [Excel 必填](H:/light/project/sqlbot_with_bcback/baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/service/projectbasic/CostProjectBasicServiceImpl.java:453)；[界面领域规则](H:/light/project/sqlbot_with_bcback/costree-frontend/src/views/cost/utils/reportingRules.ts:20) | Excel 导入应复用同一领域和提交规则；隐藏字段需兼容旧模板但不能继续强制填写。 |
| F03 | 高 | Excel 模板仍要求用户看到/填写“型号项目合同金额、目标成本、审定金额”，导入构造对象时却主动把三项清空。会出现“导入成功但金额没保存”的误解；这三项当前来自单位成本/科研经费等权威来源。 | [模板样例金额](H:/light/project/sqlbot_with_bcback/baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/controller/admin/projectbasic/CostProjectBasicController.java:178)；[清空非权威金额](H:/light/project/sqlbot_with_bcback/baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/service/projectbasic/CostProjectBasicServiceImpl.java:383)；[导入调用链](H:/light/project/sqlbot_with_bcback/baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/service/projectbasic/CostProjectBasicServiceImpl.java:423) | 从新模板移除只读汇总金额或明确标记不导入；旧文件识别这些列并反馈不采纳，不能改成覆盖权威金额。 |
| F04 | 中 | 详情新增时用 cost_project.category_name 预填 platformSeries，卫星/导弹可能把型号树分类当作人工填报平台直接保存。 | [错误预填](H:/light/project/sqlbot_with_bcback/costree-frontend/src/views/cost/projectDetail/index.vue:861)；[平台选项](H:/light/project/sqlbot_with_bcback/costree-frontend/src/views/cost/utils/reportingRules.ts:18) | 取消跨字段预填；人工选择领域初始为空，运载/空间沿用项目名称规则。 |
| F05 | 中 | 型号对比显示“项目批次”读取 cost_project.batch_no；目录“项目类别/批次”读取最新 cost_project_basic.batch_category（运载/导弹使用项目名称）。对比接口已返回 batchCategory，但矩阵没有展示它。 | [对比旧批次](H:/light/project/sqlbot_with_bcback/costree-frontend/src/views/cost/modelComparison/index.vue:349)；[已返回填报批次](H:/light/project/sqlbot_with_bcback/baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/service/modelcomparison/CostModelComparisonServiceImpl.java:254)；[目录填报批次](H:/light/project/sqlbot_with_bcback/costree-frontend/src/views/cost/catalog/index.vue:219) | 明确是否保留“同步批次”独立字段；对比的业务类别/批次应与目录一致，不能仅改表头。 |
| F06 | 中 | 同一 cost_project_basic.stage_code：采集页多选并以逗号保存，详情编辑页单选。已有 M,C 等值无法按多选回显，重新选择并保存会替换为一个阶段。 | [采集多选](H:/light/project/sqlbot_with_bcback/costree-frontend/src/views/cost/collect/index.vue:482)；[逗号存储](H:/light/project/sqlbot_with_bcback/costree-frontend/src/views/cost/collect/index.vue:1220)；[详情单选](H:/light/project/sqlbot_with_bcback/costree-frontend/src/views/cost/projectDetail/index.vue:388) | 两入口统一多选与拆分/合并规则，并验证旧单阶段与多阶段往返保存。 |
| F07 | 中 | 项目获取方式：采集页自由输入，详情页只有“单一来源/竞标/装备/批产”三个下拉选项。同一字段在两个入口允许的值不一致。 | [采集输入](H:/light/project/sqlbot_with_bcback/costree-frontend/src/views/cost/collect/index.vue:564)；[详情固定选项](H:/light/project/sqlbot_with_bcback/costree-frontend/src/views/cost/projectDetail/index.vue:586) | 确认该字段采用字典还是自由填写，再统一入口并保留历史值。 |
| F08 | 低 | 名称残留：基本情况 productShortName 页面叫“型号简称”，Excel 仍叫“产品简称”；工作令 productShortName 采集叫“工作令简称”，详情/工作令列表/待分配池仍叫“产品简称”；对比 platformSeries 叫“所属平台/类型”，填报叫“平台/系列”。前两个同名属性分属不同表，不能全局替换为同一业务名称。 | [基本情况模板](H:/light/project/sqlbot_with_bcback/baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/controller/admin/projectbasic/vo/CostProjectBasicImportExcelVO.java:29)；[工作令采集](H:/light/project/sqlbot_with_bcback/costree-frontend/src/views/cost/collect/index.vue:247)；[工作令详情](H:/light/project/sqlbot_with_bcback/costree-frontend/src/views/cost/projectDetail/index.vue:489)；[对比名称](H:/light/project/sqlbot_with_bcback/costree-frontend/src/views/cost/modelComparison/index.vue:356) | 按表和业务概念统一名称，Excel 新旧表头兼容读取，避免旧模板失效。 |

## 需要区分、不能直接判为错误的口径

- 收益率：维持用户此前确认的账面/到款，仅更名，不改公式。
- 首页“执行率”使用院内账面/院内合同；项目详情“院内目标成本执行率”使用院内账面/院内目标成本。分母不同，数值不同有明确代码原因，不能强行统一公式；建议名称/提示明确“合同”与“目标成本”。
- 目录左侧系列、采集项目列表 categoryName、项目详情顶部分类来自型号树，与填报平台是两个概念。本次仅按已确认范围替换目录卡片/列表展示；其他分类保留，后续建议名称明确为“型号树系列”。
- 多处读取“最新基本情况”按 update_time DESC、id DESC，未限定 SUBMITTED；草稿也可能作为目录及对比信息来源。是否应仅展示已提交记录需要业务确认，不能擅自改变。

## 验证与范围

- 后端：CostProjectFilledUserTest、CostReportingRulesTest、CostProjectBasicValidationTest，共 7 项通过；Maven BUILD SUCCESS。
- 新增回归覆盖：四领域英文编码与内网数字编码/领域名称；人工平台与项目名称派生；最新填报优先；缺失值不回退型号树分类；保留 categoryName；原空权限保护。
- 前端：cost-reporting-rules.test.cjs 4 项通过；pnpm ts:check:cost 通过；git diff --check 通过。
- 源码静态核查覆盖采集、目录、项目详情、基本情况列表、型号对比、工作令/待分配页面、项目/填报接口和 Excel 模板/导入/导出。未执行真实数据库写入、浏览器保存、内网或全系统验收。
- 本轮无需新增 SQL。上线这两项需要一起更新前端和 cost 后端（目录依赖新增的 platformSeries 返回）；本轮未构建发布包、提交或推送。
