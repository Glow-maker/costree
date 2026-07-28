# PostgreSQL 9.2.4 / GaussDB(DWS) 8.2.1 兼容说明

## 1. 适配范围

本包为原生 PostgreSQL 9.2.x 和 GaussDB(DWS) 8.2.1 提供同一专用目录。脚本会检查 `version()` 自动切换索引策略，不再把 DWS 当成原生 PostgreSQL 处理。

```text
database/postgresql92/
  01-new-database/       空库完整建表
  02-upgrade-existing/   旧成本库一次升级与核验
  03-data-integration/   正式外部数据暂存、同步和对账
  91-optional-demo/      可选闭环演示，仅测试环境使用
```

后端 JAR、前端资源和 JDBC URL 格式不变。当前项目使用 PostgreSQL JDBC `42.3.8`，连接仍写为：

```yaml
url: jdbc:postgresql://数据库地址:5432/数据库名
username: 数据库用户
password: 数据库密码
driver-class-name: org.postgresql.Driver
```

## 2. DWS 已处理的差异

专用脚本已经处理以下差异：

- 不使用 `ON CONFLICT`、`ADD COLUMN IF NOT EXISTS`、`CREATE INDEX IF NOT EXISTS` 和聚合 `FILTER`。
- DWS 分布表不能创建不包含分布键的唯一索引，因此三个业务键在 DWS 使用同名普通防重索引；每次同步会串行加锁，并在写入前后检查重复键。
- 暂存表不再声明跨分布键二级 `UNIQUE` 约束，而是在同步事务中强校验源数据重复。
- CSV 装载使用 9.2/DWS 均支持的 `\copy ... WITH CSV HEADER`。
- 一键脚本自动优先使用 DWS 官方 `gsql`，找不到才回退 `psql`。

参考华为云官方文档：

- DWS 表设计和唯一约束的分布键要求：<https://support.huaweicloud.com/devg-dws/dws_04_0028.html>
- DWS 8.2.1 不应使用 9.1.0 才支持的 `CREATE INDEX IF NOT EXISTS`：<https://support.huaweicloud.com/intl/en-us/sqlreference-dws/dws_06_0165.html>
- `gsql` 参数和 `\copy` 导入：<https://support.huaweicloud.com/intl/en-us/tg-dws/dws_gsql_006.html>、<https://support.huaweicloud.com/intl/en-us/migration-dws/dws_15_0042.html>

不要手工搜索替换 SQL，也不要把 `database/postgresql` 与 `database/postgresql92` 中的文件交叉组合。

## 3. 已有内网库推荐步骤

```powershell
# 先在 SQL 客户端执行 00-dws-precheck.sql，结果应识别为 GaussDB(DWS)

cd .\database\postgresql92\02-upgrade-existing
$env:PGHOST='数据库地址'
$env:PGPORT='5432'
$env:PGUSER='数据库用户'
$env:PGPASSWORD='数据库密码'
$env:PGDATABASE='成本库名'
.\run-upgrade.ps1 -Client gsql
```

升级成功后，再使用 `database/postgresql92/03-data-integration` 导入正式数据。完整链路与 14+ 一致：源数据进入暂存表，整批校验，幂等同步业务表，最后对账。

## 4. 演示验证

测试环境可按以下顺序执行：

```text
database/postgresql92/91-optional-demo/source-chain/00-create-source-schema.sql
database/postgresql92/91-optional-demo/source-chain/01-seed-two-projects.sql
database/postgresql92/91-optional-demo/source-chain/02-sync-to-cost.sql
database/postgresql92/91-optional-demo/source-chain/03-verify.sql
```

禁止在正式真实数据环境执行演示或清理脚本。

## 5. 验证边界

本套脚本已在原生 PostgreSQL `9.2.23` 实例上执行验证：

- 空库完整建表成功。
- 旧库预检查、升级、结构核验成功，18 项核验全部通过。
- 两项目演示同步成功：2 个项目、14 条项目单位金额、13 条逻辑工作令、22 条账面明细。
- 借方账面合计 11,800 万元，2 条贷方明细保留但未进入账面汇总。
- 正式暂存同步脚本连续执行两次，记录数和金额不增加。

本包已完成原生 PostgreSQL 9.2.23 回归和 DWS 8.2.1 语法/分布键兼容改造；当前开发环境没有 DWS 集群，因此正式上线前仍必须在内网实例完成：

解压后可先运行 `database/postgresql92/02-upgrade-existing/verify-dws82-compatibility.ps1`，确认包内 SQL 没有混入高版本语法。

1. 使用 `gsql` 执行 `02-upgrade-existing/00-dws-precheck.sql` 和 `00-precheck.sql`，确认引擎识别、缺表和重复业务键结果。
2. 在备份后的测试 schema 或测试库执行完整升级脚本。
3. 用两个真实型号执行 `03-data-integration`，再运行 `20-verify-sync.sql` 和 `30-diagnose-book-zero.sql`。
4. 确认借贷方向原值为“借/贷”，`gzlnm` 能对应工作令源主键，账面金额由元正确换算为万元。
5. 若标准 PostgreSQL JDBC 在认证或类型处理上出现差异，改用与内网 DWS 版本配套的官方 JDBC 驱动。

## 6. DWS 运行纪律

- 同一时刻只能运行一个 `10-sync-to-cost.sql`，不得并发启动多个导入工作流。
- 外部数据必须先进入 `cost_integration`，不得绕过校验直接批量 INSERT 到业务表。
- `20-verify.sql` 和 `20-verify-sync.sql` 任一错误计数不为 0，都不能启动后端。
- DWS 上看到 `uk_cost_*` 为 `NON_UNIQUE` 是设计结果，不要手工改成违反分布键规则的唯一索引。

## 7. 安全边界

PostgreSQL 9.2 已停止官方安全维护。本适配解决的是应用和 SQL 兼容，不代表数据库版本仍安全。内网部署至少应做到：

- 数据库不对非必要网段开放。
- 使用成本服务专用数据库账号，不使用超级用户运行应用。
- 上线前完整备份，上线后定期备份并验证恢复。
- 制定迁移到受支持 PostgreSQL 版本的时间表。
