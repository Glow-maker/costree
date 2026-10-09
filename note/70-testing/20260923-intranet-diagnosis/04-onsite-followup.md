# 现场反馈：重复请求、全量查询耗时与占位符

现场反馈：一次点击两条 filter-options；所有下拉无选项；旧诊断 B 全量统计十分钟未完成。请求截图只有 Headers，尚未确认 HTTP 状态与 JSON code/data；不得将未显示响应等同 code=0/data=[]，也不能认定接口与诊断SQL相同瓶颈。

已核实当前 Element Plus 的展开监听会调用 remoteMethod，页面另有 visible-change 再调用同一查询。已删除六个额外展开回调。新增回归执行本机安装组件的展开监听与查询分派逻辑，验证各下拉展开一次请求、关闭重开可再次请求。52项成本前端测试通过，diff-check通过；尚未提交/推送/构建，20260923已交付ZIP未覆盖，**不含本次去重修复**。

旧只读诊断B对全部借方明细做多次EXISTS，现场大库不宜重复执行。请先取消该查询；若使用了原脚本的只读事务，在同一连接执行ROLLBACK结束事务。新03-lightweight-check.sql按块执行，包含10秒statement_timeout、元数据/索引和最多20条明细抽样及单条关联定位，不做全量COUNT/GROUP，不执行EXPLAIN ANALYZE。脚本未在真实DWS执行验证；超时不是无数据证据，不应擅自加索引或修改业务值。

后续截图执行旧D/E仍含REPLACE_WITH_UNIT_NAME占位符，D限定costree_mvp而E未限定schema。应使用真实单位名并统一实际schema。D无行不能证明整张字典为空；E的参数LEFT JOIN计数正常应返回一行计数0，不能把客户端空白编辑行当成数据库NULL记录。D/E诊断单位归属，不诊断领域/型号下拉。

下一步：获取一次已完成filter-options的HTTP状态、Response和耗时；或提供旧A/C已完成结果。单位问题先限量查当前schema/租户字典实际数据，再定位确切单位名称。请求头中Authorization不需要分享。
