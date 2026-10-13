-- 成本库内网分表同步 08：全链路验收（只读）
-- status=OK 才可认为本轮同步通过；DETAIL 表示需人工核对明细。

DROP TABLE IF EXISTS tmp_manual_context;
CREATE TEMP TABLE tmp_manual_context ON COMMIT PRESERVE ROWS AS
SELECT 124::int8 AS tenant_id;

-- 1. 核心业务键、关联和金额换算验收。error_count 应全部为 0。
SELECT check_item, error_count,
       CASE WHEN error_count = 0 THEN 'OK' ELSE 'ERROR' END AS status
FROM (
    SELECT '01_node_code_duplicate'::varchar(64) AS check_item, count(*)::int8 AS error_count
    FROM (
        SELECT node_code FROM cost_model_node n CROSS JOIN tmp_manual_context c
        WHERE n.tenant_id = c.tenant_id AND n.deleted = 0
        GROUP BY node_code HAVING count(*) > 1
    ) x
    UNION ALL
    SELECT '02_node_parent_missing', count(*)::int8
    FROM cost_model_node n CROSS JOIN tmp_manual_context c
    WHERE n.tenant_id = c.tenant_id AND n.deleted = 0 AND n.parent_id <> 0
      AND NOT EXISTS (
          SELECT 1 FROM cost_model_node p
          WHERE p.tenant_id = c.tenant_id AND p.deleted = 0 AND p.id = n.parent_id
      )
    UNION ALL
    SELECT '03_project_code_duplicate', count(*)::int8
    FROM (
        SELECT project_code FROM cost_project p CROSS JOIN tmp_manual_context c
        WHERE p.tenant_id = c.tenant_id AND p.deleted = 0
        GROUP BY project_code HAVING count(*) > 1
    ) x
    UNION ALL
    SELECT '04_project_model_missing', count(*)::int8
    FROM cost_project p CROSS JOIN tmp_manual_context c
    WHERE p.tenant_id = c.tenant_id AND p.deleted = 0
      AND NOT EXISTS (
          SELECT 1 FROM cost_model_node n
          WHERE n.tenant_id = c.tenant_id AND n.deleted = 0
            AND n.id = p.model_node_id AND n.node_type = 'MODEL'
      )
    UNION ALL
    SELECT '05_unit_id_duplicate', count(*)::int8
    FROM (
        SELECT accounting_unit_id FROM cost_unit_dict d CROSS JOIN tmp_manual_context c
        WHERE d.tenant_id = c.tenant_id AND d.deleted = 0
        GROUP BY accounting_unit_id HAVING count(*) > 1
    ) x
    UNION ALL
    SELECT '06_unit_amount_business_duplicate', count(*)::int8
    FROM (
        SELECT project_code, unit_name
        FROM cost_unit_cost_detail d CROSS JOIN tmp_manual_context c
        WHERE d.tenant_id = c.tenant_id AND d.deleted = 0 AND d.stage_code = 'ALL'
        GROUP BY project_code, unit_name HAVING count(*) > 1
    ) x
    UNION ALL
    SELECT '07_unit_amount_project_or_unit_missing', count(*)::int8
    FROM cost_unit_cost_detail d CROSS JOIN tmp_manual_context c
    WHERE d.tenant_id = c.tenant_id AND d.deleted = 0
      AND (
          NOT EXISTS (
              SELECT 1 FROM cost_project p
              WHERE p.tenant_id = c.tenant_id AND p.deleted = 0
                AND p.project_code = d.project_code
          )
          OR NOT EXISTS (
              SELECT 1 FROM cost_unit_dict u
              WHERE u.tenant_id = c.tenant_id AND u.deleted = 0
                AND u.accounting_unit_name = d.unit_name
          )
      )
    UNION ALL
    SELECT '08_work_order_business_duplicate', count(*)::int8
    FROM (
        SELECT project_code, unit_name, work_order_no
        FROM cost_work_order w CROSS JOIN tmp_manual_context c
        WHERE w.tenant_id = c.tenant_id AND w.deleted = 0
        GROUP BY project_code, unit_name, work_order_no HAVING count(*) > 1
    ) x
    UNION ALL
    SELECT '09_work_order_source_id_duplicate', count(*)::int8
    FROM (
        SELECT source_work_order_id
        FROM cost_work_order w CROSS JOIN tmp_manual_context c
        WHERE w.tenant_id = c.tenant_id AND w.deleted = 0
          AND w.source_work_order_id IS NOT NULL AND btrim(w.source_work_order_id) <> ''
        GROUP BY source_work_order_id HAVING count(*) > 1
    ) x
    UNION ALL
    SELECT '10_work_order_project_or_unit_missing', count(*)::int8
    FROM cost_work_order w CROSS JOIN tmp_manual_context c
    WHERE w.tenant_id = c.tenant_id AND w.deleted = 0
      AND (
          NOT EXISTS (
              SELECT 1 FROM cost_project p
              WHERE p.tenant_id = c.tenant_id AND p.deleted = 0
                AND p.project_code = w.project_code
          )
          OR NOT EXISTS (
              SELECT 1 FROM cost_unit_dict u
              WHERE u.tenant_id = c.tenant_id AND u.deleted = 0
                AND u.accounting_unit_name = w.unit_name
          )
      )
    UNION ALL
    SELECT '11_work_order_fiscal_year_not_empty', count(*)::int8
    FROM cost_work_order w CROSS JOIN tmp_manual_context c
    WHERE w.tenant_id = c.tenant_id AND w.deleted = 0
      AND COALESCE(btrim(w.fiscal_year), '') <> ''
    UNION ALL
    SELECT '12_ledger_source_detail_duplicate', count(*)::int8
    FROM (
        SELECT source_detail_id
        FROM cost_work_order_ledger_detail d CROSS JOIN tmp_manual_context c
        WHERE d.tenant_id = c.tenant_id AND d.deleted = 0
        GROUP BY source_detail_id HAVING count(*) > 1
    ) x
    UNION ALL
    SELECT '13_ledger_project_or_work_order_orphan', count(*)::int8
    FROM cost_work_order_ledger_detail d CROSS JOIN tmp_manual_context c
    WHERE d.tenant_id = c.tenant_id AND d.deleted = 0
      AND (
          NOT EXISTS (
              SELECT 1 FROM cost_project p
              WHERE p.tenant_id = c.tenant_id AND p.deleted = 0 AND p.id = d.project_id
          )
          OR NOT EXISTS (
              SELECT 1 FROM cost_work_order w
              WHERE w.tenant_id = c.tenant_id AND w.deleted = 0 AND w.id = d.work_order_id
          )
      )
    UNION ALL
    SELECT '14_ledger_amount_conversion_error', count(*)::int8
    FROM cost_work_order_ledger_detail d CROSS JOIN tmp_manual_context c
    WHERE d.tenant_id = c.tenant_id AND d.deleted = 0
      AND abs(COALESCE(d.amount_wan, 0) - COALESCE(d.amount, 0) / 10000.0) > 0.01
    UNION ALL
    SELECT '15_work_order_book_snapshot_error', count(*)::int8
    FROM cost_work_order w
    CROSS JOIN tmp_manual_context c
    LEFT JOIN (
        SELECT d.work_order_id,
               sum(COALESCE(d.amount / 10000.0, d.amount_wan, 0)) AS debit_amount
        FROM cost_work_order_ledger_detail d
        CROSS JOIN tmp_manual_context c2
        WHERE d.tenant_id = c2.tenant_id AND d.deleted = 0
          AND upper(COALESCE(d.debit_credit, '')) IN ('借', 'DEBIT')
        GROUP BY d.work_order_id
    ) s ON s.work_order_id = w.id
    WHERE w.tenant_id = c.tenant_id AND w.deleted = 0
      AND abs(COALESCE(w.book_cost_amount, 0) - COALESCE(s.debit_amount, 0)) > 0.01
) checks
ORDER BY check_item;

-- 2. 八项支出口径验收：未归类金额和差额应为 0。
DROP TABLE IF EXISTS tmp_manual_ledger_category;
CREATE TEMP TABLE tmp_manual_ledger_category ON COMMIT PRESERVE ROWS AS
SELECT
    d.id, d.project_code, d.work_order_id,
    COALESCE(d.amount / 10000.0, d.amount_wan, 0)::numeric(18,2) AS amount_wan,
    CASE
        WHEN COALESCE(NULLIF(d.second_subject_code, ''), NULLIF(d.subject_code, '')) LIKE '501101%'
          OR COALESCE(d.second_subject_name, d.subject_name, '') LIKE '%职工%'
          OR COALESCE(d.second_subject_name, d.subject_name, '') LIKE '%薪酬%'
          OR COALESCE(d.second_subject_name, d.subject_name, '') LIKE '%劳务%' THEN '501101'
        WHEN COALESCE(NULLIF(d.second_subject_code, ''), NULLIF(d.subject_code, '')) LIKE '501102%'
          OR COALESCE(d.second_subject_name, d.subject_name, '') LIKE '%材料%' THEN '501102'
        WHEN COALESCE(NULLIF(d.second_subject_code, ''), NULLIF(d.subject_code, '')) LIKE '501103%'
          OR COALESCE(d.second_subject_name, d.subject_name, '') LIKE '%专用%' THEN '501103'
        WHEN COALESCE(NULLIF(d.second_subject_code, ''), NULLIF(d.subject_code, '')) LIKE '501104%'
          OR COALESCE(d.second_subject_name, d.subject_name, '') LIKE '%外协%' THEN '501104'
        WHEN COALESCE(NULLIF(d.second_subject_code, ''), NULLIF(d.subject_code, '')) LIKE '501105%'
          OR COALESCE(d.second_subject_name, d.subject_name, '') LIKE '%燃料%'
          OR COALESCE(d.second_subject_name, d.subject_name, '') LIKE '%动力%' THEN '501105'
        WHEN COALESCE(NULLIF(d.second_subject_code, ''), NULLIF(d.subject_code, '')) LIKE '501106%'
          OR COALESCE(d.second_subject_name, d.subject_name, '') LIKE '%事务%' THEN '501106'
        WHEN COALESCE(NULLIF(d.second_subject_code, ''), NULLIF(d.subject_code, '')) LIKE '501107%'
          OR COALESCE(d.second_subject_name, d.subject_name, '') LIKE '%固定资产%'
          OR COALESCE(d.second_subject_name, d.subject_name, '') LIKE '%折旧%' THEN '501107'
        WHEN COALESCE(NULLIF(d.second_subject_code, ''), NULLIF(d.subject_code, '')) LIKE '501108%'
          OR COALESCE(d.second_subject_name, d.subject_name, '') LIKE '%管理%' THEN '501108'
        ELSE NULL
    END::varchar(16) AS category_code
FROM cost_work_order_ledger_detail d
CROSS JOIN tmp_manual_context c
WHERE d.tenant_id = c.tenant_id AND d.deleted = 0
  AND upper(COALESCE(d.debit_credit, '')) IN ('借', 'DEBIT');

SELECT
    count(*) AS unclassified_debit_detail_count,
    COALESCE(sum(amount_wan), 0) AS unclassified_debit_amount_wan,
    CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ERROR' END AS status
FROM tmp_manual_ledger_category
WHERE category_code IS NULL;

SELECT
    category_code,
    count(*) AS detail_count,
    sum(amount_wan) AS amount_wan
FROM tmp_manual_ledger_category
WHERE category_code IS NOT NULL
GROUP BY category_code
ORDER BY category_code;

-- 3. 页面入口级汇总，用于人工抽查首页、目录、成本树和工作令页。
SELECT
    (SELECT count(*) FROM cost_model_node n
     WHERE n.tenant_id = c.tenant_id AND n.deleted = 0) AS model_node_count,
    (SELECT count(*) FROM cost_project p
     WHERE p.tenant_id = c.tenant_id AND p.deleted = 0) AS project_count,
    (SELECT count(*) FROM cost_unit_dict u
     WHERE u.tenant_id = c.tenant_id AND u.deleted = 0) AS unit_count,
    (SELECT count(*) FROM cost_unit_cost_detail d
     WHERE d.tenant_id = c.tenant_id AND d.deleted = 0 AND d.stage_code = 'ALL')
        AS project_unit_amount_count,
    (SELECT count(*) FROM cost_work_order w
     WHERE w.tenant_id = c.tenant_id AND w.deleted = 0) AS work_order_count,
    (SELECT count(*) FROM cost_work_order_ledger_detail d
     WHERE d.tenant_id = c.tenant_id AND d.deleted = 0) AS ledger_detail_count,
    (SELECT COALESCE(sum(w.book_cost_amount), 0) FROM cost_work_order w
     WHERE w.tenant_id = c.tenant_id AND w.deleted = 0) AS work_order_book_wan
FROM tmp_manual_context c;
