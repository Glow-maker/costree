# SQL 历史归档

2026-10-13 从共享后端移出旧同步、清库、演示脚本及历史打包工具，共 68 个文件，其中 36 份 SQL。

| 目录 | 内容 |
| --- | --- |
| `backend/sql/jt/` | 旧集成流程、演示数据、重置脚本、打包工具和重复脚本 |
| `maintenance/tools/` | 旧通用离线打包入口 |

[manifest.json](manifest.json) 记录原路径、归档路径、文件大小及 SHA256。归档文件保留原内容，内部命令和链接仅供历史参考，不作为当前执行入口。

当前基线、正式迁移、校验及测试依赖保留在后端 `sql/jt/`，入口为 `sql/jt/README.md`。PG14 预警迁移以 `postgresql/costree-deploy/15-upgrade-existing-to-20260820-warning-workflow.sql` 为准，根目录的同内容副本已归档。

恢复历史流程时需同时核对对应版本和依赖。已交付离线包保持原样。
