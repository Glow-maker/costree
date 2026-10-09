# 同名不同核算编码的院外归属

现场截图：华中科技大学存在两条不同accounting_unit_code记录，manage_unit_code同为M99，manage_unit_group同为OUTER，inside_institute/inside_group同为false，状态ENABLE、deleted=0、tenant124。字典中这两条的院外标志一致。

当前89b19528前端buildUnitDictionaryIndex将accountingUnitCode差异也判定为同名冲突，导致名称查询得到undefined，归入UNKNOWN。以截图同类数据复现：新测试和两处树页计算测试共3项失败。注意此路径显示的是“归属待核对”，若现场原文仍为“未分类院内单位”，仍需核对实际前端版本和接口响应，不能仅凭字典截图证明全部现场链路。

修复：分类冲突判断不再包含accountingUnitCode；同名且管理归属及院内/集团标志一致时保留共同属性，差异ID/编码等属性删除，避免把任意一条核算记录标识展示给聚合名称。仍保留真正院内外、管理归属冲突的UNKNOWN处理，以及核算名优先于往来别名。未更改真实数据、合计公式或授权范围。

验证：53项成本前端测试和ts:check:cost通过，git diff --check通过。覆盖同名多编码输入顺序、3条记录、院内/院外一致、真实标志冲突、两处树页归属和金额只计一次。

本轮尚未提交、推送或重新打包；保留上一轮下拉重复请求修复。20260923交付包仍为原件，不包含这两项追加修复。前端工作区涉及unitClassification.ts、ledgerCompositionDetail/index.vue、cost-intranet-regression.test.cjs。
