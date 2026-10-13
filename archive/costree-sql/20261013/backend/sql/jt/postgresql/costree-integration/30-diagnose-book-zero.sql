-- 院内账面成本为 0 的只读诊断脚本
-- 仅查询，不修改任何业务数据；按 PostgreSQL 兼容语法编写。
-- GaussDB(DWS) 请先在内网测试库执行验证。

-- 1. 比较三个账面口径。
-- 页面当前读取 cost_work_order.book_cost_amount；
-- cost_unit_cost_detail.book_cost_amount 是历史兼容字段，不再作为权威账面来源。
SELECT tenant_id, metric_name, row_count, amount_wan
FROM (
    SELECT tenant_id, 'unit_cost_legacy_book'::varchar(64) AS metric_name,
           count(*) AS row_count,
           sum(COALESCE(book_cost_amount, 0)) AS amount_wan
    FROM cost_unit_cost_detail
    WHERE deleted = 0
    GROUP BY tenant_id

    UNION ALL

    SELECT tenant_id, 'work_order_snapshot'::varchar(64),
           count(*), sum(COALESCE(book_cost_amount, 0))
    FROM cost_work_order
    WHERE deleted = 0
    GROUP BY tenant_id

    UNION ALL

    SELECT tenant_id, 'ledger_debit'::varchar(64),
           count(*), sum(COALESCE(amount / 10000.0, amount_wan, 0))
    FROM cost_work_order_ledger_detail
    WHERE deleted = 0 AND btrim(COALESCE(debit_credit, '')) = '借'
    GROUP BY tenant_id

    UNION ALL

    SELECT tenant_id, 'ledger_all'::varchar(64),
           count(*), sum(COALESCE(amount / 10000.0, amount_wan, 0))
    FROM cost_work_order_ledger_detail
    WHERE deleted = 0
    GROUP BY tenant_id
) totals
ORDER BY tenant_id, metric_name;

-- 2. 检查借贷方向原始值。只精确值“借”进入账面成本。
SELECT tenant_id,
       '[' || COALESCE(debit_credit, '<NULL>') || ']' AS debit_credit_raw,
       count(*) AS detail_count,
       sum(COALESCE(amount / 10000.0, amount_wan, 0)) AS amount_wan
FROM cost_work_order_ledger_detail
WHERE deleted = 0
GROUP BY tenant_id, debit_credit
ORDER BY tenant_id, debit_credit_raw;

-- 3. 检查金额列。amount 应保存元，amount_wan 应等于 amount / 10000。
SELECT tenant_id,
       count(*) AS detail_count,
       sum(CASE WHEN amount IS NULL AND amount_wan IS NULL THEN 1 ELSE 0 END) AS missing_amount_count,
       sum(CASE WHEN amount IS NOT NULL
                 AND abs(COALESCE(amount_wan, 0) - round(amount / 10000.0, 2)) > 0.01
                THEN 1 ELSE 0 END) AS amount_unit_mismatch_count
FROM cost_work_order_ledger_detail
WHERE deleted = 0
GROUP BY tenant_id
ORDER BY tenant_id;

-- 4. 检查明细是否关联到有效工作令，以及关联后的业务键是否一致。
SELECT d.tenant_id,
       count(*) AS ledger_count,
       sum(CASE WHEN d.work_order_id IS NULL THEN 1 ELSE 0 END) AS missing_work_order_id_count,
       sum(CASE WHEN d.work_order_id IS NOT NULL AND w.id IS NULL THEN 1 ELSE 0 END) AS orphan_work_order_id_count,
       sum(CASE WHEN w.id IS NOT NULL
                 AND (COALESCE(d.project_code, '') <> COALESCE(w.project_code, '')
                      OR COALESCE(d.accounting_unit_name, '') <> COALESCE(w.unit_name, '')
                      OR COALESCE(d.work_order_no, '') <> COALESCE(w.work_order_no, ''))
                THEN 1 ELSE 0 END) AS business_key_mismatch_count
FROM cost_work_order_ledger_detail d
LEFT JOIN cost_work_order w
  ON w.tenant_id = d.tenant_id AND w.id = d.work_order_id AND w.deleted = 0
WHERE d.deleted = 0
GROUP BY d.tenant_id
ORDER BY d.tenant_id;

-- 5. 列出“借方明细有金额，但工作令快照仍为 0 或不一致”的工作令。
SELECT w.tenant_id, w.project_code, w.unit_name, w.work_order_no,
       COALESCE(w.book_cost_amount, 0) AS snapshot_amount_wan,
       count(d.id) AS debit_detail_count,
       COALESCE(sum(COALESCE(d.amount / 10000.0, d.amount_wan, 0)), 0) AS debit_amount_wan
FROM cost_work_order w
LEFT JOIN cost_work_order_ledger_detail d
  ON d.tenant_id = w.tenant_id
 AND d.work_order_id = w.id
 AND d.deleted = 0
 AND btrim(COALESCE(d.debit_credit, '')) = '借'
WHERE w.deleted = 0
GROUP BY w.tenant_id, w.id, w.project_code, w.unit_name, w.work_order_no, w.book_cost_amount
HAVING abs(COALESCE(w.book_cost_amount, 0)
           - COALESCE(sum(COALESCE(d.amount / 10000.0, d.amount_wan, 0)), 0)) > 0.01
ORDER BY w.tenant_id, w.project_code, w.unit_name, w.work_order_no;

-- 6. 列出无法通过工作令源主键或规范业务键命中的账面明细样例。
SELECT d.tenant_id, d.source_detail_id, d.source_work_order_id,
       d.project_code, d.accounting_unit_code, d.accounting_unit_name,
       d.work_order_no, d.debit_credit, d.amount, d.amount_wan
FROM cost_work_order_ledger_detail d
WHERE d.deleted = 0
  AND NOT EXISTS (
      SELECT 1
      FROM cost_work_order w
      WHERE w.tenant_id = d.tenant_id
        AND w.deleted = 0
        AND (
            (NULLIF(btrim(d.source_work_order_id), '') IS NOT NULL
             AND w.source_work_order_id = btrim(d.source_work_order_id))
            OR
            (w.project_code = d.project_code
             AND w.unit_name = d.accounting_unit_name
             AND w.work_order_no = d.work_order_no)
        )
  )
ORDER BY d.tenant_id, d.project_code, d.accounting_unit_name, d.work_order_no
LIMIT 100;
