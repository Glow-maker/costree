# 内网账面筛选处理说明（2026-10-09）

## 已确认的代码缺陷

账面组成汇总与下拉选项使用相同的借方、工作令和权限过滤，但旧版 `selectFilterOptions` 额外对全部六类选项使用 `JOIN cost_project`。在未按领域、型号筛选时，汇总查询不要求该项目关联。因此存在可复现条件：有效账面与工作令已经导入、项目记录尚未匹配时，金额存在而六类下拉全部为空。

这确认了程序范围不一致，尚不能确认它是现场空下拉的唯一原因。此前截图只有请求头，未保存响应体、HTTP 状态或失败日志；旧诊断长时间运行也不等于接口本身一定超时。

## 修复范围

- 项目补充信息改为可选关联；项目编号来自账面，缺项目名称时展示编号。
- 项目、管理单位、核算单位和工作令不再仅因缺项目记录而从选项中消失。
- 领域和型号仍要求 `cost_project.domain_code/model_code` 真实存在；无数据不编造选项。
- 管理单位仍需核算编码能关联到启用的成本字典。账号权限、租户、工作令范围、金额计算均不放宽。
- 无新表、无新字段，此缺陷无需升级 SQL 或重建权限表。要使内网生效，需要包含本次修复的新 cost JAR；仅更新首页前端无效。

## 现场一次核查

1. 停止此前耗时十分钟的旧全量关联统计。在账面组成页清空手动筛选，再观察汇总和下拉；记录同一个账号、同一筛选范围。
2. 核实 schema 和 tenant 后，执行 [06 限量只读脚本](../20260923-intranet-diagnosis/06-filter-options-sample.sql) 的完整事务块：最多返回 20 条、10 秒超时、不写业务库。若超时，在同一会话单独执行 `ROLLBACK;` 后停止，不延长超时。
3. 按下表处理。样本结论只覆盖抽到的记录，不代表全库；无需再次运行全量 COUNT/GROUP BY。

| 抽样结果 | 处理方式 |
|---|---|
| `project_found=false` | 本次程序修复可恢复四类基础选项；领域/型号仍需核对账面项目编号与项目源映射，按权威源修正同步，不能凭名称填编码。 |
| `project_found=true`，`domain_found` 或 `model_found=false` | 确认该项目是否应有领域/型号，修复项目同步字段；不属于“新建表”的问题。 |
| `work_order_found=false` 或 `exact_unit_work_order_found=false` | 核对项目号、工作令号及单位名称映射；不能直接取消关联条件，否则可能改变账面口径。 |
| 仅 `eligible_work_order_found=false` | 记录匹配的是横向工作令，当前口径排除；不要为填满下拉擅自纳入。 |
| 全部通过但页面仍无选项 | 留存一条完成请求的 HTTP 状态、`code/msg/data` 和耗时；有 data 排查前端，空 data 排查实际租户/筛选/权限，错误或超时按错误日志/查询计划处理。无需提供 Authorization 头。 |
| 抽样也超时 | 转性能排查，先执行 [03 脚本 B 段](../20260923-intranet-diagnosis/03-lightweight-check.sql) 获取现有索引；不盲目追加索引或全量重同步。 |

## 验证与发布边界

源码修复完成，27 项定向测试通过（新增实际 SQL 6 项、已有服务 16 项、Mapper 5 项；失败/错误/跳过均为 0）。嵌入式 H2 加载实际 MyBatis Mapper 和生产租户拦截器，未启动服务或连接真实数据库。

- [修复前复现](before-fix-tests.log)：同范围账面 2 条、合计 3 万元，但原项目选项只有已关联的 1 个；缺项目记录的选项被排除。新增 6 项测试在旧 SQL 上为 5 个断言失败、1 个错误（空列表取首项），并非真实数据库故障。
- [修复后测试](targeted-tests.log)：六类选项、领域型号真实性、跨租户、项目与单位权限交集及空权限、日期阶段筛选、金额及明细数通过。
- 前端采用实际页面函数抽取和模拟 API 验证缺少领域/型号的项目仍能选择核算单位、工作令并保留 URL；这不是浏览器或内网端到端验收。
- `git diff --check` 通过。请求响应结构、业务汇总 SQL 均未修改；本轮没有数据库升级脚本。

测试命令（`baback` 根目录，`JAVA_HOME=H:/JDK`）：

```powershell
& 'H:/JDK/apache-maven-3.9.12/bin/mvn.cmd' -pl yudao-module-cost/yudao-module-cost-biz -am '-DskipTests=false' '-Dtest=CostWorkOrderLedgerFilterOptionsSqlTest,CostWorkOrderLedgerServiceImplTest,CostMapperAnnotationSqlTest' '-Dsurefire.failIfNoSpecifiedTests=false' test
```

本轮未提交、未构建发布 JAR、未部署服务器或内网、未生成新离线包。当前预览和既有离线包不会自动包含新的后端源码修改。H2 测试不替代 DWS/PG9.2 和大表性能验收；`GROUP BY/ORDER BY/LIMIT 50` 仍可能扫描大量数据。内网最终验收还需确认部署制品、六类选项、选择后的明细范围与金额，以及受限账号权限。
