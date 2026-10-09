# 云鲸「枢」2.2.1：成本数据全量快照＋差异更新

这是替换现有“删除成本表→全量拉取”的操作包。每次仍读取完整源快照，只向业务表新增缺少的记录、更新发生变化的外部字段；已有 `id`、人工填报、流程状态和引用保持不变。它不是按更新时间水位读取的增量抽取。

## 文件入口与使用边界

- `config.example.json`：复制为 `config.json`，填写现场 schema、租户和源映射确认项。
- `source-mapping.sql`：六个源的 SELECT 与目标列映射，唯一的源字段编辑区。
- `source-readiness.sql`：把占位 SELECT 改成上游六个数据集均发布完成的真实证据查询。
- `daily-runner.py`：推荐日常 SHELL 执行路径，动态生成批次、完整事务、失败返回非零退出码。
- `render-workflow.py`：SQL 多节点路径，按一次批次参数生成可复制 SQL。固定批次生成物不能第二天原样再用。
- `templates/`：经过静态核对的 SQL；不直接编辑，不直接将占位模板上线。
- `tests/`：隔离环境回归工具，详见其中说明；不指向业务 schema。
- `static-validation.json`：静态解析/禁写检查结果，不等于内网、PG9.2 或云鲸实机验收。

日常 runner 仅使用 Python 标准库；`validate-templates.py` 与 `runner-smoke.py` 是开发侧静态验证工具，另外需要 `pglast`，不作为内网日常执行依赖。

2026-10-09 未查到能够核验的云鲸「枢」2.2.1 官方公开操作手册。本指南只依据现场截图已经呈现的 SQL、SHELL 节点及串行连线能力，说明节点放什么、如何接；不假定它与 DolphinScheduler 全兼容，不提供臆造的菜单、任务参数语法或工作流导入 JSON。以下 SQL 事务规则依据 [PostgreSQL 9.2 事务文档](https://www.postgresql.org/docs/9.2/tutorial-transactions.html)，SHELL 调用方式依据 [psql 官方文档](https://www.postgresql.org/docs/9.2/app-psql.html)。

## 推荐：保留一个日常 SHELL 节点

工作节点须已有 Python 3、`psql`，并能以同一个 PostgreSQL 连接访问源镜像/已确认视图、中间 schema、业务 schema。本包不是新业务服务，不要求启动本地服务。数据库连接由该执行机的 `PGHOST/PGPORT/PGDATABASE/PGUSER` 或 `PGSERVICE` 提供；密码放权限受控的 `.pgpass`/既有凭据管理，不写进 SQL 或工作流命令。

1. 暂停旧定时流程，确认没有旧清空/同步实例仍在运行。另存当前工作流配置供追溯；不要让旧流程和新流程同时写成本表。
2. 把离线包中的整个 `05-workflow/` 目录复制到执行机并按示例命名为 `/opt/costree/workflow/`，保持其子目录不变。后续命令使用这个安装路径，不是包内原路径。它不依赖开发仓库；`build-delivery.py` 是开发生成器，离线包不包含它。
3. 按 `适配清单.md` 核对 `config.json`、源映射和上游完成判定。核对完成后才设置 `source_mapping_confirmed=true`。默认配置和默认完成判定都会拒绝生成/执行。
4. 先仅生成审阅文件，不连接数据库：

   ```bash
   python3 /opt/costree/workflow/daily-runner.py --config /opt/costree/workflow/config.json --out /opt/costree/workflow/runs
   ```

5. 首次在隔离环境验收通过、再到授权的上线窗口执行初始化和首批：

   ```bash
   python3 /opt/costree/workflow/daily-runner.py --config /opt/costree/workflow/config.json --out /opt/costree/workflow/runs --initialize --execute
   ```

   `--initialize` 只创建独立中间层及审计表，现有成本业务表结构须已经完成离线包的 DDL/升级。默认日常命令不初始化、不改业务表结构。

6. 在截图已有的工作流画布中，拖入/选择一个 SHELL 节点，使用以下命令；让它成为这条成本同步链的唯一执行节点，移除旧清空、复写与汇总节点的依赖连线。保存工作流后先手工触发一次，核对退出码和本批日志，再启用每天一次的单实例调度。截图未证明具体调度字段名称，以现场实际配置项为准。

   ```bash
   python3 /opt/costree/workflow/daily-runner.py --config /opt/costree/workflow/config.json --out /opt/costree/workflow/runs --execute
   ```

日常运行无需人工修改 `batch_code`、`snapshot_tag`、`expected_rows`：runner 自动生成 UUID 批次，源行数在同一 `REPEATABLE READ` 事务内按同一源 SELECT 计算，再核对实际装载量。六源装载、业务差异更新、全部年度借方账面重算、人工字段比对、缺失差异报告全部在一次 `psql` 连接/事务内执行。真实上游 `source-readiness.sql.snapshot_tag` 记录到 `batch_register.snapshot_tag`；`load_receipt.snapshot_tag` 中 `DBTX-...` 只是本次数据库一致读取标识，不能冒充上游发布完成证据。

同一数据库读取快照不代表跨数据库上游已完成发布。若源在不同数据库，必须先发布到能由同一连接读取的稳定镜像/视图，并由 `source-readiness.sql` 检查完整发布标记；不能把六个源各自“成功过一次”当作同一快照。不要简单将完成判定写成恒真。

## 旧截图十个节点如何处理

| 旧节点 | 推荐 SHELL 路径 | 保留 SQL 节点时的替代 |
|---|---|---|
| 树节点接入 | 合并进 daily-runner | `21-load-stg_model_node.sql`，只装中间表 |
| 树节点更新 | 禁用旧业务更新 | 移除旧更新 SQL；树写入并入最终 90 |
| 项目卡片接入 | 合并进 daily-runner | `22-load-stg_project.sql`，只装中间表 |
| 项目卡片更新 | 禁用旧业务更新 | 移除旧更新 SQL；项目写入并入最终 90 |
| 单位字典更新 | 合并进 daily-runner | `23-load-stg_unit_dict.sql`，只装中间表 |
| 同步单位成本 | 合并进 daily-runner | `24-load-stg_unit_amount.sql`，不写人工目标/审定 |
| 项目工作令 | 合并进 daily-runner | `25-load-stg_work_order.sql`，不覆盖单位填报 |
| 项目工作令明细 | 合并进 daily-runner | `26-load-stg_ledger_detail.sql`，借/贷都装载 |
| 复写工作令数据（截断） | **禁用并断开旧节点** | 禁止 TRUNCATE/DELETE 真实工作令表；逻辑并入 90 |
| 汇总计算 | 禁用旧独立重算 | `90-atomic-sync.sql` 内统一重算并验收，不能脱离同一事务 |

上述操作禁用的是旧执行链，不要求删除历史工作流配置。旧 `integration/10-sync-to-cost.sql`、旧 `manual/04、05` 以及清空真实业务表的 SQL 不进入日常运行目录。

## 可选：按截图保留 SQL 节点

适用前提：源快照在整个装载期间不可变；每个 SQL 节点支持同连接执行整段 SQL（含 `BEGIN/COMMIT`、`DO $$`、临时表）；任一节点失败后下游停止。必须先用隔离事务探针实测，不依据外观推断这些能力。

1. `config.json` 额外填写本批唯一 `batch_code`、经确认的同一 `snapshot_tag`、六张源完整行数 `expected_rows`。
2. 运行 `python3 /opt/costree/workflow/render-workflow.py --config /opt/costree/workflow/config.json --out /opt/costree/workflow/generated/本批唯一目录`。生成器只写文件。
3. 一次性执行生成的 `00-setup.sql`。画布新增“开始批次”SQL 节点填入 `10-begin-batch.sql`。
4. 按截图拖入/保留 SQL 节点，用上表替换内容，串行连线：`10 → 21 → 22 → 23 → 24 → 25 → 26 → 90 → 95`。所有节点选同一目标库连接；schema 由已生成 SQL 明确指定。
5. 最后的 `90` 必须整体放在一个节点、一条连接，不能拆成多个各自提交的业务更新和汇总节点。`95` 只读输出源缺失差异。
6. 若要自动按日跑此 SQL 版本，需在现场确认平台的运行参数传递方式，将下表映射到每个节点。2.2.1 的参数语法未核实，本包不猜测 `${...}`；未完成参数映射前只做一次性人工批次，日常用推荐 SHELL 路径。

| 参数 | 所有节点必须满足 |
|---|---|
| business_schema / stage_schema / tenant_id | 指向同一已核验目标，固定部署参数 |
| batch_code | 一次运行唯一，六源和最终节点完全相同，不能复用昨天的值 |
| snapshot_tag | 同一完整、冻结的源发布批次，不能取各节点自己的开始时间 |
| expected_rows 六项 | 按本批对应源 SELECT 统计，空基础字典/树/项目不接受 |

## 失败、重跑与完整性

- 日常 runner 在 COMMIT 前 SQL 报错会返回非零，整笔业务变更回滚；没有更新时间水位推进。阶段中的 `BUSINESS_SYNCED`、`RECALCULATED` 与最终 `SUCCESS` 都只在最终提交后可见，不能靠中间打印信息判成功。若恰在提交时断连，先按本批 `batch_code` 查询控制记录确认是否已为 `SUCCESS`，不要凭客户端断连认定未提交。
- SQL 多节点路径前六步只提交中间表。90 在提交前报错时业务整体回滚，状态仍为 `LOADING`。若只是锁等待等临时故障，确认状态为 `LOADING` 且中间快照完整未变，可修复运行环境后重跑同批 90。若修改了源数据或映射，不能只重跑 90，它仍读取原中间快照；应先停调度和所有节点，执行对应批次的 `99-manual-abort.sql`，再以新批次重新装载。已成功装载的源节点不可追加再跑；99 不能挂成自动失败处理。
- 运行结果与 SQL 保存在 `runs/唯一批次/`。缺失差异报告只是“业务存在、这次源中没出现”的线索，**不是完整性证明，也不执行删除**。
- 任意源 `source_deleted` 真值默认整批拒绝。需要删除语义时另行确认撤销/冲销规则，不能把未拉到的数据自动软删。现有 `deleted=1` 的业务记录不会被此流程恢复。
- 同名历史异码若落同一个项目单位/工作令目标，会报错阻断。应由业务/数据责任人确定稳定源记录映射，不能简单 `SUM/MAX/DISTINCT` 名称去重，也不能换一个 ID 继续插。
- 最终事务先锁业务表，再采集人工字段基线；查询可以继续，填报写入会等待锁释放。安排在低峰执行。SQL 序列和 Java 雪花 ID 混用时，锁内仅把正向非循环序列向上提升到已有最大 ID，绝不改旧 ID/向下重置；序列提升本身不随失败回滚，只可能留空号。
- 账面按稳定源明细 ID 幂等落库，原币元金额是计算依据，先累计借方元再换万元，不逐行按两位万元累计；收益率公式未修改。
- 中间层按批次保留快照，`runs/` 保留运行文件，本版没有自动过期清理。上线前核算每日快照容量并确定保留期；后续只清已经核验、无需追溯的旧成功批次及其文件，不清运行中的批次，更不能重新接回清空业务表的任务。

## SQL 节点事务探针

在独立测试库/测试 schema 创建一张专用 `workflow_tx_probe(id int primary key)`，不要借用业务表。让测试 SQL 节点同一段执行：`BEGIN; INSERT INTO 测试schema.workflow_tx_probe VALUES (1); SELECT 1/0; COMMIT;`。节点应失败；另一个只读查询节点/客户端检查记录数必须为 0，下游哨兵节点不得执行。再以临时表写入/读回和 `pg_backend_pid()` 检查同一 SQL 节点没有分配不同连接。探针失败则不用 SQL 多节点路径，改用已验证的 `psql -X -v ON_ERROR_STOP=1 -f` 单连接 SHELL 路径。

隔离测试通过仍需在现场确认源字段、历史编码、工作节点驱动、权限、源发布语义和代表性金额后，才可开始业务试运行。
