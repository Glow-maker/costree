-- 成本库外部数据源闭环演示对账（PostgreSQL）
-- 本脚本只读；任一核心断言不满足时会抛出异常。

DO $$
DECLARE
    v_tenant_id int8 := (SELECT tenant_id FROM cost_demo_source.demo_config WHERE id = 1);
    v_count int8;
    v_amount numeric(18,2);
BEGIN
    SELECT count(*) INTO v_count FROM cost_demo_source.unit_dict;
    IF v_count <> 15 THEN RAISE EXCEPTION '源单位字典预期 15 行，实际 %', v_count; END IF;

    SELECT count(*) INTO v_count FROM cost_demo_source.ads_lc_lshsxm2022;
    IF v_count <> 4 THEN RAISE EXCEPTION '源项目树预期 4 行，实际 %', v_count; END IF;

    SELECT count(*) INTO v_count FROM cost_demo_source.dwd_bd_bfcustomitem_gzl;
    IF v_count <> 15 THEN RAISE EXCEPTION '源工作令映射预期 15 行，实际 %', v_count; END IF;

    SELECT count(*) INTO v_count FROM cost_demo_source.precontrol_project_unit_amount;
    IF v_count <> 16 THEN RAISE EXCEPTION '源预分预控金额预期 16 行，实际 %', v_count; END IF;

    SELECT count(*) INTO v_count FROM cost_demo_source.work_order_fill;
    IF v_count <> 18 THEN RAISE EXCEPTION '源工作令年度补充预期 18 行，实际 %', v_count; END IF;

    SELECT count(*) INTO v_count FROM cost_demo_source.dws_bu_pz_pzmx_gzl;
    IF v_count <> 24 THEN RAISE EXCEPTION '源账面明细预期 24 行，实际 %', v_count; END IF;

    SELECT count(*) INTO v_count
    FROM public.cost_project
    WHERE tenant_id = v_tenant_id AND deleted = 0
      AND project_code IN ('ZY-2026-DEMO-UNIT-001', 'ZY-2026-DEMO-YEAR-002');
    IF v_count <> 2 THEN RAISE EXCEPTION '业务项目预期 2 行，实际 %', v_count; END IF;

    SELECT count(*) INTO v_count
    FROM public.cost_project_basic
    WHERE tenant_id = v_tenant_id AND deleted = 0
      AND project_code IN ('ZY-2026-DEMO-UNIT-001', 'ZY-2026-DEMO-YEAR-002');
    IF v_count <> 2 THEN RAISE EXCEPTION '项目基本信息预期 2 行，实际 %', v_count; END IF;

    SELECT count(*) INTO v_count
    FROM public.cost_unit_cost_detail
    WHERE tenant_id = v_tenant_id AND deleted = 0
      AND project_code IN ('ZY-2026-DEMO-UNIT-001', 'ZY-2026-DEMO-YEAR-002');
    IF v_count <> 16 THEN RAISE EXCEPTION '项目单位金额预期 16 行，实际 %', v_count; END IF;

    SELECT count(*) INTO v_count
    FROM public.cost_work_order
    WHERE tenant_id = v_tenant_id AND deleted = 0
      AND project_code IN ('ZY-2026-DEMO-UNIT-001', 'ZY-2026-DEMO-YEAR-002');
    IF v_count <> 15 THEN RAISE EXCEPTION '逻辑工作令预期 15 行，实际 %', v_count; END IF;

    SELECT count(*) INTO v_count
    FROM public.cost_work_order_ledger_detail
    WHERE tenant_id = v_tenant_id AND deleted = 0
      AND project_code IN ('ZY-2026-DEMO-UNIT-001', 'ZY-2026-DEMO-YEAR-002');
    IF v_count <> 24 THEN RAISE EXCEPTION '标准账面明细预期 24 行，实际 %', v_count; END IF;

    SELECT count(*) INTO v_count
    FROM public.cost_work_order_ledger_detail
    WHERE tenant_id = v_tenant_id AND deleted = 0
      AND project_code IN ('ZY-2026-DEMO-UNIT-001', 'ZY-2026-DEMO-YEAR-002')
      AND btrim(debit_credit) = '贷';
    IF v_count <> 2 THEN RAISE EXCEPTION '贷方明细预期 2 行，实际 %', v_count; END IF;

    SELECT round(sum(amount / 10000.0), 2) INTO v_amount
    FROM public.cost_work_order_ledger_detail
    WHERE tenant_id = v_tenant_id AND deleted = 0
      AND project_code IN ('ZY-2026-DEMO-UNIT-001', 'ZY-2026-DEMO-YEAR-002')
      AND btrim(debit_credit) = '借';
    IF v_amount IS DISTINCT FROM 13470.00::numeric THEN
        RAISE EXCEPTION '借方账面预期 13470.00 万元，实际 %', v_amount;
    END IF;

    SELECT round(sum(book_cost_amount), 2) INTO v_amount
    FROM public.cost_work_order
    WHERE tenant_id = v_tenant_id AND deleted = 0
      AND project_code IN ('ZY-2026-DEMO-UNIT-001', 'ZY-2026-DEMO-YEAR-002');
    IF v_amount IS DISTINCT FROM 13470.00::numeric THEN
        RAISE EXCEPTION '逻辑工作令跨年度快照预期 13470.00 万元，实际 %', v_amount;
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.cost_work_order_ledger_detail
        WHERE tenant_id = v_tenant_id AND deleted = 0
          AND project_code IN ('ZY-2026-DEMO-UNIT-001', 'ZY-2026-DEMO-YEAR-002')
          AND abs(COALESCE(amount_wan, 0) - COALESCE(amount, 0) / 10000.0) > 0.01
    ) THEN
        RAISE EXCEPTION '存在 amount 与 amount_wan 换算不一致的账面明细';
    END IF;

    SELECT round(sum(c.target_cost_amount), 2) INTO v_amount
    FROM public.cost_unit_cost_detail c
    JOIN public.cost_unit_dict d ON d.tenant_id = c.tenant_id AND d.deleted = 0
      AND d.accounting_unit_name = c.unit_name
    WHERE c.tenant_id = v_tenant_id AND c.deleted = 0
      AND c.project_code = 'ZY-2026-DEMO-UNIT-001' AND d.inside_institute = true;
    IF v_amount IS DISTINCT FROM 12470.00::numeric THEN
        RAISE EXCEPTION '单位层级项目院内目标预期 12470.00 万元，实际 %', v_amount;
    END IF;

    SELECT round(sum(w.book_cost_amount), 2) INTO v_amount
    FROM public.cost_work_order w
    WHERE w.tenant_id = v_tenant_id AND w.deleted = 0
      AND w.project_code = 'ZY-2026-DEMO-UNIT-001';
    IF v_amount IS DISTINCT FROM 12470.00::numeric THEN
        RAISE EXCEPTION '单位层级项目院内账面预期 12470.00 万元，实际 %', v_amount;
    END IF;

    SELECT count(*) INTO v_count
    FROM (
        SELECT DISTINCT d.manage_unit_name
        FROM public.cost_unit_cost_detail c
        JOIN public.cost_unit_dict d ON d.tenant_id = c.tenant_id AND d.deleted = 0
          AND d.accounting_unit_name = c.unit_name
        WHERE c.tenant_id = v_tenant_id AND c.deleted = 0
          AND c.project_code = 'ZY-2026-DEMO-UNIT-001' AND d.inside_institute = true
    ) x;
    IF v_count <> 12 THEN RAISE EXCEPTION '院内管理单位预期 12 家，实际 %', v_count; END IF;

    SELECT count(*) INTO v_count
    FROM public.cost_unit_cost_detail c
    JOIN public.cost_unit_dict d ON d.tenant_id = c.tenant_id AND d.deleted = 0
      AND d.accounting_unit_name = c.unit_name
    WHERE c.tenant_id = v_tenant_id AND c.deleted = 0
      AND c.project_code = 'ZY-2026-DEMO-UNIT-001'
      AND d.inside_institute = true AND d.manage_unit_name = '电子所';
    IF v_count <> 3 THEN RAISE EXCEPTION '电子所预期聚合 3 个核算单位，实际 %', v_count; END IF;

    SELECT round(sum(book_cost_amount), 2) INTO v_amount
    FROM public.cost_work_order
    WHERE tenant_id = v_tenant_id AND deleted = 0
      AND project_code = 'ZY-2026-DEMO-YEAR-002'
      AND work_order_no = 'DEMO-YEAR-WO-01';
    IF v_amount IS DISTINCT FROM 1000.00::numeric THEN
        RAISE EXCEPTION '跨年工作令合计预期 1000.00 万元，实际 %', v_amount;
    END IF;

    SELECT count(*) INTO v_count
    FROM public.cost_work_order
    WHERE tenant_id = v_tenant_id AND deleted = 0
      AND project_code = 'ZY-2026-DEMO-YEAR-002'
      AND work_order_no = 'DEMO-YEAR-WO-01';
    IF v_count <> 1 THEN RAISE EXCEPTION '跨年度项目应只有 1 条逻辑工作令，实际 %', v_count; END IF;

    SELECT count(*) INTO v_count
    FROM (
        SELECT COALESCE(NULLIF(second_subject_code, ''), subject_code) AS item_code
        FROM public.cost_work_order_ledger_detail
        WHERE tenant_id = v_tenant_id AND deleted = 0
          AND project_code IN ('ZY-2026-DEMO-UNIT-001', 'ZY-2026-DEMO-YEAR-002')
          AND btrim(debit_credit) = '借'
        GROUP BY COALESCE(NULLIF(second_subject_code, ''), subject_code)
    ) x;
    IF v_count <> 8 THEN RAISE EXCEPTION '八项账面组成预期 8 项，实际 %', v_count; END IF;

    IF EXISTS (
        SELECT 1 FROM public.cost_work_order_ledger_detail
        WHERE tenant_id = v_tenant_id AND deleted = 0
          AND project_code IN ('ZY-2026-DEMO-UNIT-001', 'ZY-2026-DEMO-YEAR-002')
          AND (project_id IS NULL OR work_order_id IS NULL)
    ) THEN
        RAISE EXCEPTION '标准账面明细存在未解析项目或工作令';
    END IF;
END $$;

-- 1. 源表与业务表记录数。
SELECT 'source_total' AS item, 84::numeric AS expected, sum(row_count)::numeric AS actual
FROM (
    SELECT count(*) AS row_count FROM cost_demo_source.unit_dict
    UNION ALL SELECT count(*) FROM cost_demo_source.ads_lc_lshsxm2022
    UNION ALL SELECT count(*) FROM cost_demo_source.dwd_bd_bfcustomitem_gzl
    UNION ALL SELECT count(*) FROM cost_demo_source.precontrol_project_unit_amount
    UNION ALL SELECT count(*) FROM cost_demo_source.project_office_fill
    UNION ALL SELECT count(*) FROM cost_demo_source.work_order_fill
    UNION ALL SELECT count(*) FROM cost_demo_source.dws_bu_pz_pzmx_gzl
) x
UNION ALL
SELECT 'target_projects', 2, count(*) FROM public.cost_project p
WHERE p.tenant_id = (SELECT tenant_id FROM cost_demo_source.demo_config WHERE id = 1)
  AND p.deleted = 0 AND p.project_code IN ('ZY-2026-DEMO-UNIT-001', 'ZY-2026-DEMO-YEAR-002')
UNION ALL
SELECT 'target_unit_amounts', 14, count(*) FROM public.cost_unit_cost_detail c
WHERE c.tenant_id = (SELECT tenant_id FROM cost_demo_source.demo_config WHERE id = 1)
  AND c.deleted = 0 AND c.project_code IN ('ZY-2026-DEMO-UNIT-001', 'ZY-2026-DEMO-YEAR-002')
UNION ALL
SELECT 'target_logical_work_orders', 13, count(*) FROM public.cost_work_order w
WHERE w.tenant_id = (SELECT tenant_id FROM cost_demo_source.demo_config WHERE id = 1)
  AND w.deleted = 0 AND w.project_code IN ('ZY-2026-DEMO-UNIT-001', 'ZY-2026-DEMO-YEAR-002')
UNION ALL
SELECT 'target_ledger_details', 22, count(*) FROM public.cost_work_order_ledger_detail d
WHERE d.tenant_id = (SELECT tenant_id FROM cost_demo_source.demo_config WHERE id = 1)
  AND d.deleted = 0 AND d.project_code IN ('ZY-2026-DEMO-UNIT-001', 'ZY-2026-DEMO-YEAR-002');

-- 2. 两个项目的预分预控金额与借方账面。
SELECT p.project_code, p.project_name,
       sum(c.contract_amount) AS contract_amount,
       sum(c.income_amount) AS income_amount,
       sum(c.target_cost_amount) AS target_cost_amount,
       sum(c.approved_amount) AS approved_amount,
       (SELECT sum(w.book_cost_amount) FROM public.cost_work_order w
        WHERE w.tenant_id = p.tenant_id AND w.deleted = 0 AND w.project_code = p.project_code) AS book_cost_amount
FROM public.cost_project p
JOIN public.cost_unit_cost_detail c ON c.tenant_id = p.tenant_id AND c.deleted = 0
  AND c.project_code = p.project_code
WHERE p.tenant_id = (SELECT tenant_id FROM cost_demo_source.demo_config WHERE id = 1)
  AND p.deleted = 0 AND p.project_code IN ('ZY-2026-DEMO-UNIT-001', 'ZY-2026-DEMO-YEAR-002')
GROUP BY p.tenant_id, p.project_code, p.project_name
ORDER BY p.project_code;

-- 3. 单位层级项目管理单位使用率和预警级别。
WITH unit_amount AS (
    SELECT d.manage_unit_group, d.manage_unit_name,
           sum(c.target_cost_amount) AS target_amount,
           sum(COALESCE((SELECT sum(w.book_cost_amount) FROM public.cost_work_order w
                        WHERE w.tenant_id = c.tenant_id AND w.deleted = 0
                          AND w.project_code = c.project_code AND w.unit_name = c.unit_name), 0)) AS book_amount
    FROM public.cost_unit_cost_detail c
    JOIN public.cost_unit_dict d ON d.tenant_id = c.tenant_id AND d.deleted = 0
      AND d.accounting_unit_name = c.unit_name
    WHERE c.tenant_id = (SELECT tenant_id FROM cost_demo_source.demo_config WHERE id = 1)
      AND c.deleted = 0 AND c.project_code = 'ZY-2026-DEMO-UNIT-001'
      AND d.inside_institute = true
    GROUP BY d.manage_unit_group, d.manage_unit_name
)
SELECT manage_unit_group, manage_unit_name, target_amount, book_amount,
       round(CASE WHEN target_amount > 0 THEN book_amount * 100.0 / target_amount ELSE 0 END, 1) AS usage_rate,
       CASE WHEN target_amount <= 0 OR book_amount <= target_amount THEN 'NORMAL'
            WHEN book_amount <= target_amount * 1.2 THEN 'YELLOW'
            ELSE 'RED' END AS warning_level
FROM unit_amount
ORDER BY usage_rate DESC, manage_unit_name;

-- 4. 跨年工作令仍由账面明细按年度核对；逻辑工作令自身只有一条跨年快照。
SELECT fiscal_year, work_order_no,
       round(sum(COALESCE(amount / 10000.0, amount_wan, 0)), 2) AS book_cost_amount
FROM public.cost_work_order_ledger_detail
WHERE tenant_id = (SELECT tenant_id FROM cost_demo_source.demo_config WHERE id = 1)
  AND deleted = 0 AND project_code = 'ZY-2026-DEMO-YEAR-002'
  AND btrim(debit_credit) = '借'
GROUP BY fiscal_year, work_order_no
ORDER BY fiscal_year;

-- 5. 两个项目合计八项借方组成；贷方不会进入本结果。
SELECT COALESCE(NULLIF(second_subject_code, ''), subject_code) AS item_code,
       COALESCE(NULLIF(second_subject_name, ''), subject_name) AS item_name,
       round(sum(COALESCE(amount / 10000.0, amount_wan, 0)), 2) AS amount_wan,
       count(*) AS ledger_detail_count
FROM public.cost_work_order_ledger_detail
WHERE tenant_id = (SELECT tenant_id FROM cost_demo_source.demo_config WHERE id = 1)
  AND deleted = 0 AND btrim(debit_credit) = '借'
  AND project_code IN ('ZY-2026-DEMO-UNIT-001', 'ZY-2026-DEMO-YEAR-002')
GROUP BY COALESCE(NULLIF(second_subject_code, ''), subject_code),
         COALESCE(NULLIF(second_subject_name, ''), subject_name)
ORDER BY item_code;
