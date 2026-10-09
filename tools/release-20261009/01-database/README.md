# 成本 PostgreSQL / DWS 升级入口

仅适用于 cost 实际连接的 PostgreSQL / GaussDB(DWS) schema；不适用于 MySQL、DM 或 system。

| 文件 | 作用 |
|---|---|
| 00-identify-schema.sql | 只读确认连接和成本表位置 |
| sql-parameters.html | 离线生成指定 schema / 租户的 SQL 副本 |
| 01-full-upgrade.sql | 完整升级；按实际结构补缺表、缺列、索引，再进行受版本保护的数据迁移和检查 |
| 02-backup-create-missing-tables.sql | 备用；只创建不存在的当前结构表及依赖序列、约束、注释，已有表整体跳过 |
| 03-verify-structure.sql | 只读核对 20 张表及授权关键列 |
| 05-reporting-name-width.sql | 增量扩展类别/平台字段至255，仅适用于其他升级已完成的库 |
| 04-optional-revision-only.sql | 可选；仅为已完成其余升级且已有锁表的库补 revision，不创建缺表 |

**0914 完整升级已完成：仅 03；0910/0911 其余结构完整且仅字段宽度不足：05 → 03；结构不完整：01 → 03。** 01 已含备用补表能力，不必先跑 02。备用 02 不会修正已存在表的缺列；老 cost_auth_user_lock 缺 revision 必须执行 01 或在满足条件时执行 04。

本次 SQL 与 20260914 版本字节一致，没有新结构变更；SHA256.json 保留同一组哈希。两列长度修复已在 0914 交付。生成器只替换 search_path 和完整升级中唯一的目标租户检查，不替换其他业务数字。生成后的副本哈希自然不同。直接使用原始 SQL 时，必须手工核实默认 public 和租户 124 是否匹配现场。

完整升级和备用覆盖当前 20 张成本表，包含 cost_user_role、cost_user_role_action、cost_auth_user_lock，以及项目 / 单位 / 领域授权范围表。结构补齐不受 migration 版本号影响。备用创建空表，不能恢复丢失的授权数据；误删表的数据仍需备份恢复。

停止写入、备份、启用遇错停止后整份执行，确认 COMMIT 成功。不要清 migration，不要从错误之后跳行继续。完整升级保留历史业务迁移保护，不会强行修正无法安全判定的现有错误约束或编造业务值。

本次保留旧收益率公式，仅业务名称更名。id=NULL 修复在新后端 ASSIGN_ID 中，SQL 不能修复旧 JAR 显式插入 NULL。新前端保存范围必须带 scopeRevision，旧前端不能与新 JAR 混用。

local-validation.json 是独立 PG9.2.23 / PG17.9 脚本测试，不代表 DWS。04-evidence/local-acceptance 是历史本地记录，不代表本次最终包验收；最新边界见 04-evidence/20260923-review.md。
