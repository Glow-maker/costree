# 20261009 成本树离线交付记录

完整包：`cost-server-offline-package-20261009.zip`，209,871,987 字节（约 210 MB）。

SHA256：`51d368b2e699c2e133b938e4fa67ca3fa11fa3331f23d160a5612ab239af5838`。

| 对象 | 固定提交与结果 |
|---|---|
| 后端 | `82619751f3a4f9eb0e2a4eba864cdfc0d1d86045`，已推送 `codeup/feature/costree`；Linux Java 8 构建，130/130 通过 |
| 前端 | `2a6a0d3802a1c032f67888fcd9c3dc868234c55c`，已推送 `codeup/feature/costree2`；用户批准 Windows 纯构建，61/61、成本类型检查通过 |
| 同步工作流 | PG17.11 合成隔离：核心15 + 日常5通过，13个审计schema已清理 |
| 包校验 | ZIP CRC、1937文件SHA256、17实体ASSIGN_ID/Java8/授权revision/筛选修复标记通过 |
| SQL参数页 | 5份模板一致、schema/tenant替换正确、5个非法输入拒绝 |

## 交付内容

- `03-app`：新成本JAR、前端ZIP、配置外置说明。后端单独压缩包已下载到 `.preview/release-20261009/server-artifacts/backend-package.zip`。
- `01-database`：完整升级、仅建缺表备用、结构核验、参数生成器；本次应用修复无新增业务DDL。
- `05-workflow`：云鲸操作指南、旧十节点替代关系、3个现场适配文件、11份SQL模板、日常Python/psql执行器及隔离回归工具。
- `04-evidence`：实际构建/回归/清理证据，包含Linux前端失败尝试，不将其标为成功。

## 工作流口径

每次读取完整源快照，向业务表做差异UPDATE/INSERT；不删除重建业务数据，不按更新时间水位抽取。
`cost_project_basic` 已独立存放项目填报，整表不写；单位/工作令的混合字段通过白名单保护人工输入，没有新增业务影子表或强行迁移已有填报。
已有ID、填报状态、备注及人工目标/审定等保留；源缺失仅报告。稳定源ID/同名历史异码冲突会阻断，不盲目按名称累加。
最终业务更新、借方元金额重算及人工字段验收在同一事务内；收益率公式不改。
按 `05-workflow/适配清单.md` 编辑参数、六源SELECT和真实完成判定。默认占位配置会拒绝执行。

## 验证边界与环境处理

前端Linux共享主机内存不足，3次尝试分别OOM/交换迟滞中止；用户随后批准Windows本机只构建，不启动服务。交付的前端是本次新构建，不是历史ZIP。
后端base首次Excel测试因缺字体报7项错误；仅在隔离构建目录解包字体/fontconfig后完整重跑130项，无跳过、无业务源码改动、无系统安装。运行环境的字体要求见包内03-app说明。
JAR仅移除开发profile并外置2个敏感配置键，616个非配置条目与原始Linux产物字节一致；现场继续使用原外置配置和密钥。
主机2专用swap已删除、zswap恢复，4个服务PID不变；base 15个既有Java进程不变。没有部署新JAR/前端，没有真实业务库修改。
真实DWS/PG9.2、云鲸2.2.1实际调度、源发布完整性、字段映射、历史编码、容量保留期、权限及代表性金额仍须现场验证；本记录不能替代现场验收。

证据入口：[构建清单](build-manifest.json)、[包校验](package-verification.json)、[工作流20项验证](workflow-isolated/verification-summary.json)。
