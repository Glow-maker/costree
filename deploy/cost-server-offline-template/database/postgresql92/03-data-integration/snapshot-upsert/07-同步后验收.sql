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
