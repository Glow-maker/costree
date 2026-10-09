# 四个站内信模板：只用页面，不执行 DM SQL

由平台管理员打开「系统管理 → 站内信 → 模板管理」。按编码查询；存在则编辑，不重复创建。发送人昵称统一为“成本预警中心”，类型为系统通知（字典值2），状态开启。正文中的花括号参数原样保留。

## 预警待处置

编码：`COST_WARNING_PENDING_DISPOSITION`

正文：

```text
项目【{projectName}（{projectCode}）】责任单位【{unitName}】触发{warningLevel}预警，超支金额 {overAmount}，请完成第 {cycleNo} 期处置反馈。
```

## 预警处置已反馈

编码：`COST_WARNING_FEEDBACK_SUBMITTED`

正文：

```text
项目【{projectName}（{projectCode}）】责任单位【{unitName}】已由 {dispositionName} 提交第 {cycleNo} 期处置反馈，请项目办确认。
```

## 预警任务被退回

编码：`COST_WARNING_RETURNED`

正文：

```text
项目【{projectName}（{projectCode}）】第 {cycleNo} 期预警处置被退回，原因：{returnReason}，请重新提交。
```

## 预警任务已闭环

编码：`COST_WARNING_CLOSED`

正文：

```text
项目【{projectName}（{projectCode}）】责任单位【{unitName}】第 {cycleNo} 期预警任务已闭环。
```

模板参数由页面按正文解析。保存后重新打开核对四个编码和启用状态，再以项目办推送、研制单位反馈验证。
