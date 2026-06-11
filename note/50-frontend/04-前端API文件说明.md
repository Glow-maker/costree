# 前端 API 文件说明

状态：进行中

## 目标

设计 `src/api/cost/...` 下的 TypeScript API 文件结构。

## 前端仓库

`H:\light\project\sqlbot_with_bcback\costree-frontend`

## API 文件草案

| 文件 | 用途 |
|---|---|
| `H:\light\project\sqlbot_with_bcback\costree-frontend\src\api\cost\modelNode\index.ts` | 型号树 |
| `H:\light\project\sqlbot_with_bcback\costree-frontend\src\api\cost\project\index.ts` | 成本项目 |
| `H:\light\project\sqlbot_with_bcback\costree-frontend\src\api\cost\projectBasic\index.ts` | 项目基本情况，原型 `Table 2` |
| `H:\light\project\sqlbot_with_bcback\costree-frontend\src\api\cost\workOrder\index.ts` | 工作令基础信息，原型 `Table 3` |
| `H:\light\project\sqlbot_with_bcback\costree-frontend\src\api\cost\warning\index.ts` | 预警 |

## 2026-05-17 已落地 API

| 文件 | 已实现方法 | 后端接口 |
|---|---|---|
| `src\api\cost\projectBasic\index.ts` | `getProjectBasicPage`、`exportProjectBasic`、`getProjectBasicImportTemplate` | `/cost/project-basic/page`、`/cost/project-basic/export-excel`、`/cost/project-basic/get-import-template` |
| `src\api\cost\workOrder\index.ts` | `getWorkOrderPage`、`exportWorkOrder`、`getWorkOrderImportTemplate` | `/cost/work-order/page`、`/cost/work-order/export-excel`、`/cost/work-order/get-import-template` |
| `src\api\cost\importResult.ts` | `CostImportResultVO`、`CostImportErrorVO` 类型 | 项目基本情况和工作令导入接口共用返回结构 |

说明：前端 API 文件中写 Controller 内部路径 `/cost/...`，运行时由 `VITE_API_URL=/admin-api` 形成实际访问路径 `/admin-api/cost/...`。
