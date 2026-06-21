# Controller / Service / Mapper 生成清单

状态：初稿

## 1. 目标

把成本库后端要生成的 Java 文件拆成小任务，后续每次只生成一个对象或一个接口组，降低 AI 生成错误。生成代码前必须同时引用：

- `10-research/03-参考模块清单.md`
- `30-data/schema-mvp.sql`
- `40-api/01-接口清单-MVP.md`
- `40-api/02-接口字段契约.md`

## 2. 后端仓库和模块

| 项 | 路径/说明 |
|---|---|
| 后端仓库 | `<backend-root>` |
| 长期模块 | `yudao-module-cost`【需技术确认】 |
| API 子模块 | `yudao-module-cost-api`【需技术确认】 |
| Biz 子模块 | `yudao-module-cost-biz`【需技术确认】 |
| 兜底方案 | 如暂不允许新增模块，可先放入既有模块的 `cost` 子包【需技术确认】 |

## 3. 生成批次

| 批次 | 目标 | 文件范围 | 验收方式 |
|---|---|---|---|
| B1 | 模块骨架 | Maven 模块、包目录、基础依赖、启动接入 | 后端可启动，空模块不报错 |
| B2 | 只读基础链路 | 型号树、成本项目查询 | 可查 `cost_model_node`、`cost_project` |
| B3 | 项目办维护链路 | 项目基本情况 CRUD、导入、导出 | 可维护 `cost_project_basic` |
| B4 | 研制单位维护链路 | 工作令基础信息 CRUD、导入、导出 | 可维护 `cost_work_order` |
| B5 | 预警和导入结果 | 预警分页、测试推送、导入批次/错误返回 | 可查 `cost_warning_record`，可模拟推送 |

建议严格按批次推进，不要一次生成全部文件。

## 4. 包路径约定

以下路径以新增 `yudao-module-cost` 为准。

| 层 | 包路径 |
|---|---|
| Controller | `cn.iocoder.yudao.module.cost.controller.admin.*` |
| VO | `cn.iocoder.yudao.module.cost.controller.admin.*.vo` |
| Service | `cn.iocoder.yudao.module.cost.service.*` |
| DO | `cn.iocoder.yudao.module.cost.dal.dataobject.*` |
| Mapper | `cn.iocoder.yudao.module.cost.dal.mysql.*` |
| ErrorCode | `cn.iocoder.yudao.module.cost.enums.ErrorCodeConstants`【需确认现有模块习惯】 |
| Convert | 当前参考模块 `finance/baseworkhour` 未使用独立 Convert，优先使用 `BeanUtils.toBean()`；是否新增 Convert 需技术确认 |

## 5. 对象级生成清单

### 5.1 型号树 `cost_model_node`

用途：领域/系列/型号树，只读为主，MVP 可先不做后台维护页面。

| 文件 | 是否生成 | 路径草案 |
|---|---|---|
| Controller | 是 | `controller/admin/modelnode/CostModelNodeController.java` |
| PageReqVO | 可选 | `controller/admin/modelnode/vo/CostModelNodePageReqVO.java`【若只做 tree 可不生成】 |
| ListReqVO | 是 | `controller/admin/modelnode/vo/CostModelNodeListReqVO.java` |
| RespVO | 是 | `controller/admin/modelnode/vo/CostModelNodeRespVO.java` |
| SaveReqVO | 暂不生成 | MVP 暂不维护树节点 |
| DO | 是 | `dal/dataobject/modelnode/CostModelNodeDO.java` |
| Mapper | 是 | `dal/mysql/modelnode/CostModelNodeMapper.java` |
| Service | 是 | `service/modelnode/CostModelNodeService.java` |
| ServiceImpl | 是 | `service/modelnode/CostModelNodeServiceImpl.java` |

接口：

| 方法 | 路径 | 权限点 |
|---|---|---|
| GET | `/cost/model-node/tree` | `cost:project:query` |

实现注意：

- 树构造可参考前端 `handleTree` 思路；后端可返回平铺或树形，优先按接口契约返回 `children`。
- 查询默认过滤 `deleted = 0` 和 `status = ENABLE`【需确认】。

### 5.2 成本项目/主业项目锚定 `cost_project`

用途：成本项目列表、项目锚定信息、状态流转。

| 文件 | 是否生成 | 路径草案 |
|---|---|---|
| Controller | 是 | `controller/admin/project/CostProjectController.java` |
| PageReqVO | 是 | `controller/admin/project/vo/CostProjectPageReqVO.java` |
| RespVO | 是 | `controller/admin/project/vo/CostProjectRespVO.java` |
| UpdateStatusReqVO | 是 | `controller/admin/project/vo/CostProjectUpdateStatusReqVO.java` |
| SaveReqVO | 暂不生成 | MVP 项目数据先用 SQL 种子和导入模拟，是否开放新增项目【需确认】 |
| DO | 是 | `dal/dataobject/project/CostProjectDO.java` |
| Mapper | 是 | `dal/mysql/project/CostProjectMapper.java` |
| Service | 是 | `service/project/CostProjectService.java` |
| ServiceImpl | 是 | `service/project/CostProjectServiceImpl.java` |

接口：

| 方法 | 路径 | 权限点 |
|---|---|---|
| GET | `/cost/project/page` | `cost:project:query` |
| GET | `/cost/project/get?id=` | `cost:project:query` |
| PUT | `/cost/project/update-status` | `cost:project:submit` |

实现注意：

- `get` 用于页面左侧锚定信息，不允许前端编辑锚定字段。
- 状态流转第一版只改 `audit_status`，是否同步项目基本情况/工作令状态【需确认】。
- 数据权限预留 `dept_id`、`owner_user_id`，真实规则待确认。

### 5.3 项目基本情况 `cost_project_basic`

用途：项目办维护，原型 `Table 2`。

| 文件 | 是否生成 | 路径草案 |
|---|---|---|
| Controller | 是 | `controller/admin/projectbasic/CostProjectBasicController.java` |
| PageReqVO | 是 | `controller/admin/projectbasic/vo/CostProjectBasicPageReqVO.java` |
| RespVO | 是 | `controller/admin/projectbasic/vo/CostProjectBasicRespVO.java` |
| SaveReqVO | 是 | `controller/admin/projectbasic/vo/CostProjectBasicSaveReqVO.java` |
| ImportExcelVO | 是 | `controller/admin/projectbasic/vo/CostProjectBasicImportExcelVO.java` |
| ExportExcelVO | 可选 | 若现有导出直接用 RespVO，可不单独生成【需确认】 |
| DO | 是 | `dal/dataobject/projectbasic/CostProjectBasicDO.java` |
| Mapper | 是 | `dal/mysql/projectbasic/CostProjectBasicMapper.java` |
| Service | 是 | `service/projectbasic/CostProjectBasicService.java` |
| ServiceImpl | 是 | `service/projectbasic/CostProjectBasicServiceImpl.java` |

接口：

| 方法 | 路径 | 权限点 |
|---|---|---|
| GET | `/cost/project-basic/page` | `cost:project-basic:query` |
| GET | `/cost/project-basic/get?id=` | `cost:project-basic:query` |
| POST | `/cost/project-basic/create` | `cost:project-basic:create` |
| PUT | `/cost/project-basic/update` | `cost:project-basic:update` |
| DELETE | `/cost/project-basic/delete?id=` | `cost:project-basic:delete` |
| GET | `/cost/project-basic/export-excel` | `cost:project-basic:export` |
| GET | `/cost/project-basic/get-import-template` | `cost:project-basic:import` |
| POST | `/cost/project-basic/import` | `cost:project-basic:import` |

实现注意：

- `projectId` 必须存在，保存时从 `cost_project` 回填 `projectCode`、`projectName`。
- 金额字段不能小于 0。
- `cycleEnd` 不能早于 `cycleStart`。
- `approvedAmount` 第一阶段可作为普通字段保存，正式审批回写规则【需确认】。
- 导入逻辑参考 `BaseWorkHourController`、`BaseWorkHourImportExcelVO`、`BaseWorkHourServiceImpl#importBaseWorkList`。

### 5.4 工作令基础信息 `cost_work_order`

用途：研制单位维护，原型 `Table 3`。

| 文件 | 是否生成 | 路径草案 |
|---|---|---|
| Controller | 是 | `controller/admin/workorder/CostWorkOrderController.java` |
| PageReqVO | 是 | `controller/admin/workorder/vo/CostWorkOrderPageReqVO.java` |
| RespVO | 是 | `controller/admin/workorder/vo/CostWorkOrderRespVO.java` |
| SaveReqVO | 是 | `controller/admin/workorder/vo/CostWorkOrderSaveReqVO.java` |
| ImportExcelVO | 是 | `controller/admin/workorder/vo/CostWorkOrderImportExcelVO.java` |
| ExportExcelVO | 可选 | 若现有导出直接用 RespVO，可不单独生成【需确认】 |
| DO | 是 | `dal/dataobject/workorder/CostWorkOrderDO.java` |
| Mapper | 是 | `dal/mysql/workorder/CostWorkOrderMapper.java` |
| Service | 是 | `service/workorder/CostWorkOrderService.java` |
| ServiceImpl | 是 | `service/workorder/CostWorkOrderServiceImpl.java` |

接口：

| 方法 | 路径 | 权限点 |
|---|---|---|
| GET | `/cost/work-order/page` | `cost:work-order:query` |
| GET | `/cost/work-order/get?id=` | `cost:work-order:query` |
| POST | `/cost/work-order/create` | `cost:work-order:create` |
| PUT | `/cost/work-order/update` | `cost:work-order:update` |
| DELETE | `/cost/work-order/delete?id=` | `cost:work-order:delete` |
| GET | `/cost/work-order/export-excel` | `cost:work-order:export` |
| GET | `/cost/work-order/get-import-template` | `cost:work-order:import` |
| POST | `/cost/work-order/import` | `cost:work-order:import` |

实现注意：

- `workOrderNo` 在租户内唯一。
- `projectId` 必须存在，跨主业工作令也必须先选择主业项目。
- `quantity` 必须大于 0。
- `productTargetCost` 不能小于 0。
- `bookCostAmount` 外网测试用于预警；真实账面成本来源【需确认】。
- `maxStageCode` 可由后端根据 `stageCodes` 计算，阶段排序规则仍需业务确认。

### 5.5 导入批次和导入错误

用途：记录导入结果，供项目基本情况和工作令导入共用。

| 文件 | 是否生成 | 路径草案 |
|---|---|---|
| Controller | 暂不单独生成 | 导入结果由业务导入接口返回 |
| RespVO | 是 | `controller/admin/importbatch/vo/CostImportResultRespVO.java`、`CostImportErrorRespVO.java` |
| DO | 是 | `dal/dataobject/importbatch/CostImportBatchDO.java`、`CostImportErrorDO.java` |
| Mapper | 是 | `dal/mysql/importbatch/CostImportBatchMapper.java`、`CostImportErrorMapper.java` |
| Service | 是 | `service/importbatch/CostImportBatchService.java` |
| ServiceImpl | 是 | `service/importbatch/CostImportBatchServiceImpl.java` |

实现注意：

- 不建议第一阶段暴露单独的导入批次管理页面。
- 导入成功/失败统计由业务 Service 调用导入批次 Service 写入。
- 错误明细返回 `rowNum`、`fieldName`、`errorMessage`、`rawData`。

### 5.6 预警记录 `cost_warning_record`

用途：10% 超支预警简版、全部推送模拟。

| 文件 | 是否生成 | 路径草案 |
|---|---|---|
| Controller | 是 | `controller/admin/warning/CostWarningController.java` |
| PageReqVO | 是 | `controller/admin/warning/vo/CostWarningPageReqVO.java` |
| RespVO | 是 | `controller/admin/warning/vo/CostWarningRespVO.java` |
| PushReqVO | 是 | `controller/admin/warning/vo/CostWarningPushReqVO.java` |
| PushRespVO | 是 | `controller/admin/warning/vo/CostWarningPushRespVO.java` |
| DO | 是 | `dal/dataobject/warning/CostWarningRecordDO.java` |
| Mapper | 是 | `dal/mysql/warning/CostWarningRecordMapper.java` |
| Service | 是 | `service/warning/CostWarningService.java` |
| ServiceImpl | 是 | `service/warning/CostWarningServiceImpl.java` |

接口：

| 方法 | 路径 | 权限点 |
|---|---|---|
| GET | `/cost/warning/page` | `cost:warning:query` |
| POST | `/cost/warning/push` | `cost:warning:push` |

实现注意：

- 分页响应建议联表补 `projectCode`、`projectName`、`workOrderNo`；是否改表冗余这些字段【需确认】。
- `push` 第一版只更新 `pushStatus`、`pushedTime`，是否写中心消息表【需确认】。
- 预警扫描任务不在首轮生成；先用种子数据和手动推送跑通页面。

## 6. 公共错误码草案

| 错误码常量 | 说明 |
|---|---|
| `COST_PROJECT_NOT_EXISTS` | 成本项目不存在 |
| `COST_PROJECT_BASIC_NOT_EXISTS` | 项目基本情况不存在 |
| `COST_WORK_ORDER_NOT_EXISTS` | 工作令基础信息不存在 |
| `COST_WORK_ORDER_NO_DUPLICATE` | 工作令编号已存在 |
| `COST_AMOUNT_NEGATIVE` | 金额不能小于 0 |
| `COST_CYCLE_INVALID` | 研制周期结束时间不能早于开始时间 |
| `COST_STAGE_INVALID` | 阶段值不合法 |
| `COST_IMPORT_FILE_EMPTY` | 导入文件为空 |
| `COST_WARNING_NOT_EXISTS` | 预警记录不存在 |

错误码数值范围需要对齐中台统一分配规则【需技术确认】。

## 7. 生成规则

- 每次生成前引用 `10-research/03-参考模块清单.md`，优先仿照 `finance/baseworkhour`。
- 不引入 Java 8 不支持的语法。
- 不绕开中台权限、日志、Excel 工具和响应格式。
- Controller 返回值使用 `CommonResult` / `PageResult`。
- Controller 权限使用 `@PreAuthorize("@ss.hasPermission('cost:...')")`。
- 分页 Mapper 使用 `BaseMapperX` + `LambdaQueryWrapperX`。
- DO 继承 `BaseDO`，字段与 `schema-mvp.sql` 保持一致。
- 导入导出使用现有 `ExcelUtils` 和 EasyExcel 注解风格。
- 先实现查询和 CRUD，再实现导入导出，最后实现预警推送。

## 8. 首轮推荐生成顺序

| 顺序 | 生成内容 | 原因 |
|---|---|---|
| 1 | `CostModelNodeDO/Mapper/Service/Controller` | 验证新模块可查库 |
| 2 | `CostProjectDO/Mapper/Service/Controller` | 打通项目列表和锚定信息 |
| 3 | `CostProjectBasic` 全套 CRUD | 项目办 MVP 主链路 |
| 4 | `CostWorkOrder` 全套 CRUD | 研制单位 MVP 主链路 |
| 5 | 项目基本情况导入导出 | 复用 BaseWorkHour 导入模式 |
| 6 | 工作令导入导出 | 补齐研制单位批量维护 |
| 7 | `CostWarning` 查询和推送 | 跑通预警演示 |

## 9. 暂不生成

| 对象 | 原因 |
|---|---|
| 正式 BPM 流程接入 | 第一阶段只做草稿/提交状态 |
| 复杂驾驶舱统计接口 | 二阶段 |
| 成本树详情接口 | 二阶段 |
| 型号对比接口 | 二阶段 |
| 定时预警扫描 Job | MVP 先使用种子数据和手动推送 |
| 字段级权限控制 | MVP 通过页面、按钮、接口和数据权限拆分 |
