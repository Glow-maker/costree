-- 成本库内网分表同步 07：重算工作令跨年度借方账面快照
-- 执行前提：01-06 均已验收通过。
-- 账面唯一事实源为 cost_work_order_ledger_detail；贷方不进入快照。

BEGIN;
SELECT pg_advisory_xact_lock(hashtext('costree-manual-book-snapshot-rebuild'));

DROP TABLE IF EXISTS tmp_manual_context;
CREATE TEMP TABLE tmp_manual_context ON COMMIT PRESERVE ROWS AS
SELECT 124::int8 AS tenant_id, 'manual_book_rebuild'::varchar(64) AS source_tag;

DROP TABLE IF EXISTS tmp_manual_ledger_resolution;
CREATE TEMP TABLE tmp_manual_ledger_resolution ON COMMIT PRESERVE ROWS AS
SELECT
    d.id AS ledger_id,
    p.id AS resolved_project_id,
    COALESCE(
        CASE WHEN d.source_work_order_id IS NOT NULL AND btrim(d.source_work_order_id) <> ''
            THEN (
                SELECT min(w.id) FROM cost_work_order w
                WHERE w.tenant_id = c.tenant_id
                  AND w.source_work_order_id = d.source_work_order_id
                  AND w.deleted = 0
            )
            ELSE NULL
        END,
        (
            SELECT min(w.id) FROM cost_work_order w
            WHERE w.tenant_id = c.tenant_id
              AND w.deleted = 0
              AND w.project_code = d.project_code
              AND w.unit_name = d.accounting_unit_name
              AND w.work_order_no = d.work_order_no
        )
    ) AS resolved_work_order_id
FROM cost_work_order_ledger_detail d
CROSS JOIN tmp_manual_context c
LEFT JOIN cost_project p
  ON p.tenant_id = c.tenant_id AND p.deleted = 0
 AND p.project_code = d.project_code
WHERE d.tenant_id = c.tenant_id
  AND d.deleted = 0;

-- 导入前检查：下面三张清单必须为空，否则回滚并修正 01-06 的字段映射。
SELECT d.id, d.source_detail_id, d.project_code
FROM cost_work_order_ledger_detail d
JOIN tmp_manual_ledger_resolution r ON r.ledger_id = d.id
WHERE r.resolved_project_id IS NULL
ORDER BY d.id;

SELECT d.id, d.source_detail_id, d.accounting_unit_code, d.accounting_unit_name
FROM cost_work_order_ledger_detail d
CROSS JOIN tmp_manual_context c
WHERE d.tenant_id = c.tenant_id AND d.deleted = 0
  AND NOT EXISTS (
      SELECT 1 FROM cost_unit_dict u
      WHERE u.tenant_id = c.tenant_id AND u.deleted = 0
        AND u.accounting_unit_code = d.accounting_unit_code
        AND u.accounting_unit_name = d.accounting_unit_name
  )
ORDER BY d.id;

SELECT d.id, d.source_detail_id, d.source_work_order_id,
       d.project_code, d.accounting_unit_name, d.work_order_no
FROM cost_work_order_ledger_detail d
JOIN tmp_manual_ledger_resolution r ON r.ledger_id = d.id
WHERE r.resolved_work_order_id IS NULL
ORDER BY d.id;

DO $$
DECLARE
    v_tenant_id int8 := (SELECT tenant_id FROM tmp_manual_context);
BEGIN
    IF EXISTS (
        SELECT 1 FROM tmp_manual_ledger_resolution
        WHERE resolved_project_id IS NULL OR resolved_work_order_id IS NULL
    ) THEN
        RAISE EXCEPTION '存在无法关联项目或工作令的账面明细，已停止账面重算';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM cost_work_order_ledger_detail d
        CROSS JOIN tmp_manual_context c
        WHERE d.tenant_id = c.tenant_id AND d.deleted = 0
          AND NOT EXISTS (
              SELECT 1 FROM cost_unit_dict u
              WHERE u.tenant_id = c.tenant_id AND u.deleted = 0
                AND u.accounting_unit_code = d.accounting_unit_code
                AND u.accounting_unit_name = d.accounting_unit_name
          )
    ) THEN
        RAISE EXCEPTION '存在无法匹配实际核算单位的账面明细，已停止账面重算';
    END IF;

    IF EXISTS (
        SELECT project_code, unit_name, work_order_no
        FROM cost_work_order
        WHERE tenant_id = v_tenant_id AND deleted = 0
        GROUP BY project_code, unit_name, work_order_no HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '工作令业务键重复，不能安全重算账面快照';
    END IF;
END $$;

UPDATE cost_work_order_ledger_detail d
SET project_id = r.resolved_project_id,
    work_order_id = r.resolved_work_order_id,
    resolved_stage_code = w.max_stage_code,
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_manual_ledger_resolution r
JOIN cost_work_order w ON w.id = r.resolved_work_order_id
CROSS JOIN tmp_manual_context c
WHERE d.id = r.ledger_id;

DROP TABLE IF EXISTS tmp_manual_book_snapshot;
CREATE TEMP TABLE tmp_manual_book_snapshot ON COMMIT PRESERVE ROWS AS
SELECT
    d.work_order_id,
    sum(COALESCE(d.amount / 10000.0, d.amount_wan, 0))::numeric(18,2) AS book_cost_amount
FROM cost_work_order_ledger_detail d
CROSS JOIN tmp_manual_context c
WHERE d.tenant_id = c.tenant_id
  AND d.deleted = 0
  AND upper(COALESCE(d.debit_credit, '')) IN ('借', 'DEBIT')
GROUP BY d.work_order_id;

-- 账面明细是唯一事实源：没有借方明细的工作令快照归零。
UPDATE cost_work_order w
SET book_cost_amount = 0,
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_manual_context c
WHERE w.tenant_id = c.tenant_id
  AND w.deleted = 0;

UPDATE cost_work_order w
SET book_cost_amount = s.book_cost_amount,
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_manual_book_snapshot s
CROSS JOIN tmp_manual_context c
WHERE w.tenant_id = c.tenant_id
  AND w.id = s.work_order_id;

-- 导入后验收：必须为空。跨年度数据按同一 work_order_id 自动合计。
SELECT
    w.id, w.project_code, w.unit_name, w.work_order_no,
    w.book_cost_amount AS snapshot_amount,
    COALESCE(s.book_cost_amount, 0) AS ledger_debit_amount
FROM cost_work_order w
CROSS JOIN tmp_manual_context c
LEFT JOIN tmp_manual_book_snapshot s ON s.work_order_id = w.id
WHERE w.tenant_id = c.tenant_id AND w.deleted = 0
  AND abs(COALESCE(w.book_cost_amount, 0) - COALESCE(s.book_cost_amount, 0)) > 0.01
ORDER BY w.project_code, w.unit_name, w.work_order_no;

COMMIT;
