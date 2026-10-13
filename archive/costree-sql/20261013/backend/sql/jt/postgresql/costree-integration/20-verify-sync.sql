-- 成本库正式数据同步核验（PostgreSQL 14+）
-- 本脚本只读。任一核心断言不满足时抛出异常。

DO $$
DECLARE
    v_tenant_id int8 := (SELECT tenant_id FROM cost_integration.sync_config WHERE id = 1);
    v_error_count int8;
BEGIN
    IF v_tenant_id IS NULL THEN
        RAISE EXCEPTION 'cost_integration.sync_config 缺少 id=1 的租户配置';
    END IF;

    SELECT count(*) INTO v_error_count
    FROM cost_integration.precontrol_project_unit_amount s
    LEFT JOIN public.cost_unit_cost_detail d
      ON d.tenant_id = v_tenant_id AND d.project_code = s.project_code
     AND d.unit_name = s.unit_name
    WHERE s.source_deleted = 0
      AND (d.id IS NULL OR d.deleted <> 0 OR d.stage_code <> 'ALL'
           OR d.contract_amount IS DISTINCT FROM s.contract_amount
           OR d.income_amount IS DISTINCT FROM s.income_amount);
    IF v_error_count > 0 THEN
        RAISE EXCEPTION '预分预控项目单位合同/到款对账失败，共 % 条', v_error_count;
    END IF;

    SELECT count(*) INTO v_error_count
    FROM cost_integration.dwd_bd_bfcustomitem_gzl s
    LEFT JOIN public.cost_work_order w
      ON w.tenant_id = v_tenant_id AND w.project_code = s.zyxmcode
     AND w.unit_name = s.accountorgname AND w.work_order_no = s.cusitemcode
    WHERE lower(btrim(COALESCE(s.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
      AND (w.id IS NULL OR w.deleted <> 0);
    IF v_error_count > 0 THEN
        RAISE EXCEPTION '工作令映射对账失败，共 % 条未落到逻辑工作令', v_error_count;
    END IF;

    SELECT count(*) INTO v_error_count
    FROM cost_integration.dws_bu_pz_pzmx_gzl s
    LEFT JOIN public.cost_work_order_ledger_detail d
      ON d.tenant_id = v_tenant_id AND d.source_detail_id = s.ysnm
    WHERE lower(btrim(COALESCE(s.source_deleted, '0'))) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
      AND (d.id IS NULL OR d.deleted <> 0 OR d.project_id IS NULL OR d.work_order_id IS NULL
           OR d.amount IS DISTINCT FROM replace(btrim(s.je), ',', '')::numeric(18,2)
           OR abs(COALESCE(d.amount_wan, 0) - replace(btrim(s.je), ',', '')::numeric / 10000.0) > 0.01);
    IF v_error_count > 0 THEN
        RAISE EXCEPTION '账面明细对账失败，共 % 条', v_error_count;
    END IF;

    SELECT count(*) INTO v_error_count
    FROM (
        SELECT tenant_id, project_code, unit_name, work_order_no
        FROM public.cost_work_order
        WHERE tenant_id = v_tenant_id AND deleted = 0
        GROUP BY tenant_id, project_code, unit_name, work_order_no
        HAVING count(*) > 1
    ) x;
    IF v_error_count > 0 THEN
        RAISE EXCEPTION '目标库仍有 % 组重复逻辑工作令', v_error_count;
    END IF;

    SELECT count(*) INTO v_error_count
    FROM (
        SELECT w.id
        FROM public.cost_work_order w
        JOIN (
            SELECT DISTINCT xmbh AS project_code, dwmc AS unit_name, gzllb AS work_order_no
            FROM cost_integration.dws_bu_pz_pzmx_gzl
        ) k ON k.project_code = w.project_code AND k.unit_name = w.unit_name
           AND k.work_order_no = w.work_order_no
        LEFT JOIN public.cost_work_order_ledger_detail d
          ON d.tenant_id = w.tenant_id AND d.deleted = 0
         AND d.project_code = w.project_code
         AND d.accounting_unit_name = w.unit_name
         AND d.work_order_no = w.work_order_no
        WHERE w.tenant_id = v_tenant_id AND w.deleted = 0
        GROUP BY w.id, w.book_cost_amount
        HAVING abs(COALESCE(w.book_cost_amount, 0) -
                   COALESCE(sum(CASE WHEN btrim(d.debit_credit) = '借'
                                     THEN COALESCE(d.amount / 10000.0, d.amount_wan, 0)
                                     ELSE 0 END), 0)) > 0.01
    ) x;
    IF v_error_count > 0 THEN
        RAISE EXCEPTION '工作令借方账面快照对账失败，共 % 条', v_error_count;
    END IF;
END $$;

SELECT tenant_id, batch_code, source_tag, update_time
FROM cost_integration.sync_config
WHERE id = 1;

SELECT source_name, row_count
FROM (
    SELECT 1 AS sort_no, 'unit_dict' AS source_name, count(*) AS row_count FROM cost_integration.unit_dict
    UNION ALL SELECT 2, 'project_tree', count(*) FROM cost_integration.ads_lc_lshsxm2022
    UNION ALL SELECT 3, 'work_order_ref', count(*) FROM cost_integration.dwd_bd_bfcustomitem_gzl
    UNION ALL SELECT 4, 'precontrol_amount', count(*) FROM cost_integration.precontrol_project_unit_amount
    UNION ALL SELECT 5, 'project_office_fill', count(*) FROM cost_integration.project_office_fill
    UNION ALL SELECT 6, 'work_order_fill', count(*) FROM cost_integration.work_order_fill
    UNION ALL SELECT 7, 'ledger_detail', count(*) FROM cost_integration.dws_bu_pz_pzmx_gzl
) x
ORDER BY sort_no;

WITH context AS (
    SELECT tenant_id FROM cost_integration.sync_config WHERE id = 1
), projects AS (
    SELECT DISTINCT lshsxm_xmbh AS project_code
    FROM cost_integration.ads_lc_lshsxm2022
    WHERE lshsxm_js = '3'
)
SELECT 'projects' AS item, count(*)::numeric AS row_count,
       NULL::numeric AS amount_wan
FROM public.cost_project p, context c
WHERE p.tenant_id = c.tenant_id AND p.deleted = 0
  AND p.project_code IN (SELECT project_code FROM projects)
UNION ALL
SELECT 'project_unit_amounts', count(*)::numeric, sum(d.target_cost_amount)
FROM public.cost_unit_cost_detail d, context c
WHERE d.tenant_id = c.tenant_id AND d.deleted = 0
  AND d.project_code IN (SELECT project_code FROM projects)
UNION ALL
SELECT 'logical_work_orders', count(*)::numeric, sum(w.book_cost_amount)
FROM public.cost_work_order w, context c
WHERE w.tenant_id = c.tenant_id AND w.deleted = 0
  AND w.project_code IN (SELECT project_code FROM projects)
UNION ALL
SELECT 'debit_ledger_details', count(*)::numeric, sum(d.amount / 10000.0)
FROM public.cost_work_order_ledger_detail d, context c
WHERE d.tenant_id = c.tenant_id AND d.deleted = 0
  AND btrim(d.debit_credit) = '借'
  AND d.project_code IN (SELECT project_code FROM projects)
UNION ALL
SELECT 'credit_ledger_details', count(*)::numeric, sum(d.amount / 10000.0)
FROM public.cost_work_order_ledger_detail d, context c
WHERE d.tenant_id = c.tenant_id AND d.deleted = 0
  AND btrim(d.debit_credit) = '贷'
  AND d.project_code IN (SELECT project_code FROM projects);

SELECT b.import_type, b.file_name, b.total_count, b.success_count, b.failure_count,
       b.status, b.update_time
FROM public.cost_import_batch b
JOIN cost_integration.sync_config c
  ON b.tenant_id = c.tenant_id AND b.file_name = c.batch_code
WHERE b.import_type = 'COST_INTEGRATION_SYNC'
ORDER BY b.id DESC
LIMIT 1;
