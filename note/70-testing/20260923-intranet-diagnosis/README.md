# 20260923 内网三个问题定位（只读）

用户确认已换 20260921 包。前端当前 e495dbda 与包记录一致；后端当前87b8bd2f，交付为55083357。以下分析以交付的成本实现为准，未连接内网，未修改业务代码/数据库/制品。

## 1. 工作令明细刷新后未打开

已用当前实际函数定向复现一条确定的失败路径：URL带manageUnitName但名称未映射为manageUnitCode时，reloadFromRoute每次都会再次做旧名称映射，并先关闭明细。若关闭动画完成早于选项接口返回，handleDetailDrawerClosed再次同步URL，清掉itemCode。该URL变动触发第二轮加载，通过routeReloadSequence使第一轮重开明细失效，最终弹窗保持关闭。见 reproduction-results.json。

此外同页router.replace触发全局permission.ts的start/loadStart，产生刷新视觉。此前AppView/FullView稳定path key只修了组件重建，没有解决上述时序问题。已存在代码缺陷；该条件是否正是现场触发点仍需请求参数确认，不能仅凭现象排除其他时序问题。

位置：ledgerCompositionDetail/index.vue 1199 openDetailDrawer、1225 handleDetailDrawerClosed、1455 syncRouteQuery、1494 reloadFromRoute；treeUnitDetail/index.vue 1025 openCompositionDetailPage传递unitName/manageUnitName。

修复方向：同页打开/切换成本项不应重新加载整个范围；未解析名称只在初次或名称变化时处理；关闭动画回调不得覆盖新一轮打开或路由恢复，保留关闭/重开/前进后退及慢接口的回归验证。

## 2. 领域/型号下拉空

选项接口 /cost/work-order-ledger/filter-options（DOMAIN/MODEL），实际基础路径为 cost_work_order_ledger_detail -> 按tenant_id/project_code关联cost_project；读取cost_project.domain_code/domain_name/model_code/model_name。不是直接取cost_model_node。

还要求：借方、未删除、存在同项目同工作令同核算单位名称的纵向工作令；并叠加当前管理单位/核算单位、阶段、凭证年度/期间和账号数据范围。名称/项目关联断开、归属字段未同步、筛选条件过窄、权限返回空或接口失败均能造成空选项。未获取现场API/数据结果，不能断言缺字段。

现有全量升级脚本补结构，不负责把权威业务字典/领域/型号数据重新同步进cost_project。若空字段应按权威来源核实同步，不应虚构编码或从名称随意补值。模型源字段已存在于交付DDL中。

检查：先清空年度/期间/单位/阶段，从账面组成入口查看，再在Network观察两类filter-options响应。请求失败、code非0、data=[]、有data但UI空应分别处理。01-read-only-check.sql提供不含账号权限过滤的底表核验，不能将其结果当作用户应有权限。

## 3. 院外误归院内未分类

两个树页把返回的cost_unit_dict按accountingUnitName/contactUnitName建立名称Map。getManageUnitIdentity/isInsideInstituteUnit使用insideInstitute ?? true，字典找不到或标志null都默认院内；manageUnitGroup不在有效内部分类时归UNCLASSIFIED。定向测试已复现“字典找不到 -> 院内未分类”。同名或别名多条还可能相互覆盖，当前没有歧义检测。

正确字段：cost_unit_dict.inside_institute判断是否八院；inside_group只表示集团归属，true不代表院内；manage_unit_group是总体/总装/专业/基础等另一个维度。前端只取得ENABLE、未删除且当前租户/角色可见的字典。只更新源/中台字典而未同步成本字典，名称不一致、字典不可见、标志为空都可能触发默认院内。若接口确实返回该单位insideInstitute=false且唯一正确匹配，现逻辑不会把它作为院内节点，需继续定位实际匹配行。

修复方向：分类未知不应伪装成院内；明确区分核算名/往来名及重复映射，保持金额和权限范围不变。不能把未知全部改成院外，也不能仅依赖inside_group。

## 现场补证据

- 一个误分类单位的实际名称、当前角色，以及“是否八院/集团”填在哪张字典。
- DOMAIN/MODEL两条filter-options请求参数、响应code/data；无须提供账号口令。
- 确认实际成本schema/tenant后执行附带只读SQL。默认public/124仅为历史配置，须核实。

本轮只提供定位和只读核查材料；业务源码、历史包、真实数据库均未更改。旧SQL隔离测试/本地定向代码复现不替代现场验收。
