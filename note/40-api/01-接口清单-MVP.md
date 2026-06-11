# 接口清单 - MVP

状态：初稿

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
