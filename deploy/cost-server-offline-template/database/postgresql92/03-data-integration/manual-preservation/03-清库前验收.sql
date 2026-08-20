-- 验证快照完整后才允许执行旧清库/重装 SQL。

BEGIN;

DO $$
DECLARE
    v_batch varchar(64) := (SELECT current_batch_code FROM cost_manual_snapshot.snapshot_control WHERE id = 1);
    v_tenant int8 := (SELECT tenant_id FROM cost_manual_snapshot.snapshot_control WHERE id = 1);
    v_error text;
BEGIN
    IF (SELECT snapshot_status FROM cost_manual_snapshot.snapshot_control WHERE id = 1) <> 'SNAPSHOT_READY' THEN
        RAISE EXCEPTION '手工快照状态不是 SNAPSHOT_READY';
    END IF;
    IF (SELECT count(*) FROM cost_manual_snapshot.snapshot_count WHERE batch_code = v_batch AND tenant_id = v_tenant) <> 7 THEN
        RAISE EXCEPTION '手工快照对象计数不完整';
    END IF;

    SELECT string_agg(object_name || ': snapshot=' || expected_count || ', current=' || current_count, '; ')
      INTO v_error
    FROM (
        SELECT expected.object_name, expected.row_count AS expected_count,
               CASE expected.object_name
                   WHEN 'project_state' THEN (SELECT count(*) FROM "costree_mvp".cost_project WHERE tenant_id = v_tenant)
                   WHEN 'project_basic' THEN (SELECT count(*) FROM "costree_mvp".cost_project_basic WHERE tenant_id = v_tenant)
                   WHEN 'unit_fill' THEN (SELECT count(*) FROM "costree_mvp".cost_unit_cost_detail WHERE tenant_id = v_tenant)
                   WHEN 'work_order_fill' THEN (SELECT count(*) FROM "costree_mvp".cost_work_order WHERE tenant_id = v_tenant)
                   WHEN 'warning_state_v2' THEN (SELECT count(*) FROM "costree_mvp".cost_warning_record WHERE tenant_id = v_tenant)
                   WHEN 'warning_receiver' THEN (SELECT count(*) FROM "costree_mvp".cost_warning_receiver WHERE tenant_id = v_tenant)
                   WHEN 'warning_action_log' THEN (SELECT count(*) FROM "costree_mvp".cost_warning_action_log WHERE tenant_id = v_tenant)
               END AS current_count
        FROM cost_manual_snapshot.snapshot_count expected
        WHERE expected.batch_code = v_batch AND expected.tenant_id = v_tenant
    ) checked
    WHERE expected_count <> current_count;

    IF v_error IS NOT NULL THEN
        RAISE EXCEPTION '清库前快照验收失败：%', v_error;
    END IF;
END $$;

UPDATE cost_manual_snapshot.snapshot_control
SET snapshot_status = 'PRECHECK_OK', remark = '清库前验收通过；可执行已备份、已审核的旧重装 SQL'
WHERE id = 1;

COMMIT;

SELECT current_batch_code, tenant_id, snapshot_status, snapshot_at, remark
FROM cost_manual_snapshot.snapshot_control WHERE id = 1;
