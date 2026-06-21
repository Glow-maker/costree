# yudao-module-cost 后端设计

状态：初稿

## 后端仓库

`<backend-root>`

## 模块落点

建议长期形态为 `yudao-module-cost`。

【需技术确认】如果内网暂不允许新增模块，可先放入既有模块的 `cost` 子包中。

## 待设计内容

- Maven 模块结构
- API/Biz 分层
- Controller 包路径
- Service 包路径
- Mapper 包路径
- DO/VO/Convert 类
- 权限标识
- 数据权限接入方式
- Excel 导入导出
- 预警与消息复用方式

## 业务聚合划分

| 聚合 | 原型来源 | 主要角色 | Controller 前缀草案 |
|---|---|---|---|
| 成本项目/主业项目锚定 | `Table 1` | 所有授权角色只读，管理员维护测试数据 | `/cost/project` |
| 项目基本情况 | `Table 2` | 项目办 | `/cost/project-basic` |
| 工作令基础信息 | `Table 3` | 研制单位 | `/cost/work-order` |
| 成本预警 | 预警页 | 管理员、管理层【需确认】 | `/cost/warning` |

## 包路径草案

| 层 | 路径草案 |
|---|---|
| Controller | `cn.iocoder.yudao.module.cost.controller.admin.project`、`projectbasic`、`workorder`、`warning` |
| Service | `cn.iocoder.yudao.module.cost.service.project`、`projectbasic`、`workorder`、`warning` |
| DO | `cn.iocoder.yudao.module.cost.dal.dataobject.project`、`projectbasic`、`workorder`、`warning` |
| Mapper | `cn.iocoder.yudao.module.cost.dal.mysql.project`、`projectbasic`、`workorder`、`warning` |
| VO | `cn.iocoder.yudao.module.cost.controller.admin.*.vo` |
| Convert | `cn.iocoder.yudao.module.cost.convert.*`【需确认是否沿用现有 MapStruct 目录习惯】 |

## 权限和数据权限原则

- Controller 权限使用 `@PreAuthorize("@ss.hasPermission('cost:...')")`。
- 项目基本情况接口使用 `cost:project-basic:*` 权限。
- 工作令基础信息接口使用 `cost:work-order:*` 权限。
- 数据权限优先通过 `cost_project` 预留 `dept_id`、`unit_id`、`owner_user_id` 等字段承接【需确认真实规则】。
- MVP 不通过一个接口同时保存项目基本情况和工作令基础信息，避免项目办/研制单位权限边界混乱。
