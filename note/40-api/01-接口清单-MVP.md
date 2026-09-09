# 接口清单 - MVP

状态：历史 MVP 草案保留；当前本地授权接口见文末 [2026-09-08 增补](#local-auth-api)。

## 命名口径

接口路径不使用 `table2`、`table3`。原型 `Table 2` 对应 `/cost/project-basic`，原型 `Table 3` 对应 `/cost/work-order`。

## 接口组草案

| 接口组 | 路径前缀 | 说明 |
|---|---|---|
| 型号树 | `/cost/model-node` | 领域/系列/型号树 |
| 成本项目 | `/cost/project` | 项目列表、详情、状态 |
| 单位字典 | `/cost/unit-dict` | 成本树院内/院外单位分类 |
| 项目基本情况 | `/cost/project-basic` | 项目办维护，原型 `Table 2` |
| 工作令基础信息 | `/cost/work-order` | 研制单位维护，原型 `Table 3` |
| 总体展示 | `/cost/overview` | 按领域和研制单位实时聚合 |
| 导入导出 | 复用各业务前缀 | 模板下载、导入、导出 |
| 预警 | `/cost/warning` | 10% 超支预警简版 |

## 通用接口形态

- `/page`
- `/get`
- `/create`
- `/update`
- `/delete`
- `/export-excel`
- `/get-import-template`
- `/import`

## MVP 接口草案

| 方法 | 路径 | 权限点 | 说明 |
|---|---|---|---|
| GET | `/cost/project/page` | `cost:project:query` | 成本项目分页 |
| GET | `/cost/project/get?id=` | `cost:project:query` | 主业项目锚定信息 |
| PUT | `/cost/project/update-status` | `cost:project:submit` | 草稿/提交状态流转【需确认粒度】 |
| GET | `/cost/unit-dict/list` | `cost:project:query` | 单位字典列表，用于成本树院内/院外分类 |
| GET | `/cost/project-basic/page` | `cost:project-basic:query` | 项目基本情况分页 |
| GET | `/cost/project-basic/get?id=` | `cost:project-basic:query` | 项目基本情况详情 |
| POST | `/cost/project-basic/create` | `cost:project-basic:create` | 新增项目基本情况 |
| PUT | `/cost/project-basic/update` | `cost:project-basic:update` | 编辑项目基本情况 |
| DELETE | `/cost/project-basic/delete?id=` | `cost:project-basic:delete` | 删除项目基本情况 |
| GET | `/cost/project-basic/export-excel` | `cost:project-basic:export` | 导出项目基本情况 |
| GET | `/cost/project-basic/get-import-template` | `cost:project-basic:import` | 下载项目基本情况模板 |
| POST | `/cost/project-basic/import` | `cost:project-basic:import` | 导入项目基本情况 |
| GET | `/cost/work-order/page` | `cost:work-order:query` | 工作令基础信息分页 |
| GET | `/cost/work-order/get?id=` | `cost:work-order:query` | 工作令基础信息详情 |
| POST | `/cost/work-order/create` | `cost:work-order:create` | 新增工作令基础信息 |
| PUT | `/cost/work-order/update` | `cost:work-order:update` | 编辑工作令基础信息 |
| DELETE | `/cost/work-order/delete?id=` | `cost:work-order:delete` | 删除工作令基础信息 |
| GET | `/cost/work-order/export-excel` | `cost:work-order:export` | 导出工作令基础信息 |
| GET | `/cost/work-order/get-import-template` | `cost:work-order:import` | 下载工作令基础信息模板 |
| POST | `/cost/work-order/import` | `cost:work-order:import` | 导入工作令基础信息 |
| GET | `/cost/overview/summary` | `cost:project:query` | 按领域聚合总体展示 |
| GET | `/cost/overview/unit-detail` | `cost:project:query` | 按领域、项目、阶段和研制单位聚合成本详情 |
| GET | `/cost/warning/page` | `cost:warning:query` | 预警记录分页 |
| POST | `/cost/warning/push` | `cost:warning:push` | 测试推送，外网暂按全部推送 |

<a id="local-auth-api"></a>

## 2026-09-08 本地授权接口（当前源码）

依据后端 `9b0476ed`、前端 `4d5766a8`。下表为 Controller 相对路径；默认服务前缀 `/admin-api`，实际外部网关入口以环境配置为准。完整请求头及字段见 [字段契约](02-接口字段契约.md#local-auth-contract)，每个接口的样例见 [联调用例](03-接口联调用例.md#local-auth-cases)。

| 方法 | 路径 | 调用权限 | 用途 / 返回 data |
|---|---|---|---|
| GET | `/cost/role-assignment/page` | 管理员或独立授权专员；服务层 `requireManager` | 当前租户已有本地角色记录分页，包含撤销记录；`{list,total}` |
| GET | `/cost/role-assignment/scope-user-page` | 同上 | 本地角色非空的用户分页；`{list,total}` |
| GET | `/cost/role-assignment/lookup` | 同上 | 按名称或用户 ID 查找现有中台账号；`UserVO[]` |
| PUT | `/cost/role-assignment/assign` | 同上；不可改自己或任何管理员/专员 | 分配一个成本业务角色或显式撤销；`true` |
| GET | `/cost/access-scope/me` | 中台登录账号 | 查询自己的角色、范围及页面能力；`ProfileVO`。无成本授权也可返回未授权档案 |
| GET | `/cost/access-scope/profile` | 管理员或独立授权专员；Controller 与服务层双重检查 | 查询指定用户范围档案；`ProfileVO` |
| PUT | `/cost/access-scope/profile` | 同上 | 按当前角色整体替换范围；`true` |
| GET | `/cost/access-scope/options` | 同上 | 获取领域、项目或管理单位的编号/名称；对象数组，不返回成本金额 |

“管理员”指平台 `super_admin` 或 `tenant_admin`。“独立授权专员”指平台 `cost_role_allocator` 且有效成本业务角色为空；专员混配业务角色会被拒绝。四类业务角色本身均无授权管理权限。页面可见性不是接口鉴权依据。

角色接口禁止所有操作者修改自己的角色，也保护管理员及专员目标账号。范围接口中，专员不得操作自己、管理员或专员；管理员仍保留原范围管理能力，不套用专员的目标限制。

源码入口：[角色 Controller](../../../sqlbot_with_bcback/baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/controller/admin/accessscope/CostRoleAssignmentController.java)、[范围 Controller](../../../sqlbot_with_bcback/baback/yudao-module-cost/yudao-module-cost-biz/src/main/java/cn/iocoder/yudao/module/cost/controller/admin/accessscope/CostAccessScopeController.java)。上述接口不要求部署新 system 服务，也不直接写 DM。
