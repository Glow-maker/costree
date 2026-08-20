-- 旧清库/重装完成后恢复成本库手工字段、流程状态和预警处理状态。
-- 常规 snapshot-upsert 不得执行本文件。

BEGIN;
SELECT pg_advisory_xact_lock(hashtext('cost-manual-snapshot'));

DO $$
DECLARE
    v_batch varchar(64) := (SELECT current_batch_code FROM cost_manual_snapshot.snapshot_control WHERE id = 1);
    v_tenant int8 := (SELECT tenant_id FROM cost_manual_snapshot.snapshot_control WHERE id = 1);
    v_columns text;
    v_object record;
BEGIN
    IF (SELECT snapshot_status FROM cost_manual_snapshot.snapshot_control WHERE id = 1) <> 'PRECHECK_OK' THEN
        RAISE EXCEPTION '手工快照状态不是 PRECHECK_OK，拒绝恢复';
    END IF;

    DELETE FROM cost_manual_snapshot.restore_exception
    WHERE batch_code = v_batch AND tenant_id = v_tenant;

    INSERT INTO cost_manual_snapshot.restore_exception(batch_code, tenant_id, object_name, business_key, reason)
    SELECT v_batch, v_tenant, 'project_state', s.project_code, '原主键已被其他项目或租户占用'
    FROM cost_manual_snapshot.project_state s
    JOIN "costree_mvp".cost_project t ON t.id = s.id
    WHERE s.batch_code = v_batch AND s.tenant_id = v_tenant
      AND (t.tenant_id <> v_tenant OR t.project_code <> s.project_code)
    UNION ALL
    SELECT v_batch, v_tenant, 'project_basic', COALESCE(s.project_code, s.id::text), '原主键已被其他项目或租户占用'
    FROM cost_manual_snapshot.project_basic s
    JOIN "costree_mvp".cost_project_basic t ON t.id = s.id
    WHERE s.batch_code = v_batch AND s.tenant_id = v_tenant
      AND (t.tenant_id <> v_tenant OR t.project_code IS DISTINCT FROM s.project_code)
    UNION ALL
    SELECT v_batch, v_tenant, 'unit_fill', s.project_code || '|' || s.unit_name, '原主键已被其他业务记录或租户占用'
    FROM cost_manual_snapshot.unit_fill s
    JOIN "costree_mvp".cost_unit_cost_detail t ON t.id = s.id
    WHERE s.batch_code = v_batch AND s.tenant_id = v_tenant
      AND (t.tenant_id <> v_tenant OR t.project_code <> s.project_code OR t.unit_name <> s.unit_name)
    UNION ALL
    SELECT v_batch, v_tenant, 'work_order_fill', s.project_code || '|' || s.unit_name || '|' || s.work_order_no, '原主键已被其他业务记录或租户占用'
    FROM cost_manual_snapshot.work_order_fill s
    JOIN "costree_mvp".cost_work_order t ON t.id = s.id
    WHERE s.batch_code = v_batch AND s.tenant_id = v_tenant
      AND (t.tenant_id <> v_tenant OR t.project_code <> s.project_code OR t.unit_name <> s.unit_name OR t.work_order_no <> s.work_order_no)
    UNION ALL
    SELECT v_batch, v_tenant, 'warning_state_v2', s.id::text, '原预警主键已被其他租户占用'
    FROM cost_manual_snapshot.warning_state_v2 s
    JOIN "costree_mvp".cost_warning_record t ON t.id = s.id
    WHERE s.batch_code = v_batch AND s.tenant_id = v_tenant AND t.tenant_id <> v_tenant
    UNION ALL
    SELECT v_batch, v_tenant, 'warning_receiver', s.id::text, '接收人主键已被其他租户占用'
    FROM cost_manual_snapshot.warning_receiver s
    JOIN "costree_mvp".cost_warning_receiver t ON t.id = s.id
    WHERE s.batch_code = v_batch AND s.tenant_id = v_tenant AND t.tenant_id <> v_tenant
    UNION ALL
    SELECT v_batch, v_tenant, 'warning_action_log', s.id::text, '操作日志主键已被其他租户占用'
    FROM cost_manual_snapshot.warning_action_log s
    JOIN "costree_mvp".cost_warning_action_log t ON t.id = s.id
    WHERE s.batch_code = v_batch AND s.tenant_id = v_tenant AND t.tenant_id <> v_tenant;

    IF EXISTS (SELECT 1 FROM cost_manual_snapshot.restore_exception WHERE batch_code = v_batch AND tenant_id = v_tenant) THEN
        RAISE EXCEPTION '恢复前检查失败：存在主键冲突，请查看 cost_manual_snapshot.restore_exception';
    END IF;

    -- 按依赖顺序补回清库后缺失的业务记录。列清单来自目标表与快照表交集。
    FOR v_object IN
        SELECT * FROM (VALUES
            ('project_state', 'cost_project', 'NOT EXISTS (SELECT 1 FROM "costree_mvp".cost_project x WHERE x.tenant_id = s.tenant_id AND x.project_code = s.project_code)'),
            ('project_basic', 'cost_project_basic', 'NOT EXISTS (SELECT 1 FROM "costree_mvp".cost_project_basic x WHERE x.id = s.id)'),
            ('unit_fill', 'cost_unit_cost_detail', 'NOT EXISTS (SELECT 1 FROM "costree_mvp".cost_unit_cost_detail x WHERE x.tenant_id = s.tenant_id AND x.project_code = s.project_code AND x.unit_name = s.unit_name)'),
            ('work_order_fill', 'cost_work_order', 'NOT EXISTS (SELECT 1 FROM "costree_mvp".cost_work_order x WHERE x.tenant_id = s.tenant_id AND x.project_code = s.project_code AND x.unit_name = s.unit_name AND x.work_order_no = s.work_order_no)'),
            ('warning_state_v2', 'cost_warning_record', 'NOT EXISTS (SELECT 1 FROM "costree_mvp".cost_warning_record x WHERE x.id = s.id)'),
            ('warning_receiver', 'cost_warning_receiver', 'NOT EXISTS (SELECT 1 FROM "costree_mvp".cost_warning_receiver x WHERE x.id = s.id)'),
            ('warning_action_log', 'cost_warning_action_log', 'NOT EXISTS (SELECT 1 FROM "costree_mvp".cost_warning_action_log x WHERE x.id = s.id)')
        ) AS objects(snapshot_table, target_table, insert_guard)
    LOOP
        SELECT string_agg(quote_ident(target_column.column_name), ', ' ORDER BY target_column.ordinal_position)
          INTO v_columns
        FROM information_schema.columns target_column
        WHERE target_column.table_schema = 'costree_mvp'
          AND target_column.table_name = v_object.target_table
          AND EXISTS (
              SELECT 1 FROM information_schema.columns snapshot_column
              WHERE snapshot_column.table_schema = 'cost_manual_snapshot'
                AND snapshot_column.table_name = v_object.snapshot_table
                AND snapshot_column.column_name = target_column.column_name
          );

        EXECUTE 'INSERT INTO "costree_mvp".' || quote_ident(v_object.target_table) || ' (' || v_columns || ') '
             || 'SELECT ' || v_columns || ' FROM cost_manual_snapshot.' || quote_ident(v_object.snapshot_table) || ' s '
             || 'WHERE s.batch_code = ' || quote_literal(v_batch) || ' AND s.tenant_id = ' || v_tenant
             || ' AND ' || v_object.insert_guard;
    END LOOP;
END $$;

-- 已重装记录只恢复成本库拥有的字段；外部源字段以重装后的值为准。
UPDATE "costree_mvp".cost_project target
SET batch_no = snapshot.batch_no, stage_codes = snapshot.stage_codes,
    unit_id = snapshot.unit_id, unit_name = snapshot.unit_name, unit_type = snapshot.unit_type,
    project_office_status = snapshot.project_office_status,
    unit_fill_status = snapshot.unit_fill_status, audit_status = snapshot.audit_status,
    dept_id = snapshot.dept_id, owner_user_id = snapshot.owner_user_id,
    warning_status = snapshot.warning_status, remark = snapshot.remark,
    creator = snapshot.creator, create_time = snapshot.create_time,
    updater = snapshot.updater, update_time = snapshot.update_time, deleted = snapshot.deleted
FROM cost_manual_snapshot.project_state snapshot
JOIN cost_manual_snapshot.snapshot_control control
  ON control.id = 1 AND snapshot.batch_code = control.current_batch_code AND snapshot.tenant_id = control.tenant_id
WHERE target.tenant_id = snapshot.tenant_id AND target.project_code = snapshot.project_code;

UPDATE "costree_mvp".cost_project_basic target
SET product_attachment_type = snapshot.product_attachment_type,
    subsystem_name = snapshot.subsystem_name, quantity = snapshot.quantity,
    product_short_name = snapshot.product_short_name, vertical_division = snapshot.vertical_division,
    user_name = snapshot.user_name, acquire_method = snapshot.acquire_method,
    batch_category = snapshot.batch_category, platform_series = snapshot.platform_series,
    research_unit_id = snapshot.research_unit_id, research_unit_name = snapshot.research_unit_name,
    target_price = snapshot.target_price, competitor_unit_1 = snapshot.competitor_unit_1,
    competitor_price_1 = snapshot.competitor_price_1, competitor_unit_2 = snapshot.competitor_unit_2,
    competitor_price_2 = snapshot.competitor_price_2, contract_amount = snapshot.contract_amount,
    tax_exempt = snapshot.tax_exempt, target_cost_amount = snapshot.target_cost_amount,
    approved_amount = snapshot.approved_amount, cycle_start = snapshot.cycle_start,
    cycle_end = snapshot.cycle_end, stage_code = snapshot.stage_code,
    basic_info = snapshot.basic_info, status = snapshot.status, remark = snapshot.remark,
    import_batch_id = snapshot.import_batch_id, dept_id = snapshot.dept_id,
    owner_user_id = snapshot.owner_user_id, creator = snapshot.creator,
    create_time = snapshot.create_time, updater = snapshot.updater,
    update_time = snapshot.update_time, deleted = snapshot.deleted
FROM cost_manual_snapshot.project_basic snapshot
JOIN cost_manual_snapshot.snapshot_control control
  ON control.id = 1 AND snapshot.batch_code = control.current_batch_code AND snapshot.tenant_id = control.tenant_id
WHERE target.id = snapshot.id;

UPDATE "costree_mvp".cost_unit_cost_detail target
SET target_cost_amount = snapshot.target_cost_amount, approved_amount = snapshot.approved_amount,
    salary_amount = snapshot.salary_amount, material_amount = snapshot.material_amount,
    outsource_amount = snapshot.outsource_amount, manage_amount = snapshot.manage_amount,
    fuel_power_amount = snapshot.fuel_power_amount, other_amount = snapshot.other_amount,
    remark = snapshot.remark, creator = snapshot.creator, create_time = snapshot.create_time,
    updater = snapshot.updater, update_time = snapshot.update_time, deleted = snapshot.deleted
FROM cost_manual_snapshot.unit_fill snapshot
JOIN cost_manual_snapshot.snapshot_control control
  ON control.id = 1 AND snapshot.batch_code = control.current_batch_code AND snapshot.tenant_id = control.tenant_id
WHERE target.tenant_id = snapshot.tenant_id
  AND target.project_code = snapshot.project_code AND target.unit_name = snapshot.unit_name;

UPDATE "costree_mvp".cost_work_order target
SET product_target_cost = snapshot.product_target_cost,
    contract_amount = snapshot.contract_amount, income_amount = snapshot.income_amount,
    approved_amount = snapshot.approved_amount, stage_codes = snapshot.stage_codes,
    max_stage_code = snapshot.max_stage_code, subsystem_name = snapshot.subsystem_name,
    product_short_name = snapshot.product_short_name, quantity = snapshot.quantity,
    vertical_division = snapshot.vertical_division, status = snapshot.status,
    remark = snapshot.remark, import_batch_id = snapshot.import_batch_id,
    dept_id = snapshot.dept_id, owner_user_id = snapshot.owner_user_id,
    creator = snapshot.creator, create_time = snapshot.create_time,
    updater = snapshot.updater, update_time = snapshot.update_time, deleted = snapshot.deleted
FROM cost_manual_snapshot.work_order_fill snapshot
JOIN cost_manual_snapshot.snapshot_control control
  ON control.id = 1 AND snapshot.batch_code = control.current_batch_code AND snapshot.tenant_id = control.tenant_id
WHERE target.tenant_id = snapshot.tenant_id
  AND ((snapshot.source_work_order_id IS NOT NULL AND target.source_work_order_id = snapshot.source_work_order_id)
       OR (target.project_code = snapshot.project_code AND target.unit_name = snapshot.unit_name
           AND target.work_order_no = snapshot.work_order_no));

UPDATE "costree_mvp".cost_warning_record target
SET warning_source = snapshot.warning_source, warning_title = snapshot.warning_title,
    target_cost_amount = snapshot.target_cost_amount, actual_cost_amount = snapshot.actual_cost_amount,
    over_amount = snapshot.over_amount, over_rate = snapshot.over_rate,
    threshold_rate = snapshot.threshold_rate, warning_level = snapshot.warning_level,
    responsible_unit_name = snapshot.responsible_unit_name, push_status = snapshot.push_status,
    pushed_time = snapshot.pushed_time, receiver_scope = snapshot.receiver_scope,
    message_id = snapshot.message_id, status = snapshot.status, remark = snapshot.remark,
    project_code = snapshot.project_code, project_name = snapshot.project_name,
    domain_code = snapshot.domain_code, domain_name = snapshot.domain_name,
    model_code = snapshot.model_code, model_name = snapshot.model_name,
    cycle_no = snapshot.cycle_no, workflow_status = snapshot.workflow_status,
    active_marker = snapshot.active_marker, initiator_user_id = snapshot.initiator_user_id,
    initiator_user_name = snapshot.initiator_user_name, initiated_time = snapshot.initiated_time,
    disposition_user_id = snapshot.disposition_user_id, disposition_user_name = snapshot.disposition_user_name,
    cause_analysis = snapshot.cause_analysis, disposal_measure = snapshot.disposal_measure,
    expected_completion_date = snapshot.expected_completion_date, disposition_time = snapshot.disposition_time,
    close_user_id = snapshot.close_user_id, close_user_name = snapshot.close_user_name,
    close_time = snapshot.close_time, return_reason = snapshot.return_reason,
    creator = snapshot.creator, create_time = snapshot.create_time,
    updater = snapshot.updater, update_time = snapshot.update_time, deleted = snapshot.deleted
FROM cost_manual_snapshot.warning_state_v2 snapshot
JOIN cost_manual_snapshot.snapshot_control control
  ON control.id = 1 AND snapshot.batch_code = control.current_batch_code AND snapshot.tenant_id = control.tenant_id
WHERE target.id = snapshot.id;

-- 清库后主键可能变化，统一按稳定业务键重新映射引用。
UPDATE "costree_mvp".cost_project_basic basic
SET project_id = project.id
FROM "costree_mvp".cost_project project
WHERE basic.tenant_id = project.tenant_id AND basic.project_code = project.project_code
  AND basic.tenant_id = (SELECT tenant_id FROM cost_manual_snapshot.snapshot_control WHERE id = 1);

UPDATE "costree_mvp".cost_unit_cost_detail unit_cost
SET project_id = project.id
FROM "costree_mvp".cost_project project
WHERE unit_cost.tenant_id = project.tenant_id AND unit_cost.project_code = project.project_code
  AND unit_cost.tenant_id = (SELECT tenant_id FROM cost_manual_snapshot.snapshot_control WHERE id = 1);

UPDATE "costree_mvp".cost_work_order work_order
SET project_id = project.id
FROM "costree_mvp".cost_project project
WHERE work_order.tenant_id = project.tenant_id AND work_order.project_code = project.project_code
  AND work_order.tenant_id = (SELECT tenant_id FROM cost_manual_snapshot.snapshot_control WHERE id = 1);

UPDATE "costree_mvp".cost_warning_record warning
SET project_id = project.id,
    work_order_id = work_order.id
FROM cost_manual_snapshot.warning_state_v2 snapshot
LEFT JOIN "costree_mvp".cost_project project
  ON project.tenant_id = snapshot.tenant_id AND project.project_code = snapshot.project_code_key
LEFT JOIN "costree_mvp".cost_work_order work_order
  ON work_order.tenant_id = snapshot.tenant_id
 AND work_order.project_code = snapshot.project_code_key
 AND work_order.unit_name = snapshot.work_order_unit_key
 AND work_order.work_order_no = snapshot.work_order_no_key
JOIN cost_manual_snapshot.snapshot_control control
  ON control.id = 1 AND snapshot.batch_code = control.current_batch_code AND snapshot.tenant_id = control.tenant_id
WHERE warning.id = snapshot.id;

-- 补回原业务主键后推进序列，避免后续页面新增时与恢复 ID 冲突。
DO $$
DECLARE
    v_sequence text;
    v_table text;
    v_max_id int8;
BEGIN
    FOR v_sequence, v_table IN
        SELECT * FROM (VALUES
            ('cost_project_seq', 'cost_project'),
            ('cost_project_basic_seq', 'cost_project_basic'),
            ('cost_unit_cost_detail_seq', 'cost_unit_cost_detail'),
            ('cost_work_order_seq', 'cost_work_order'),
            ('cost_warning_record_seq', 'cost_warning_record'),
            ('cost_warning_receiver_seq', 'cost_warning_receiver'),
            ('cost_warning_action_log_seq', 'cost_warning_action_log')
        ) AS sequence_map(sequence_name, table_name)
    LOOP
        EXECUTE 'SELECT max(id) FROM "costree_mvp".' || quote_ident(v_table) INTO v_max_id;
        IF v_max_id IS NOT NULL THEN
            PERFORM setval(('"costree_mvp".' || quote_ident(v_sequence))::regclass, v_max_id, true);
        END IF;
    END LOOP;
END $$;

UPDATE cost_manual_snapshot.snapshot_control
SET snapshot_status = 'RESTORED_PENDING_VERIFY', restored_at = CURRENT_TIMESTAMP,
    remark = '恢复 SQL 已完成，等待恢复后验收'
WHERE id = 1;

COMMIT;

SELECT current_batch_code, tenant_id, snapshot_status, restored_at, remark
FROM cost_manual_snapshot.snapshot_control WHERE id = 1;
