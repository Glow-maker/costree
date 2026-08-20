-- 恢复后逐对象核对成本库拥有字段；失败时不标记 RESTORED。

BEGIN;

DELETE FROM cost_manual_snapshot.restore_exception exception
USING cost_manual_snapshot.snapshot_control control
WHERE control.id = 1 AND exception.batch_code = control.current_batch_code AND exception.tenant_id = control.tenant_id;

INSERT INTO cost_manual_snapshot.restore_exception(batch_code, tenant_id, object_name, business_key, reason)
SELECT control.current_batch_code, control.tenant_id, 'project_state', snapshot.project_code, '项目缺失或手工状态/负责人/审计字段不一致'
FROM cost_manual_snapshot.snapshot_control control
JOIN cost_manual_snapshot.project_state snapshot ON snapshot.batch_code = control.current_batch_code AND snapshot.tenant_id = control.tenant_id
LEFT JOIN "costree_mvp".cost_project target ON target.tenant_id = snapshot.tenant_id AND target.project_code = snapshot.project_code
WHERE control.id = 1 AND (target.id IS NULL OR md5(ROW(
    target.batch_no, target.stage_codes, target.unit_id, target.unit_name, target.unit_type,
    target.project_office_status, target.unit_fill_status, target.audit_status,
    target.dept_id, target.owner_user_id, target.warning_status, target.remark,
    target.creator, target.create_time, target.updater, target.update_time, target.deleted
)::text) <> md5(ROW(
    snapshot.batch_no, snapshot.stage_codes, snapshot.unit_id, snapshot.unit_name, snapshot.unit_type,
    snapshot.project_office_status, snapshot.unit_fill_status, snapshot.audit_status,
    snapshot.dept_id, snapshot.owner_user_id, snapshot.warning_status, snapshot.remark,
    snapshot.creator, snapshot.create_time, snapshot.updater, snapshot.update_time, snapshot.deleted
)::text))
UNION ALL
SELECT control.current_batch_code, control.tenant_id, 'project_basic', COALESCE(snapshot.project_code, snapshot.id::text), '项目办填报、状态或审计字段不一致'
FROM cost_manual_snapshot.snapshot_control control
JOIN cost_manual_snapshot.project_basic snapshot ON snapshot.batch_code = control.current_batch_code AND snapshot.tenant_id = control.tenant_id
LEFT JOIN "costree_mvp".cost_project_basic target ON target.id = snapshot.id
WHERE control.id = 1 AND (target.id IS NULL OR md5(ROW(
    target.product_attachment_type, target.subsystem_name, target.quantity, target.product_short_name,
    target.vertical_division, target.user_name, target.acquire_method, target.batch_category,
    target.platform_series, target.research_unit_id, target.research_unit_name, target.target_price,
    target.competitor_unit_1, target.competitor_price_1, target.competitor_unit_2,
    target.competitor_price_2, target.contract_amount, target.tax_exempt,
    target.target_cost_amount, target.approved_amount, target.cycle_start, target.cycle_end,
    target.stage_code, target.basic_info, target.status, target.remark, target.import_batch_id,
    target.dept_id, target.owner_user_id, target.creator, target.create_time,
    target.updater, target.update_time, target.deleted
)::text) <> md5(ROW(
    snapshot.product_attachment_type, snapshot.subsystem_name, snapshot.quantity, snapshot.product_short_name,
    snapshot.vertical_division, snapshot.user_name, snapshot.acquire_method, snapshot.batch_category,
    snapshot.platform_series, snapshot.research_unit_id, snapshot.research_unit_name, snapshot.target_price,
    snapshot.competitor_unit_1, snapshot.competitor_price_1, snapshot.competitor_unit_2,
    snapshot.competitor_price_2, snapshot.contract_amount, snapshot.tax_exempt,
    snapshot.target_cost_amount, snapshot.approved_amount, snapshot.cycle_start, snapshot.cycle_end,
    snapshot.stage_code, snapshot.basic_info, snapshot.status, snapshot.remark, snapshot.import_batch_id,
    snapshot.dept_id, snapshot.owner_user_id, snapshot.creator, snapshot.create_time,
    snapshot.updater, snapshot.update_time, snapshot.deleted
)::text))
UNION ALL
SELECT control.current_batch_code, control.tenant_id, 'unit_fill', snapshot.project_code || '|' || snapshot.unit_name, '单位目标/审定/手工组成或审计字段不一致'
FROM cost_manual_snapshot.snapshot_control control
JOIN cost_manual_snapshot.unit_fill snapshot ON snapshot.batch_code = control.current_batch_code AND snapshot.tenant_id = control.tenant_id
LEFT JOIN "costree_mvp".cost_unit_cost_detail target ON target.tenant_id = snapshot.tenant_id AND target.project_code = snapshot.project_code AND target.unit_name = snapshot.unit_name
WHERE control.id = 1 AND (target.id IS NULL OR md5(ROW(
    target.target_cost_amount, target.approved_amount, target.salary_amount, target.material_amount,
    target.outsource_amount, target.manage_amount, target.fuel_power_amount, target.other_amount,
    target.remark, target.creator, target.create_time, target.updater, target.update_time, target.deleted
)::text) <> md5(ROW(
    snapshot.target_cost_amount, snapshot.approved_amount, snapshot.salary_amount, snapshot.material_amount,
    snapshot.outsource_amount, snapshot.manage_amount, snapshot.fuel_power_amount, snapshot.other_amount,
    snapshot.remark, snapshot.creator, snapshot.create_time, snapshot.updater, snapshot.update_time, snapshot.deleted
)::text))
UNION ALL
SELECT control.current_batch_code, control.tenant_id, 'work_order_fill', snapshot.project_code || '|' || snapshot.unit_name || '|' || snapshot.work_order_no, '工作令填报、纵向分工、状态或审计字段不一致'
FROM cost_manual_snapshot.snapshot_control control
JOIN cost_manual_snapshot.work_order_fill snapshot ON snapshot.batch_code = control.current_batch_code AND snapshot.tenant_id = control.tenant_id
LEFT JOIN "costree_mvp".cost_work_order target ON target.tenant_id = snapshot.tenant_id
 AND ((snapshot.source_work_order_id IS NOT NULL AND target.source_work_order_id = snapshot.source_work_order_id)
      OR (target.project_code = snapshot.project_code AND target.unit_name = snapshot.unit_name AND target.work_order_no = snapshot.work_order_no))
WHERE control.id = 1 AND (target.id IS NULL OR md5(ROW(
    target.product_target_cost, target.contract_amount, target.income_amount, target.approved_amount,
    target.stage_codes, target.max_stage_code, target.subsystem_name, target.product_short_name,
    target.quantity, target.vertical_division, target.status, target.remark, target.import_batch_id,
    target.dept_id, target.owner_user_id, target.creator, target.create_time,
    target.updater, target.update_time, target.deleted
)::text) <> md5(ROW(
    snapshot.product_target_cost, snapshot.contract_amount, snapshot.income_amount, snapshot.approved_amount,
    snapshot.stage_codes, snapshot.max_stage_code, snapshot.subsystem_name, snapshot.product_short_name,
    snapshot.quantity, snapshot.vertical_division, snapshot.status, snapshot.remark, snapshot.import_batch_id,
    snapshot.dept_id, snapshot.owner_user_id, snapshot.creator, snapshot.create_time,
    snapshot.updater, snapshot.update_time, snapshot.deleted
)::text))
UNION ALL
SELECT control.current_batch_code, control.tenant_id, 'warning_state_v2', snapshot.id::text, '预警任务、处置状态或审计字段不一致'
FROM cost_manual_snapshot.snapshot_control control
JOIN cost_manual_snapshot.warning_state_v2 snapshot ON snapshot.batch_code = control.current_batch_code AND snapshot.tenant_id = control.tenant_id
LEFT JOIN "costree_mvp".cost_warning_record target ON target.id = snapshot.id
WHERE control.id = 1 AND (target.id IS NULL OR md5(ROW(
    target.warning_source, target.warning_title, target.target_cost_amount, target.actual_cost_amount,
    target.over_amount, target.over_rate, target.threshold_rate, target.warning_level,
    target.responsible_unit_name, target.push_status, target.pushed_time, target.receiver_scope,
    target.message_id, target.status, target.remark,
    target.project_code, target.project_name, target.domain_code, target.domain_name,
    target.model_code, target.model_name, target.cycle_no, target.workflow_status, target.active_marker,
    target.initiator_user_id, target.initiator_user_name, target.initiated_time,
    target.disposition_user_id, target.disposition_user_name, target.cause_analysis,
    target.disposal_measure, target.expected_completion_date, target.disposition_time,
    target.close_user_id, target.close_user_name, target.close_time, target.return_reason,
    target.creator, target.create_time,
    target.updater, target.update_time, target.deleted
)::text) <> md5(ROW(
    snapshot.warning_source, snapshot.warning_title, snapshot.target_cost_amount, snapshot.actual_cost_amount,
    snapshot.over_amount, snapshot.over_rate, snapshot.threshold_rate, snapshot.warning_level,
    snapshot.responsible_unit_name, snapshot.push_status, snapshot.pushed_time, snapshot.receiver_scope,
    snapshot.message_id, snapshot.status, snapshot.remark,
    snapshot.project_code, snapshot.project_name, snapshot.domain_code, snapshot.domain_name,
    snapshot.model_code, snapshot.model_name, snapshot.cycle_no, snapshot.workflow_status, snapshot.active_marker,
    snapshot.initiator_user_id, snapshot.initiator_user_name, snapshot.initiated_time,
    snapshot.disposition_user_id, snapshot.disposition_user_name, snapshot.cause_analysis,
    snapshot.disposal_measure, snapshot.expected_completion_date, snapshot.disposition_time,
    snapshot.close_user_id, snapshot.close_user_name, snapshot.close_time, snapshot.return_reason,
    snapshot.creator, snapshot.create_time,
    snapshot.updater, snapshot.update_time, snapshot.deleted
)::text))
UNION ALL
SELECT control.current_batch_code, control.tenant_id, 'warning_receiver', snapshot.id::text, '预警接收账号或通知状态不一致'
FROM cost_manual_snapshot.snapshot_control control
JOIN cost_manual_snapshot.warning_receiver snapshot ON snapshot.batch_code=control.current_batch_code AND snapshot.tenant_id=control.tenant_id
LEFT JOIN "costree_mvp".cost_warning_receiver target ON target.id=snapshot.id
WHERE control.id=1 AND (target.id IS NULL OR md5(ROW(
    target.warning_record_id,target.user_id,target.username,target.nickname,target.notify_status,
    target.message_id,target.notified_time,target.failure_reason,target.deleted
)::text) <> md5(ROW(
    snapshot.warning_record_id,snapshot.user_id,snapshot.username,snapshot.nickname,snapshot.notify_status,
    snapshot.message_id,snapshot.notified_time,snapshot.failure_reason,snapshot.deleted
)::text))
UNION ALL
SELECT control.current_batch_code, control.tenant_id, 'warning_action_log', snapshot.id::text, '预警操作时间线不一致'
FROM cost_manual_snapshot.snapshot_control control
JOIN cost_manual_snapshot.warning_action_log snapshot ON snapshot.batch_code=control.current_batch_code AND snapshot.tenant_id=control.tenant_id
LEFT JOIN "costree_mvp".cost_warning_action_log target ON target.id=snapshot.id
WHERE control.id=1 AND (target.id IS NULL OR md5(ROW(
    target.warning_record_id,target.action_type,target.operator_user_id,target.operator_user_name,
    target.operator_role_code,target.from_status,target.to_status,target.action_content,target.create_time,target.deleted
)::text) <> md5(ROW(
    snapshot.warning_record_id,snapshot.action_type,snapshot.operator_user_id,snapshot.operator_user_name,
    snapshot.operator_role_code,snapshot.from_status,snapshot.to_status,snapshot.action_content,snapshot.create_time,snapshot.deleted
)::text));

DO $$
DECLARE
    v_batch varchar(64) := (SELECT current_batch_code FROM cost_manual_snapshot.snapshot_control WHERE id = 1);
    v_tenant int8 := (SELECT tenant_id FROM cost_manual_snapshot.snapshot_control WHERE id = 1);
BEGIN
    IF (SELECT snapshot_status FROM cost_manual_snapshot.snapshot_control WHERE id = 1) <> 'RESTORED_PENDING_VERIFY' THEN
        RAISE EXCEPTION '手工快照状态不是 RESTORED_PENDING_VERIFY';
    END IF;
    IF EXISTS (SELECT 1 FROM cost_manual_snapshot.restore_exception WHERE batch_code = v_batch AND tenant_id = v_tenant) THEN
        RAISE EXCEPTION '恢复后验收失败，请查看 cost_manual_snapshot.restore_exception';
    END IF;
END $$;

UPDATE cost_manual_snapshot.snapshot_control
SET snapshot_status = 'RESTORED', restored_at = CURRENT_TIMESTAMP,
    remark = '手工字段、流程状态、预警状态和引用恢复验收通过'
WHERE id = 1;

COMMIT;

SELECT current_batch_code, tenant_id, snapshot_status, snapshot_at, restored_at, remark
FROM cost_manual_snapshot.snapshot_control WHERE id = 1;
SELECT * FROM cost_manual_snapshot.restore_exception
WHERE batch_code = (SELECT current_batch_code FROM cost_manual_snapshot.snapshot_control WHERE id = 1)
ORDER BY object_name, business_key;
