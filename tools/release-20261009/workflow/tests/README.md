# 隔离验收：真实同步模板

本测试调用交付的 `templates/00、10、21–26、90、99` 文件，不另写一套同步算法。测试只向本次新建的 `costree_workflow_audit_*_biz` / `*_stage` 两个 schema 装入小型合成数据。目标数据库可以是已有 PostgreSQL 实例上的专用验收库；禁止指向内网业务 schema，禁止从业务库复制数据。

以下第一组路径用于源码仓库。**在离线包根目录运行时，使用 `tests = Path("05-workflow/tests")`，输出目录改成自选的 `audit-runs/your-run`**；Python 文件、DDL 和同级模板均在包内，无需后端源码仓库。不要改这些相对目录之间的关系。

`fixture-schema.sql` 的建表及序列定义摘自后端 `sql/postgresql92/costree-cost.sql`。测试没有启动应用、数据库或 Docker 服务。它验证 SQL 在所连接 PostgreSQL 版本上的行为；**不等于已通过真实 DWS、PG9.2、云鲸 2.2.1 节点和上游快照完整性验收**。

## 本地语法检查

```powershell
python -m py_compile tools/release-20261009/workflow/tests/run_isolated.py tools/release-20261009/workflow/tests/remote_psql.py
```

## 连接已有数据库运行

先只读确认服务器身份和目标数据库。`run_isolated.py` 会检查两个 schema 都不存在，再创建；已有同名 schema 时停止，绝不覆盖。

在项目根目录，用 Python 构造参数数组可避免 Windows 命令行 JSON 引号问题：

```python
import json, subprocess, sys
from pathlib import Path

tests = Path("tools/release-20261009/workflow/tests")
# 使用现有 psql。密码经 PGPASSFILE 等既有凭据机制提供，不写进参数或日志。
psql = ["psql", "-h", "YOUR_AUDIT_HOST", "-U", "YOUR_AUDIT_USER", "-d", "YOUR_AUDIT_DATABASE"]
subprocess.run([
    sys.executable, str(tests / "run_isolated.py"), "--execute", "--cleanup",
    "--output", "note/70-testing/20261009-offline-release/workflow-isolated/your-run",
    "--psql-command-json", json.dumps(psql),
], check=True)
```

若需复用已运行的远程 PostgreSQL 容器，将 `psql` 替换为下面的 argv。该代理只执行 `ssh → docker exec → psql`，不启动任何服务，也不输出容器凭据：

```python
psql = [sys.executable, str(tests / "remote_psql.py"),
        "--host", "YOUR_SSH_HOST", "--container", "YOUR_EXISTING_PG_CONTAINER",
        "--database", "YOUR_AUDIT_DATABASE"]
```

## 验证内容与证据

- 首次导入、相同快照重放：原 ID 与行数不变。
- 项目基本情况整行、项目填报/审定状态、单位目标/审定/备注与成本字段、工作令人工金额和状态保持原值。
- 源负责的名称/合同到款发生变更及新增工作令/账面明细；旧记录 ID 保持。
- 同名历史单位异码归一冲突、稳定源 ID 与目标逻辑键冲突、串批和未批准的源删除均整批拒绝。
- 业务后半程 SQL 故障：此前业务写入及同步控制状态均回滚。
- Java 手工大 ID 高于数据库序列时仅向上推进；失败事务后序列不倒退（允许空号）。缺席快照的软删除行不复活。
- 实际 `DEFAULT nextval(...)` 与旧的 `OWNED BY` 不一致时，只提升实际默认序列，旧关联序列不变；源匹配到软删除目标时拒绝，不能复活。
- 三笔各 60 元的借方先合计 180 元再转万元，结果为 0.02；贷方不计入该借方账面回写。

输出目录保留每一步的 SQL、stdout、stderr、`result.json`（数据库版本、模板 SHA256、用例结果）、本次双 schema 的精确清理 SQL。`--cleanup` 只清理由本次运行创建的这两个 schema。预期拒绝的 SQL 日志包含 ERROR 属于用例通过条件；其他错误使脚本非零退出。

## 日常 SHELL 路径专项

把执行入口改为 `tests / "run_daily_isolated.py"`，其余参数相同。它额外新建同前缀的 `*_src` 合成源 schema，以交付的真实 `source-mapping.sql` 和 `daily-runner.py` 生成并执行 `daily-atomic.sql` 两次，验证不同动态批次、真实发布标签写入 `batch_register`、全部被保护字段/ID 不变和元→万元精度。随后将合成发布状态改为 false，验证整段日常事务拒绝且业务和同步控制状态不变。此专项三 schema 同样仅由本次创建，`--cleanup` 只删除这些新资源。

测试用 `99` 明确终止自身失败批次，以便继续下一合成用例。它不是生产环境自动清错或自动重试方案。生产失败必须按交付说明确认原因和快照，再决定重试/终止。
