# 06-内网原表-主业项目树 ads_lc_lshsxm2022

状态：原表字段整理草案
更新时间：2026-06-21
来源：用户提供的内网截图，字段以数据库 `COMMENT ON COLUMN` 为准，后续需用正式 DDL 和样例数据复核。

交接总览：先读 `09-成本库内网数据对接总设计方案.md`，再按本文核对主业项目树字段和映射细节。

## 1. 表定位

原表：

```text
schema: sc_8001_cw
table : ads_lc_lshsxm2022
comment: 分析层项目
```

业务口径：

- 该表是内网“主业项目树”对应的原始项目层级表。
- 目前截图中可见字段全部为 `varchar(255)`，包括主键、项目编号、层级、状态、禁用日期等。
- 表名带 `2022` 后缀，可能是年度版本、历史模型或固定同步批次命名【需确认】。
- 成本库不应让前端直接依赖此表字段名，推荐先作为源表/原表镜像承接，再解析生成 `cost_model_node` 和 `cost_project`。

## 2. 字段清单

以下字段来自截图中可读的字段注释。

| 原字段 | 注释 | 类型 | 初步理解 | 备注 |
|---|---|---|---|---|
| `lshsxm_id` | 主键 | `varchar(255)` | 原表行主键 | 可作为原表唯一键；是否稳定需确认 |
| `lshsxm_xmnm` | 项目内码 | `varchar(255)` | 项目节点内码 | 推荐作为成本库 `source_project_id` 的首选来源 |
| `lshsxm_xmbh` | 项目编号 | `varchar(255)` | 主业项目编号/核算项目编号 | 推荐映射到 `project_code` |
| `lshsxm_xmmc` | 项目名称 | `varchar(255)` | 主业项目名称/节点名称 | 推荐映射到 `project_name` 或展示节点名称 |
| `lshsxm_js` | 级数 | `varchar(255)` | 树层级 | 推荐转数值后映射到 `level_no` |
| `lshsxm_mx` | 明细 | `varchar(255)` | 是否明细节点/叶子节点标识 | 需样例确认取值，如 `0/1`、`是/否` |
| `lshsxm_dwbh` | 单位编号 | `varchar(255)` | 项目关联单位编号 | 可用于匹配单位字典或项目归属单位 |
| `lshsxm_fjnm` | 父级内码 | `varchar(255)` | 父节点内码 | 候选 `parent_source_id` |
| `lshsxm_xmlx` | 项目类型 | `varchar(255)` | 源项目类型 | 可能用于项目类别/系列判断，需样例确认 |
| `parent_xmnm` | 上级项目内码 | `varchar(255)` | 上级项目内码 | 候选 `parent_source_id`，需和 `lshsxm_fjnm` 对比 |
| `lshsxm_ms` | 是否免税 | `varchar(255)` | 免税标识 | 成本树展示暂不用，保留源字段 |
| `seclevel` | 密级 | `varchar(255)` | 密级 | 可能影响权限或展示脱敏，当前先保留 |
| `lshsxm_zt` | 状态 | `varchar(255)` | 源状态 | 可辅助生成 `status`，需确认有效/停用取值 |
| `nfjm` | 新父级码 | `varchar(255)` | 新版父级编码 | 与 `lshsxm_fjnm`、`nparent_xmnm` 关系需确认 |
| `nxmnm` | 新核算编码 | `varchar(255)` | 新核算项目编码 | 可能是新口径项目内码/编号，需确认 |
| `disabled` | 禁用状态 | `varchar(255)` | 是否禁用 | 可辅助生成 `status=DISABLE` |
| `nparent_xmnm` | 新上级编码 | `varchar(255)` | 新上级项目编码 | 新口径父节点字段，需确认是否优先于 `parent_xmnm` |
| `jyrq` | 禁用日期 | `varchar(255)` | 禁用日期 | 原表为字符型，使用前需解析日期格式 |
| `wglx` | 完工类型 | `varchar(255)` | 项目完工类型 | 成本树展示暂不用，保留源字段 |
| `xmsx` | 项目属性 | `varchar(255)` | 项目属性 | 可能影响项目分类，需样例确认 |

## 3. 当前能直接确认的树关系

从字段名和注释看，该表至少具备构造树的三个关键能力：

| 能力 | 可用字段 | 说明 |
|---|---|---|
| 节点唯一标识 | `lshsxm_xmnm`，以及原表主键 `lshsxm_id` | 推荐优先用 `lshsxm_xmnm` 作为业务节点 ID，`lshsxm_id` 保留为原表行 ID |
| 父子关系 | `lshsxm_fjnm`、`parent_xmnm`、`nfjm`、`nparent_xmnm` | 哪个字段才是内网当前有效父节点，需要用样例数据确认 |
| 层级判断 | `lshsxm_js`、`lshsxm_mx` | 可判断第几级、是否叶子/明细节点 |

当前不能直接确认：

- 哪一级是成本库“领域”。
- 哪一级是成本库“系列/类别”。
- 哪一级是成本库“型号项目”。
- `lshsxm_xmlx` 是否等同“主业项目所属类别”。
- 是否存在独立“所属领域”字段；截图中该原表未看到直接字段。

因此不能简单把 `lshsxm_js=1/2/3` 直接写死为 `DOMAIN/SERIES/MODEL`，必须先看样例数据。

## 4. 与成本库源表的初步映射

当前成本库文档里已有 `cost_source_project_tree` 作为源主业项目树承接表。若继续使用该表，可先按以下方式映射。

| `ads_lc_lshsxm2022` | `cost_source_project_tree` | 规则 |
|---|---|---|
| `lshsxm_xmnm` | `source_project_id` | 首选；用于稳定追踪源项目节点 |
| `lshsxm_xmbh` | `project_code` | 主业项目编号；为空时需进入未解析清单 |
| `lshsxm_xmmc` | `project_name` | 项目/节点名称 |
| `lshsxm_xmlx` | `project_category` | 暂作为源项目类型/类别；是否等同成本库“系列”待确认 |
| 暂无明确字段 | `domain_code` / `domain_name` | 不能直接映射；需从顶层节点、项目类型、父路径或外部映射表生成 |
| `parent_xmnm` 或 `lshsxm_fjnm` | `parent_source_id` | 需样例数据确认哪个字段更稳定 |
| 可由父链拼出 | `parent_path` | 导入后通过递归父节点生成 |
| `lshsxm_js` | `level_no` | 字符转整数；不能转换时进异常清单 |
| 暂无可见最后修改字段 | `source_lastmodify` | 如果原表 DDL 有更新时间字段再补；否则无法做可靠增量 |
| `lshsxm_dwbh` | `custom_01` 或新增 `source_unit_code` | 当前 `cost_source_project_tree` 没有单位编号字段，先保留 |
| `lshsxm_mx` | `custom_02` | 保留明细标识 |
| `lshsxm_ms` | `custom_03` | 保留是否免税 |
| `seclevel` | `custom_04` | 保留密级 |
| `lshsxm_zt` | `custom_05` | 保留源状态 |
| `disabled` | `custom_06` / 派生 `status` | 可用于后续生成展示节点状态 |
| `jyrq` | `custom_07` | 保留禁用日期原值 |
| `wglx` | `custom_08` | 保留完工类型 |
| `xmsx` | `custom_09` | 保留项目属性 |
| `nfjm`、`nxmnm`、`nparent_xmnm` | `custom_10` 或扩展字段 | 三个字段同时塞入一个 custom 不利于维护，正式建议扩展源表字段 |

## 5. 推荐承接方式

### 5.1 首轮验证

首轮内网验证可以先做一张原表镜像，字段保持与原表一致，全部 `varchar(255)`：

```text
cost_source_ads_lc_lshsxm2022
```

用途：

- 原样保存内网原表，便于和 DBA/业务方核对。
- 不丢失 `nfjm`、`nxmnm`、`nparent_xmnm` 等当前成本库源表没有的字段。
- 后续用 SQL 或解析任务写入标准化的 `cost_source_project_tree`。

### 5.2 正式维护

正式建议使用“两段式”：

```text
ads_lc_lshsxm2022 原表/镜像
  -> cost_source_project_tree 标准源项目树
  -> cost_model_node 展示树
  -> cost_project 成本项目锚点
```

这样做的原因：

- 原表字段名和类型完全按内网系统走，成本库不直接耦合。
- `cost_source_project_tree` 负责变成成本库能理解的标准源树。
- `cost_model_node` 只负责前端目录树展示，不保存所有原始业务字段。
- `cost_project` 只保存成本库项目锚点，不承载整棵源树。

## 6. 解析到成本库展示树的初步规则

待拿到样例数据后，建议按以下顺序判定：

1. 用 `lshsxm_xmnm` 建立节点表。
2. 用 `parent_xmnm` 和 `lshsxm_fjnm` 分别跑一次父子关系校验，比较哪一组能形成完整树。
3. 用 `lshsxm_js` 统计每级节点数量和示例名称。
4. 用 `lshsxm_mx` 判断叶子节点是否为成本库“型号项目”候选。
5. 检查 `lshsxm_xmlx`、`xmsx` 是否能稳定表示项目类别/系列。
6. 如果没有直接“所属领域”字段，从一级或二级节点名称映射出成本库 `domain_code/domain_name`。
7. 只把明确有效、可展示的叶子项目生成 `cost_project`。
8. 对停用或禁用节点，根据 `disabled`、`jyrq`、`lshsxm_zt` 生成禁用状态或进入异常清单。

## 7. 需要业务或 DBA 补充确认

| 问题 | 为什么重要 |
|---|---|
| `lshsxm_xmnm` 和 `lshsxm_id` 哪个是稳定唯一主键 | 决定导入幂等键 |
| `parent_xmnm`、`lshsxm_fjnm`、`nfjm`、`nparent_xmnm` 哪个表示当前有效父节点 | 决定树结构 |
| `lshsxm_js` 的各级样例名称 | 决定如何转换成 `DOMAIN/SERIES/MODEL` |
| `lshsxm_mx` 取值含义 | 决定是否能用作叶子节点判断 |
| `lshsxm_xmlx` 是否等同主业项目所属类别 | 决定能否生成成本库“系列” |
| 领域从哪里来 | 当前截图未看到直接字段，必须确认从层级、外部映射还是其他表取 |
| `disabled`、`lshsxm_zt`、`jyrq` 的取值范围 | 决定有效/停用过滤 |
| 是否存在最后修改时间字段 | 决定后续能否增量同步 |
| 原表是否一年一表或按版本建表 | 决定同步范围和后续表名策略 |

## 8. 下一步

1. 请 DBA 导出 `sc_8001_cw.ads_lc_lshsxm2022` 的完整 DDL，不只截图。
2. 抽取 20 至 50 行真实样例，至少覆盖一级、二级、三级、叶子、停用节点。
3. 用样例数据跑父子关系校验，确认当前有效父节点字段。
4. 再更新本文，把“初步理解”改成正式映射规则。
5. 已新增第二张“工作令关联主业项目字典”和第三张“项目工作令账面成本明细数据”原表整理，下一步用样例数据确认项目树、工作令映射和账面明细三者之间的关联键。
