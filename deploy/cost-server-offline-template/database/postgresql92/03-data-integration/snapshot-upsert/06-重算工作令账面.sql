-- 按全部年度借方明细重算逻辑工作令账面快照。
-- cost_work_order.book_cost_amount 是可重建快照；单位金额表的 book_cost_amount 不更新。

BEGIN;

LOCK TABLE cost_sync_stage.sync_control IN EXCLUSIVE MODE;

DROP TABLE IF EXISTS tmp_cost_recalc_context;
CREATE TEMP TABLE tmp_cost_recalc_context ON COMMIT PRESERVE ROWS AS
SELECT tenant_id, batch_code, source_tag
FROM cost_sync_stage.sync_control
WHERE id = 1 AND load_status IN ('BUSINESS_SYNCED', 'RECALCULATED');

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM tmp_cost_recalc_context) THEN
        RAISE EXCEPTION '业务表尚未同步，必须先执行 05-业务表幂等同步.sql';
    END IF;
END $$;

DROP TABLE IF EXISTS tmp_cost_recalc_work_order;
CREATE TEMP TABLE tmp_cost_recalc_work_order ON COMMIT PRESERVE ROWS AS
SELECT DISTINCT w.id AS work_order_id
FROM cost_sync_stage.stg_work_order s
CROSS JOIN tmp_cost_recalc_context c
JOIN "costree_mvp".cost_unit_dict u
  ON u.tenant_id = c.tenant_id AND u.accounting_unit_code = s.accounting_unit_code
JOIN "costree_mvp".cost_work_order w
  ON w.tenant_id = c.tenant_id
 AND w.project_code = s.project_code
 AND w.unit_name = u.accounting_unit_name
 AND w.work_order_no = s.work_order_no
WHERE lower(btrim(COALESCE(s.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y');

-- 重新绑定本批账面明细到项目、实际单位和逻辑工作令。
DROP TABLE IF EXISTS tmp_cost_recalc_ledger_link;
CREATE TEMP TABLE tmp_cost_recalc_ledger_link ON COMMIT PRESERVE ROWS AS
SELECT
    s.source_detail_id,
    p.id AS project_id,
    p.project_name,
    u.accounting_unit_code,
    u.accounting_unit_name,
    u.manage_unit_name,
    COALESCE(
        CASE WHEN NULLIF(btrim(s.source_work_order_id), '') IS NOT NULL THEN (
            SELECT min(w1.id) FROM "costree_mvp".cost_work_order w1
            WHERE w1.tenant_id = c.tenant_id
              AND w1.source_work_order_id = btrim(s.source_work_order_id)
        ) ELSE NULL END,
        (
            SELECT min(w2.id) FROM "costree_mvp".cost_work_order w2
            WHERE w2.tenant_id = c.tenant_id
              AND w2.project_code = s.project_code
              AND w2.unit_name = u.accounting_unit_name
              AND w2.work_order_no = s.work_order_no
        )
    ) AS work_order_id
FROM cost_sync_stage.stg_ledger_detail s
CROSS JOIN tmp_cost_recalc_context c
LEFT JOIN "costree_mvp".cost_project p
  ON p.tenant_id = c.tenant_id AND p.project_code = s.project_code
LEFT JOIN "costree_mvp".cost_unit_dict u
  ON u.tenant_id = c.tenant_id AND u.accounting_unit_code = s.accounting_unit_code;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM tmp_cost_recalc_ledger_link
        WHERE project_id IS NULL OR accounting_unit_name IS NULL OR work_order_id IS NULL
    ) THEN
        RAISE EXCEPTION '本批账面明细仍有无法绑定项目、实际单位或工作令的记录';
    END IF;
END $$;

UPDATE "costree_mvp".cost_work_order_ledger_detail d
SET project_id = s.project_id,
    project_name = s.project_name,
    accounting_unit_code = s.accounting_unit_code,
    accounting_unit_name = s.accounting_unit_name,
    manage_unit_name = s.manage_unit_name,
    work_order_id = s.work_order_id,
    source_work_order_id = COALESCE(w.source_work_order_id, d.source_work_order_id),
    work_order_no = w.work_order_no,
    work_order_name = COALESCE(d.work_order_name, w.work_order_name),
    resolved_stage_code = w.max_stage_code,
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_cost_recalc_ledger_link s
CROSS JOIN tmp_cost_recalc_context c
JOIN "costree_mvp".cost_work_order w ON w.id = s.work_order_id
WHERE d.tenant_id = c.tenant_id
  AND d.source_detail_id = s.source_detail_id;

-- 先把本批活动工作令清零，确保“无借方明细”的工作令不会保留旧账面。
UPDATE "costree_mvp".cost_work_order w
SET book_cost_amount = 0,
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_cost_recalc_work_order a
CROSS JOIN tmp_cost_recalc_context c
WHERE w.id = a.work_order_id;

UPDATE "costree_mvp".cost_work_order w
SET book_cost_amount = a.book_cost_amount,
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM (
    SELECT d.work_order_id,
           sum(COALESCE(d.amount_wan, d.amount / 10000.0))::numeric(18,2) AS book_cost_amount
    FROM "costree_mvp".cost_work_order_ledger_detail d
    JOIN tmp_cost_recalc_work_order x ON x.work_order_id = d.work_order_id
    CROSS JOIN tmp_cost_recalc_context c
    WHERE d.tenant_id = c.tenant_id
      AND d.deleted = 0
      AND d.debit_credit = '借'
    GROUP BY d.work_order_id
) a
CROSS JOIN tmp_cost_recalc_context c
WHERE w.id = a.work_order_id;

UPDATE cost_sync_stage.sync_control
SET load_status = 'RECALCULATED',
    synced_at = CURRENT_TIMESTAMP,
    remark = '业务同步和借方账面快照重算完成，等待最终验收'
WHERE id = 1;

UPDATE cost_sync_stage.sync_history h
SET sync_status = 'RECALCULATED',
    finish_time = NULL,
    remark = '业务同步和借方账面快照重算完成，等待最终验收'
FROM tmp_cost_recalc_context c
WHERE h.batch_code = c.batch_code AND h.tenant_id = c.tenant_id;

COMMIT;

SELECT count(*) AS recalculated_work_order_count,
       sum(COALESCE(w.book_cost_amount, 0)) AS total_book_cost_wan
FROM "costree_mvp".cost_work_order w
JOIN tmp_cost_recalc_work_order x ON x.work_order_id = w.id;

SELECT d.debit_credit, count(*) AS detail_count,
       sum(COALESCE(d.amount_wan, d.amount / 10000.0)) AS amount_wan
FROM "costree_mvp".cost_work_order_ledger_detail d
JOIN tmp_cost_recalc_work_order x ON x.work_order_id = d.work_order_id
WHERE d.deleted = 0
GROUP BY d.debit_credit
ORDER BY d.debit_credit;
