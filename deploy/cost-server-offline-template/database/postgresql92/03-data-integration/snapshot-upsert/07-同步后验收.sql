-- 同步后强制验收。异常时抛错；最后输出本批对账结果。

BEGIN;

LOCK TABLE cost_sync_stage.sync_control IN EXCLUSIVE MODE;

DO $$
DECLARE
    v_tenant_id int8 := (SELECT tenant_id FROM cost_sync_stage.sync_control WHERE id = 1);
BEGIN
    IF (SELECT load_status FROM cost_sync_stage.sync_control WHERE id = 1) IS DISTINCT FROM 'RECALCULATED' THEN
        RAISE EXCEPTION '本批状态不是 RECALCULATED，请先完成 05 和 06';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_sync_stage.stg_unit_dict s
        WHERE lower(btrim(COALESCE(s.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
          AND NOT EXISTS (
              SELECT 1 FROM "costree_mvp".cost_unit_dict d
              WHERE d.tenant_id = v_tenant_id AND d.deleted = 0
                AND d.accounting_unit_code = s.accounting_unit_code
          )
    ) THEN
        RAISE EXCEPTION '验收失败：存在活动单位未写入业务表';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_sync_stage.stg_project s
        WHERE lower(btrim(COALESCE(s.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
          AND NOT EXISTS (
              SELECT 1 FROM "costree_mvp".cost_project p
              WHERE p.tenant_id = v_tenant_id AND p.deleted = 0
                AND p.project_code = s.project_code
          )
    ) THEN
        RAISE EXCEPTION '验收失败：存在活动项目未写入业务表';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM cost_sync_stage.stg_unit_amount s
        JOIN "costree_mvp".cost_unit_dict u
          ON u.tenant_id = v_tenant_id AND u.accounting_unit_code = s.accounting_unit_code
        JOIN "costree_mvp".cost_unit_cost_detail d
          ON d.tenant_id = v_tenant_id AND d.project_code = s.project_code
         AND d.unit_name = u.accounting_unit_name
        WHERE lower(btrim(COALESCE(s.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
          AND (
              abs(COALESCE(d.contract_amount, 0) - COALESCE(NULLIF(btrim(s.contract_amount_wan), '')::numeric, 0)) > 0.01
              OR abs(COALESCE(d.income_amount, 0) - COALESCE(NULLIF(btrim(s.income_amount_wan), '')::numeric, 0)) > 0.01
          )
    ) THEN
        RAISE EXCEPTION '验收失败：单位合同或到款与本批快照不一致';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_sync_stage.stg_work_order s
        JOIN "costree_mvp".cost_unit_dict u
          ON u.tenant_id = v_tenant_id AND u.accounting_unit_code = s.accounting_unit_code
        WHERE lower(btrim(COALESCE(s.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
          AND NOT EXISTS (
              SELECT 1 FROM "costree_mvp".cost_work_order w
              WHERE w.tenant_id = v_tenant_id AND w.deleted = 0
                AND w.project_code = s.project_code
                AND w.unit_name = u.accounting_unit_name
                AND w.work_order_no = s.work_order_no
          )
    ) THEN
        RAISE EXCEPTION '验收失败：存在活动工作令未写入业务表';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_sync_stage.stg_ledger_detail s
        WHERE lower(btrim(COALESCE(s.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
          AND NOT EXISTS (
              SELECT 1 FROM "costree_mvp".cost_work_order_ledger_detail d
              WHERE d.tenant_id = v_tenant_id AND d.deleted = 0
                AND d.source_detail_id = s.source_detail_id
          )
    ) THEN
        RAISE EXCEPTION '验收失败：存在活动账面明细未写入业务表';
    END IF;

    IF EXISTS (
        SELECT 1 FROM "costree_mvp".cost_work_order_ledger_detail d
        WHERE d.tenant_id = v_tenant_id AND d.deleted = 0
          AND d.source_detail_id IN (SELECT source_detail_id FROM cost_sync_stage.stg_ledger_detail)
          AND abs(COALESCE(d.amount_wan, 0) - COALESCE(d.amount, 0) / 10000.0) > 0.01
    ) THEN
        RAISE EXCEPTION '验收失败：账面元和万元换算不一致';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM "costree_mvp".cost_work_order w
        JOIN (
            SELECT w2.id AS work_order_id,
                   COALESCE(sum(CASE WHEN d.debit_credit = '借' AND d.deleted = 0
                                     THEN COALESCE(d.amount_wan, d.amount / 10000.0)
                                     ELSE 0 END), 0)::numeric(18,2) AS expected_book
            FROM cost_sync_stage.stg_work_order s
            JOIN "costree_mvp".cost_unit_dict u
              ON u.tenant_id = v_tenant_id AND u.accounting_unit_code = s.accounting_unit_code
            JOIN "costree_mvp".cost_work_order w2
              ON w2.tenant_id = v_tenant_id AND w2.project_code = s.project_code
             AND w2.unit_name = u.accounting_unit_name AND w2.work_order_no = s.work_order_no
            LEFT JOIN "costree_mvp".cost_work_order_ledger_detail d
              ON d.tenant_id = v_tenant_id AND d.work_order_id = w2.id
            WHERE lower(btrim(COALESCE(s.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
            GROUP BY w2.id
        ) x ON x.work_order_id = w.id
        WHERE abs(COALESCE(w.book_cost_amount, 0) - x.expected_book) > 0.01
    ) THEN
        RAISE EXCEPTION '验收失败：工作令账面快照不等于全部年度借方明细合计';
    END IF;
END $$;

DROP TABLE IF EXISTS tmp_cost_current_manual_baseline;
CREATE TEMP TABLE tmp_cost_current_manual_baseline
(
    object_name  varchar(64) NOT NULL,
    record_id    int8        NOT NULL,
    digest_value varchar(32) NOT NULL
) ON COMMIT DELETE ROWS;

INSERT INTO tmp_cost_current_manual_baseline(object_name, record_id, digest_value)
SELECT baseline.object_name, baseline.record_id,
       md5(ROW(
           basic.id, basic.project_id, basic.project_code, basic.project_name,
           basic.product_attachment_type, basic.subsystem_name, basic.quantity,
           basic.product_short_name, basic.vertical_division, basic.user_name,
           basic.acquire_method, basic.batch_category, basic.platform_series,
           basic.research_unit_id, basic.research_unit_name, basic.target_price,
           basic.competitor_unit_1, basic.competitor_price_1,
           basic.competitor_unit_2, basic.competitor_price_2,
           basic.contract_amount, basic.tax_exempt, basic.target_cost_amount,
           basic.approved_amount, basic.cycle_start, basic.cycle_end,
           basic.stage_code, basic.basic_info, basic.status, basic.remark,
           basic.import_batch_id, basic.dept_id, basic.owner_user_id,
           basic.creator, basic.create_time, basic.updater, basic.update_time, basic.deleted
       )::text)
FROM cost_sync_stage.sync_control control
JOIN cost_sync_stage.manual_field_baseline baseline
  ON baseline.batch_code = control.batch_code AND baseline.tenant_id = control.tenant_id
 AND baseline.object_name = 'project_basic'
JOIN "costree_mvp".cost_project_basic basic
  ON basic.tenant_id = control.tenant_id AND basic.id = baseline.record_id
WHERE control.id = 1
UNION ALL
SELECT baseline.object_name, baseline.record_id,
       md5(ROW(
           project.id, project.project_code, project.batch_no, project.stage_codes,
           project.unit_id, project.unit_name, project.unit_type,
           project.project_office_status, project.unit_fill_status, project.audit_status,
           project.dept_id, project.owner_user_id, project.warning_status,
           project.remark
       )::text)
FROM cost_sync_stage.sync_control control
JOIN cost_sync_stage.manual_field_baseline baseline
  ON baseline.batch_code = control.batch_code AND baseline.tenant_id = control.tenant_id
 AND baseline.object_name = 'project_state'
JOIN "costree_mvp".cost_project project
  ON project.tenant_id = control.tenant_id AND project.id = baseline.record_id
WHERE control.id = 1
UNION ALL
SELECT baseline.object_name, baseline.record_id,
       md5(ROW(
           unit_cost.id,
           unit_cost.target_cost_amount, unit_cost.approved_amount,
           unit_cost.salary_amount, unit_cost.material_amount, unit_cost.outsource_amount,
           unit_cost.manage_amount, unit_cost.fuel_power_amount, unit_cost.other_amount,
           unit_cost.remark, unit_cost.deleted
       )::text)
FROM cost_sync_stage.sync_control control
JOIN cost_sync_stage.manual_field_baseline baseline
  ON baseline.batch_code = control.batch_code AND baseline.tenant_id = control.tenant_id
 AND baseline.object_name = 'unit_fill'
JOIN "costree_mvp".cost_unit_cost_detail unit_cost
  ON unit_cost.tenant_id = control.tenant_id AND unit_cost.id = baseline.record_id
WHERE control.id = 1
UNION ALL
SELECT baseline.object_name, baseline.record_id,
       md5(ROW(
           work_order.id, work_order.product_target_cost,
           work_order.contract_amount, work_order.income_amount, work_order.approved_amount,
           work_order.stage_codes, work_order.max_stage_code, work_order.subsystem_name,
           work_order.product_short_name, work_order.quantity, work_order.vertical_division,
           work_order.status, work_order.remark, work_order.import_batch_id,
           work_order.dept_id, work_order.owner_user_id, work_order.deleted
       )::text)
FROM cost_sync_stage.sync_control control
JOIN cost_sync_stage.manual_field_baseline baseline
  ON baseline.batch_code = control.batch_code AND baseline.tenant_id = control.tenant_id
 AND baseline.object_name = 'work_order_fill'
JOIN "costree_mvp".cost_work_order work_order
  ON work_order.tenant_id = control.tenant_id AND work_order.id = baseline.record_id
WHERE control.id = 1
UNION ALL
SELECT baseline.object_name, baseline.record_id,
       md5(ROW(
           warning.id, warning.project_id, warning.work_order_id, warning.warning_source,
           warning.warning_title, warning.target_cost_amount, warning.actual_cost_amount,
           warning.over_amount, warning.over_rate, warning.threshold_rate,
           warning.warning_level, warning.responsible_unit_name, warning.push_status,
           warning.pushed_time, warning.receiver_scope, warning.message_id,
           warning.status, warning.remark, warning.creator, warning.create_time,
           warning.updater, warning.update_time, warning.deleted
       )::text)
FROM cost_sync_stage.sync_control control
JOIN cost_sync_stage.manual_field_baseline baseline
  ON baseline.batch_code = control.batch_code AND baseline.tenant_id = control.tenant_id
 AND baseline.object_name = 'warning_state'
JOIN "costree_mvp".cost_warning_record warning
  ON warning.tenant_id = control.tenant_id AND warning.id = baseline.record_id
WHERE control.id = 1;

DO $$
DECLARE
    v_mismatch text;
BEGIN
    SELECT string_agg(baseline.object_name || '#' || baseline.record_id::text, ', ')
      INTO v_mismatch
    FROM cost_sync_stage.sync_control control
    JOIN cost_sync_stage.manual_field_baseline baseline
      ON baseline.batch_code = control.batch_code
     AND baseline.tenant_id = control.tenant_id
    LEFT JOIN tmp_cost_current_manual_baseline current_baseline
      ON current_baseline.object_name = baseline.object_name
     AND current_baseline.record_id = baseline.record_id
    WHERE control.id = 1
      AND (current_baseline.record_id IS NULL
           OR baseline.digest_value <> current_baseline.digest_value);

    IF v_mismatch IS NOT NULL THEN
        RAISE EXCEPTION '验收失败：常规同步改动了成本库手工字段或流程状态：%', v_mismatch;
    END IF;

    IF (SELECT count(*) FROM cost_sync_stage.sync_control control
        JOIN cost_sync_stage.manual_field_digest digest
          ON digest.batch_code = control.batch_code AND digest.tenant_id = control.tenant_id
        WHERE control.id = 1) <> 5 THEN
        RAISE EXCEPTION '验收失败：同步前手工字段摘要不完整，拒绝标记 SUCCESS';
    END IF;

    IF (SELECT COALESCE(sum(digest.row_count), 0)
        FROM cost_sync_stage.sync_control control
        JOIN cost_sync_stage.manual_field_digest digest
          ON digest.batch_code = control.batch_code AND digest.tenant_id = control.tenant_id
        WHERE control.id = 1) <>
       (SELECT count(*)
        FROM cost_sync_stage.sync_control control
        JOIN cost_sync_stage.manual_field_baseline baseline
          ON baseline.batch_code = control.batch_code AND baseline.tenant_id = control.tenant_id
        WHERE control.id = 1) THEN
        RAISE EXCEPTION '验收失败：手工字段摘要与逐行基线不一致';
    END IF;
END $$;

UPDATE cost_sync_stage.sync_control
SET load_status = 'SUCCESS',
    synced_at = CURRENT_TIMESTAMP,
    remark = '业务同步、借方账面快照重算和最终验收完成'
WHERE id = 1;

UPDATE cost_sync_stage.sync_history h
SET sync_status = 'SUCCESS',
    finish_time = CURRENT_TIMESTAMP,
    remark = '业务同步、借方账面快照重算和最终验收完成'
FROM cost_sync_stage.sync_control c
WHERE c.id = 1
  AND h.batch_code = c.batch_code
  AND h.tenant_id = c.tenant_id;

COMMIT;

SELECT 'sync accepted' AS result, tenant_id, batch_code, load_status, loaded_at, synced_at
FROM cost_sync_stage.sync_control
WHERE id = 1;

SELECT 'unit_dict' AS object_name, count(*) AS stage_rows
FROM cost_sync_stage.stg_unit_dict
UNION ALL SELECT 'model_node', count(*) FROM cost_sync_stage.stg_model_node
UNION ALL SELECT 'project', count(*) FROM cost_sync_stage.stg_project
UNION ALL SELECT 'unit_amount', count(*) FROM cost_sync_stage.stg_unit_amount
UNION ALL SELECT 'work_order', count(*) FROM cost_sync_stage.stg_work_order
UNION ALL SELECT 'ledger_detail', count(*) FROM cost_sync_stage.stg_ledger_detail
ORDER BY object_name;

SELECT d.debit_credit, count(*) AS detail_count,
       sum(COALESCE(d.amount_wan, d.amount / 10000.0)) AS amount_wan
FROM "costree_mvp".cost_work_order_ledger_detail d
JOIN cost_sync_stage.stg_ledger_detail s ON s.source_detail_id = d.source_detail_id
CROSS JOIN cost_sync_stage.sync_control c
WHERE c.id = 1 AND d.tenant_id = c.tenant_id AND d.deleted = 0
GROUP BY d.debit_credit
ORDER BY d.debit_credit;

SELECT
    COALESCE(substr(NULLIF(d.second_subject_code, ''), 1, 6), substr(NULLIF(d.subject_code, ''), 1, 6), 'UNCLASSIFIED') AS item_code,
    count(*) AS detail_count,
    sum(COALESCE(d.amount_wan, d.amount / 10000.0)) AS amount_wan
FROM "costree_mvp".cost_work_order_ledger_detail d
JOIN cost_sync_stage.stg_ledger_detail s ON s.source_detail_id = d.source_detail_id
CROSS JOIN cost_sync_stage.sync_control c
WHERE c.id = 1 AND d.tenant_id = c.tenant_id
  AND d.deleted = 0 AND d.debit_credit = '借'
GROUP BY COALESCE(substr(NULLIF(d.second_subject_code, ''), 1, 6), substr(NULLIF(d.subject_code, ''), 1, 6), 'UNCLASSIFIED')
ORDER BY item_code;

SELECT batch_code, tenant_id, stage_row_count, sync_status, start_time, finish_time, remark
FROM cost_sync_stage.sync_history
ORDER BY start_time DESC;
