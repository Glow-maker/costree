-- 内网正式源数据同步到成本库业务表（PostgreSQL 9.2 兼容版）
-- 可重复执行。任一校验失败时整批回滚。

BEGIN;

-- DWS 兼容模式不依赖跨分布键唯一索引，因此所有正式同步批次必须串行执行。
SELECT pg_advisory_xact_lock(hashtext('costree-data-integration-sync'));

DROP TABLE IF EXISTS tmp_sync_context;
CREATE TEMP TABLE tmp_sync_context ON COMMIT DELETE ROWS AS
SELECT tenant_id, batch_code, source_tag
FROM cost_integration.sync_config
WHERE id = 1;

DO $$
DECLARE
    v_tenant_id int8;
BEGIN
    IF (SELECT count(*) FROM tmp_sync_context) <> 1 THEN
        RAISE EXCEPTION 'cost_integration.sync_config 必须且只能有一条 id=1 的配置';
    END IF;
    SELECT tenant_id INTO v_tenant_id FROM tmp_sync_context;

    IF EXISTS (
        SELECT 1
        FROM (VALUES ('cost_project'), ('cost_work_order'),
                     ('cost_work_order_ledger_detail'), ('cost_unit_cost_detail')) required(table_name)
        WHERE NOT EXISTS (
            SELECT 1 FROM information_schema.tables t
            WHERE t.table_schema = 'public' AND t.table_name = required.table_name
        )
    ) THEN
        RAISE EXCEPTION '成本库业务表不存在，请先执行 sql/jt/postgresql92/costree-cost.sql';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'cost_unit_dict'
          AND column_name = 'manage_unit_group'
    ) THEN
        RAISE EXCEPTION 'cost_unit_dict.manage_unit_group 不存在，请先执行 20260721 增量脚本';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'cost_project_basic'
          AND column_name = 'product_attachment_type'
    ) THEN
        RAISE EXCEPTION 'cost_project_basic.product_attachment_type 不存在，请先执行 20260626 增量脚本';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM (VALUES ('quantity'), ('product_short_name'), ('vertical_division')) required(column_name)
        WHERE NOT EXISTS (
            SELECT 1 FROM information_schema.columns c
            WHERE c.table_schema = 'public' AND c.table_name = 'cost_project_basic'
              AND c.column_name = required.column_name
        )
    ) THEN
        RAISE EXCEPTION 'cost_project_basic 项目办字段不完整，请先执行 20260728 增量脚本';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM (VALUES ('uk_cost_unit_cost_project_unit'), ('uk_cost_work_order_business'),
                     ('uk_cost_ledger_source_detail')) required(index_name)
        WHERE NOT EXISTS (
            SELECT 1 FROM pg_indexes i
            WHERE i.schemaname = 'public' AND i.indexname = required.index_name
        )
    ) THEN
        RAISE EXCEPTION '金额同步所需业务防重索引缺失，请先执行当前数据库升级脚本';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_integration.unit_dict
        GROUP BY accounting_unit_id HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '单位字典暂存表存在重复 accounting_unit_id';
    END IF;
    IF EXISTS (
        SELECT 1 FROM cost_integration.ads_lc_lshsxm2022
        GROUP BY lshsxm_xmnm HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '主业项目树暂存表存在重复 lshsxm_xmnm';
    END IF;
    IF EXISTS (
        SELECT 1 FROM cost_integration.precontrol_project_unit_amount
        WHERE source_deleted = 0
        GROUP BY project_code, unit_name HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '预分预控暂存表存在重复的项目编码 + 单位名称';
    END IF;
    IF EXISTS (
        SELECT 1 FROM cost_integration.project_office_fill
        WHERE source_deleted = 0
        GROUP BY project_code HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '项目办暂存表存在重复 project_code';
    END IF;
    IF EXISTS (
        SELECT 1 FROM cost_integration.dws_bu_pz_pzmx_gzl
        GROUP BY ysnm HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '账面明细暂存表存在重复 ysnm，禁止重复记账';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.cost_unit_cost_detail
        GROUP BY tenant_id, project_code, unit_name HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '目标库 cost_unit_cost_detail 已存在重复业务键，请先运行升级验收并清理重复数据';
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.cost_work_order
        GROUP BY tenant_id, project_code, unit_name, work_order_no HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '目标库 cost_work_order 已存在重复业务键，请先运行升级验收并清理重复数据';
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.cost_work_order_ledger_detail
        GROUP BY tenant_id, source_detail_id HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '目标库账面明细已存在重复 source_detail_id，请先运行升级验收并清理重复数据';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_integration.ads_lc_lshsxm2022 s
        WHERE btrim(s.lshsxm_js) !~ '^[123]$'
    ) THEN
        RAISE EXCEPTION '主业项目树暂存数据只允许 1/2/3 级节点';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM cost_integration.ads_lc_lshsxm2022 s
        WHERE s.lshsxm_js IN ('2', '3')
          AND NOT EXISTS (
              SELECT 1 FROM cost_integration.ads_lc_lshsxm2022 p
              WHERE p.lshsxm_xmnm = s.parent_xmnm
          )
    ) THEN
        RAISE EXCEPTION '主业项目树存在找不到父节点的记录';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_integration.unit_dict
        WHERE manage_unit_group NOT IN ('HEAD_OFFICE', 'OVERALL', 'ASSEMBLY', 'PROFESSIONAL', 'FOUNDATION', 'OUTER')
    ) THEN
        RAISE EXCEPTION '单位管理分类必须是 HEAD_OFFICE/OVERALL/ASSEMBLY/PROFESSIONAL/FOUNDATION/OUTER';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_integration.precontrol_project_unit_amount a
        WHERE a.source_deleted = 0
          AND (a.contract_amount < 0 OR a.income_amount < 0)
    ) THEN
        RAISE EXCEPTION '预分预控合同金额和到款金额不允许为负数';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_integration.precontrol_project_unit_amount a
        WHERE a.source_deleted = 0
          AND NOT EXISTS (
              SELECT 1 FROM cost_integration.ads_lc_lshsxm2022 p
              WHERE p.lshsxm_js = '3' AND p.lshsxm_xmbh = a.project_code
          )
    ) THEN
        RAISE EXCEPTION '预分预控金额存在未进入主业项目树的项目';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_integration.precontrol_project_unit_amount a
        WHERE a.source_deleted = 0
          AND NOT EXISTS (
              SELECT 1 FROM cost_integration.unit_dict d
              WHERE d.accounting_unit_id = a.accounting_unit_id
                AND d.accounting_unit_name = a.unit_name
          )
    ) THEN
        RAISE EXCEPTION '预分预控金额存在未进入单位字典的单位';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_integration.dwd_bd_bfcustomitem_gzl w
        WHERE w.source_deleted = '0'
          AND NOT EXISTS (
              SELECT 1 FROM cost_integration.ads_lc_lshsxm2022 p
              WHERE p.lshsxm_js = '3' AND p.lshsxm_xmbh = w.zyxmcode
                AND p.lshsxm_xmnm = w.zyxmid
          )
    ) THEN
        RAISE EXCEPTION '工作令映射存在无法匹配的主业项目';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_integration.dwd_bd_bfcustomitem_gzl w
        WHERE w.source_deleted = '0'
          AND NOT EXISTS (
              SELECT 1 FROM cost_integration.unit_dict d
              WHERE d.accounting_unit_code = w.accountorgcode
                AND d.accounting_unit_name = w.accountorgname
          )
    ) THEN
        RAISE EXCEPTION '工作令映射存在无法匹配的核算单位';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_integration.dws_bu_pz_pzmx_gzl l
        WHERE lower(btrim(l.source_deleted)) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
          AND (
              btrim(l.kjnd) !~ '^\d{4}$'
              OR btrim(l.pzrq) !~ '^\d{8}$'
              OR btrim(l.jzfx) NOT IN ('借', '贷')
              OR replace(btrim(l.je), ',', '') !~ '^-?\d+(\.\d+)?$'
          )
    ) THEN
        RAISE EXCEPTION '账面明细存在非法年度、日期、借贷方向或金额';
    END IF;

    IF EXISTS (
        SELECT 1 FROM cost_integration.dws_bu_pz_pzmx_gzl l
        WHERE lower(btrim(l.source_deleted)) NOT IN ('1', 'true', 't', '是', 'yes', 'y')
          AND NOT EXISTS (
              SELECT 1 FROM cost_integration.dwd_bd_bfcustomitem_gzl w
              WHERE (
                  (NULLIF(btrim(l.gzlnm), '') IS NOT NULL
                   AND w.id = btrim(l.gzlnm))
                  OR
                  (NULLIF(btrim(l.gzlnm), '') IS NULL
                   AND w.cusitemcode = l.gzllb
                   AND w.zyxmcode = l.xmbh
                   AND (
                       (NULLIF(btrim(l.dwbh), '') IS NOT NULL
                        AND w.accountorgcode = btrim(l.dwbh))
                       OR
                       (NULLIF(btrim(l.dwmc), '') IS NOT NULL
                        AND w.accountorgname = btrim(l.dwmc))
                   ))
              )
          )
    ) THEN
        RAISE EXCEPTION '账面明细存在无法匹配的工作令映射';
    END IF;

    IF EXISTS (
        SELECT p.project_code
        FROM public.cost_project p
        WHERE p.tenant_id = v_tenant_id AND p.deleted = 0
          AND p.project_code IN (
              SELECT lshsxm_xmbh FROM cost_integration.ads_lc_lshsxm2022 WHERE lshsxm_js = '3'
          )
        GROUP BY p.project_code HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '目标库本批项目编码存在重复，不能安全同步';
    END IF;

    IF EXISTS (
        SELECT n.node_code
        FROM public.cost_model_node n
        WHERE n.tenant_id = v_tenant_id AND n.deleted = 0
          AND n.node_code IN (SELECT lshsxm_xmnm FROM cost_integration.ads_lc_lshsxm2022)
        GROUP BY n.node_code HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '目标库本批型号树节点编码存在重复，不能安全同步';
    END IF;
END $$;

DROP TABLE IF EXISTS tmp_sync_unit_source;
CREATE TEMP TABLE tmp_sync_unit_source ON COMMIT DELETE ROWS AS
SELECT s.*,
       lower(btrim(COALESCE(s.inside_group, '否'))) IN ('1', 'true', 't', '是', 'yes', 'y') AS inside_group_value,
       lower(btrim(COALESCE(s.inside_institute, '否'))) IN ('1', 'true', 't', '是', 'yes', 'y') AS inside_institute_value,
       lower(btrim(COALESCE(s.disabled, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y') AS disabled_value,
       lower(btrim(COALESCE(s.source_deleted, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y') AS deleted_value
FROM cost_integration.unit_dict s;

UPDATE public.cost_unit_dict d
SET accounting_unit_code = s.accounting_unit_code,
    accounting_unit_name = s.accounting_unit_name,
    manage_unit_code = s.manage_unit_code,
    manage_unit_name = s.manage_unit_name,
    manage_unit_group = s.manage_unit_group,
    contact_unit_code = s.contact_unit_code,
    contact_unit_name = s.contact_unit_name,
    inside_group = s.inside_group_value,
    inside_institute = s.inside_institute_value,
    status = CASE WHEN s.disabled_value THEN 'DISABLE' ELSE 'ENABLE' END,
    remark = '内网正式单位字典同步', updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP, deleted = CASE WHEN s.deleted_value THEN 1 ELSE 0 END
FROM tmp_sync_unit_source s
CROSS JOIN tmp_sync_context c
WHERE d.tenant_id = c.tenant_id
  AND (
      d.accounting_unit_id = s.accounting_unit_id
      OR (
          d.accounting_unit_name = s.accounting_unit_name
          AND NOT EXISTS (
              SELECT 1 FROM public.cost_unit_dict x
              WHERE x.tenant_id = c.tenant_id AND x.accounting_unit_id = s.accounting_unit_id
          )
      )
  );

INSERT INTO public.cost_unit_dict (
    accounting_unit_id, accounting_unit_code, accounting_unit_name,
    manage_unit_code, manage_unit_name, manage_unit_group,
    contact_unit_code, contact_unit_name, inside_group, inside_institute,
    status, remark, creator, create_time, updater, update_time, deleted, tenant_id
)
SELECT s.accounting_unit_id, s.accounting_unit_code, s.accounting_unit_name,
       s.manage_unit_code, s.manage_unit_name, s.manage_unit_group,
       s.contact_unit_code, s.contact_unit_name, s.inside_group_value, s.inside_institute_value,
       CASE WHEN s.disabled_value THEN 'DISABLE' ELSE 'ENABLE' END,
       '内网正式单位字典同步', c.source_tag, CURRENT_TIMESTAMP, c.source_tag, CURRENT_TIMESTAMP,
       CASE WHEN s.deleted_value THEN 1 ELSE 0 END, c.tenant_id
FROM tmp_sync_unit_source s
CROSS JOIN tmp_sync_context c
WHERE NOT EXISTS (
    SELECT 1 FROM public.cost_unit_dict d
    WHERE d.tenant_id = c.tenant_id
      AND (d.accounting_unit_id = s.accounting_unit_id OR d.accounting_unit_name = s.accounting_unit_name)
);

DROP TABLE IF EXISTS tmp_sync_node_source;
CREATE TEMP TABLE tmp_sync_node_source ON COMMIT DELETE ROWS AS
SELECT lshsxm_xmnm AS node_code, lshsxm_xmmc AS node_name,
       lshsxm_js::int AS level_no, parent_xmnm AS parent_code,
       CASE lshsxm_js WHEN '1' THEN 'DOMAIN' WHEN '2' THEN 'SERIES' ELSE 'MODEL' END AS node_type,
       xmsx AS domain_code,
       CASE WHEN lower(btrim(COALESCE(disabled, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
            THEN 'DISABLE' ELSE 'ENABLE' END AS status,
       CASE WHEN lower(btrim(COALESCE(source_deleted, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
            THEN 1 ELSE 0 END::int2 AS deleted
FROM cost_integration.ads_lc_lshsxm2022;

UPDATE public.cost_model_node n
SET parent_id = 0, node_name = s.node_name, node_type = s.node_type,
    domain_code = s.domain_code, sort = 990, status = s.status,
    remark = '内网正式主业项目树同步', updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP, deleted = s.deleted
FROM tmp_sync_node_source s CROSS JOIN tmp_sync_context c
WHERE s.level_no = 1 AND n.tenant_id = c.tenant_id AND n.node_code = s.node_code;

INSERT INTO public.cost_model_node (
    parent_id, node_code, node_name, node_type, domain_code, sort, status,
    remark, creator, create_time, updater, update_time, deleted, tenant_id
)
SELECT 0, s.node_code, s.node_name, s.node_type, s.domain_code, 990, s.status,
       '内网正式主业项目树同步', c.source_tag, CURRENT_TIMESTAMP, c.source_tag, CURRENT_TIMESTAMP,
       s.deleted, c.tenant_id
FROM tmp_sync_node_source s CROSS JOIN tmp_sync_context c
WHERE s.level_no = 1 AND NOT EXISTS (
    SELECT 1 FROM public.cost_model_node n
    WHERE n.tenant_id = c.tenant_id AND n.node_code = s.node_code
);

UPDATE public.cost_model_node n
SET parent_id = (SELECT min(p.id) FROM public.cost_model_node p
                 WHERE p.tenant_id = c.tenant_id AND p.node_code = s.parent_code),
    node_name = s.node_name, node_type = s.node_type, domain_code = s.domain_code,
    sort = 10, status = s.status, remark = '内网正式主业项目树同步',
    updater = c.source_tag, update_time = CURRENT_TIMESTAMP, deleted = s.deleted
FROM tmp_sync_node_source s CROSS JOIN tmp_sync_context c
WHERE s.level_no = 2 AND n.tenant_id = c.tenant_id AND n.node_code = s.node_code;

INSERT INTO public.cost_model_node (
    parent_id, node_code, node_name, node_type, domain_code, sort, status,
    remark, creator, create_time, updater, update_time, deleted, tenant_id
)
SELECT (SELECT min(p.id) FROM public.cost_model_node p
        WHERE p.tenant_id = c.tenant_id AND p.node_code = s.parent_code),
       s.node_code, s.node_name, s.node_type, s.domain_code, 10, s.status,
       '内网正式主业项目树同步', c.source_tag, CURRENT_TIMESTAMP, c.source_tag, CURRENT_TIMESTAMP,
       s.deleted, c.tenant_id
FROM tmp_sync_node_source s CROSS JOIN tmp_sync_context c
WHERE s.level_no = 2 AND NOT EXISTS (
    SELECT 1 FROM public.cost_model_node n
    WHERE n.tenant_id = c.tenant_id AND n.node_code = s.node_code
);

UPDATE public.cost_model_node n
SET parent_id = (SELECT min(p.id) FROM public.cost_model_node p
                 WHERE p.tenant_id = c.tenant_id AND p.node_code = s.parent_code),
    node_name = s.node_name, node_type = s.node_type, domain_code = s.domain_code,
    sort = 10, status = s.status, remark = '内网正式主业项目树同步',
    updater = c.source_tag, update_time = CURRENT_TIMESTAMP, deleted = s.deleted
FROM tmp_sync_node_source s CROSS JOIN tmp_sync_context c
WHERE s.level_no = 3 AND n.tenant_id = c.tenant_id AND n.node_code = s.node_code;

INSERT INTO public.cost_model_node (
    parent_id, node_code, node_name, node_type, domain_code, sort, status,
    remark, creator, create_time, updater, update_time, deleted, tenant_id
)
SELECT (SELECT min(p.id) FROM public.cost_model_node p
        WHERE p.tenant_id = c.tenant_id AND p.node_code = s.parent_code),
       s.node_code, s.node_name, s.node_type, s.domain_code, 10, s.status,
       '内网正式主业项目树同步', c.source_tag, CURRENT_TIMESTAMP, c.source_tag, CURRENT_TIMESTAMP,
       s.deleted, c.tenant_id
FROM tmp_sync_node_source s CROSS JOIN tmp_sync_context c
WHERE s.level_no = 3 AND NOT EXISTS (
    SELECT 1 FROM public.cost_model_node n
    WHERE n.tenant_id = c.tenant_id AND n.node_code = s.node_code
);

DROP TABLE IF EXISTS tmp_sync_project_source;
CREATE TEMP TABLE tmp_sync_project_source ON COMMIT DELETE ROWS AS
SELECT m.lshsxm_xmbh AS project_code, m.lshsxm_xmmc AS project_name,
       m.lshsxm_xmnm AS model_code, m.lshsxm_xmmc AS model_name,
       m.xmsx AS domain_code, d.lshsxm_xmmc AS domain_name,
       s.lshsxm_xmnm AS category_code, s.lshsxm_xmmc AS category_name,
       o.batch_category AS batch_no, o.research_unit_name AS unit_name,
       o.stage_code AS current_stage,
       COALESCE((
           SELECT string_agg(x.stage_code, ',' ORDER BY x.stage_sort)
           FROM (
               SELECT f.max_stage_code AS stage_code,
                      min(CASE f.max_stage_code WHEN 'M' THEN 1 WHEN 'C' THEN 2
                                               WHEN 'S' THEN 3 WHEN 'D' THEN 4
                                               WHEN 'Z' THEN 5 ELSE 99 END) AS stage_sort
               FROM cost_integration.dwd_bd_bfcustomitem_gzl wr
               JOIN cost_integration.work_order_fill f ON f.source_work_order_id = wr.id
               WHERE wr.zyxmcode = m.lshsxm_xmbh AND wr.source_deleted = '0' AND f.source_deleted = 0
               GROUP BY f.max_stage_code
           ) x
       ), o.stage_code) AS stage_codes,
       CASE WHEN lower(btrim(COALESCE(m.source_deleted, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
            THEN 1 ELSE 0 END::int2 AS deleted
FROM cost_integration.ads_lc_lshsxm2022 m
JOIN cost_integration.ads_lc_lshsxm2022 s ON s.lshsxm_xmnm = m.parent_xmnm
JOIN cost_integration.ads_lc_lshsxm2022 d ON d.lshsxm_xmnm = s.parent_xmnm
LEFT JOIN cost_integration.project_office_fill o ON o.project_code = m.lshsxm_xmbh AND o.source_deleted = 0
WHERE m.lshsxm_js = '3';

UPDATE public.cost_project p
SET project_name = s.project_name,
    model_node_id = (SELECT min(n.id) FROM public.cost_model_node n
                     WHERE n.tenant_id = c.tenant_id AND n.node_code = s.model_code),
    domain_code = s.domain_code, domain_name = s.domain_name,
    category_code = s.category_code, category_name = s.category_name,
    model_code = s.model_code, model_name = s.model_name,
    batch_no = s.batch_no, stage_codes = s.stage_codes,
    unit_name = s.unit_name, unit_type = '院内单位',
    project_office_status = 'FILLED', unit_fill_status = 'FILLED', audit_status = 'SUBMITTED',
    remark = '内网正式主业项目同步', updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP, deleted = s.deleted
FROM tmp_sync_project_source s CROSS JOIN tmp_sync_context c
WHERE p.tenant_id = c.tenant_id AND p.project_code = s.project_code;

INSERT INTO public.cost_project (
    project_code, project_name, model_node_id, domain_code, domain_name,
    category_code, category_name, model_code, model_name, batch_no, stage_codes,
    unit_name, unit_type, project_office_status, unit_fill_status, audit_status,
    remark, creator, create_time, updater, update_time, deleted, tenant_id
)
SELECT s.project_code, s.project_name,
       (SELECT min(n.id) FROM public.cost_model_node n
        WHERE n.tenant_id = c.tenant_id AND n.node_code = s.model_code),
       s.domain_code, s.domain_name, s.category_code, s.category_name,
       s.model_code, s.model_name, s.batch_no, s.stage_codes,
       s.unit_name, '院内单位', 'FILLED', 'FILLED', 'SUBMITTED',
       '内网正式主业项目同步', c.source_tag, CURRENT_TIMESTAMP, c.source_tag, CURRENT_TIMESTAMP,
       s.deleted, c.tenant_id
FROM tmp_sync_project_source s CROSS JOIN tmp_sync_context c
WHERE NOT EXISTS (
    SELECT 1 FROM public.cost_project p
    WHERE p.tenant_id = c.tenant_id AND p.project_code = s.project_code
);

DO $$
DECLARE v_tenant_id int8 := (SELECT tenant_id FROM tmp_sync_context);
BEGIN
    IF EXISTS (
        SELECT b.project_code
        FROM public.cost_project_basic b
        WHERE b.tenant_id = v_tenant_id AND b.deleted = 0
          AND b.project_code IN (SELECT project_code FROM cost_integration.project_office_fill)
        GROUP BY b.project_code HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '目标库本批项目存在多条有效项目基本信息，不能安全同步';
    END IF;
END $$;

UPDATE public.cost_project_basic b
SET project_id = p.id, project_name = p.project_name,
    product_attachment_type = s.product_attachment_type,
    subsystem_name = s.subsystem_name, quantity = s.quantity,
    product_short_name = s.product_short_name, vertical_division = s.vertical_division,
    user_name = s.user_name,
    acquire_method = s.acquire_method, batch_category = s.batch_category,
    platform_series = s.platform_series,
    research_unit_id = (SELECT min(d.id) FROM public.cost_unit_dict d
                        WHERE d.tenant_id = c.tenant_id AND d.deleted = 0
                          AND d.accounting_unit_name = s.research_unit_name),
    research_unit_name = s.research_unit_name, tax_exempt = s.tax_exempt,
    contract_amount = NULL, target_cost_amount = NULL, approved_amount = NULL,
    cycle_start = s.cycle_start, cycle_end = s.cycle_end, stage_code = s.stage_code,
    basic_info = s.basic_info, status = s.status,
    remark = '内网正式项目办字段同步', updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP, deleted = s.source_deleted
FROM cost_integration.project_office_fill s
CROSS JOIN tmp_sync_context c
JOIN public.cost_project p ON p.tenant_id = c.tenant_id AND p.project_code = s.project_code
WHERE b.tenant_id = c.tenant_id AND b.project_code = s.project_code;

INSERT INTO public.cost_project_basic (
    project_id, project_code, project_name, product_attachment_type, subsystem_name,
    quantity, product_short_name, vertical_division,
    user_name, acquire_method, batch_category, platform_series,
    research_unit_id, research_unit_name, tax_exempt,
    cycle_start, cycle_end, stage_code, basic_info, status, remark,
    creator, create_time, updater, update_time, deleted, tenant_id
)
SELECT p.id, s.project_code, p.project_name, s.product_attachment_type, s.subsystem_name,
       s.quantity, s.product_short_name, s.vertical_division,
       s.user_name, s.acquire_method, s.batch_category, s.platform_series,
       (SELECT min(d.id) FROM public.cost_unit_dict d
        WHERE d.tenant_id = c.tenant_id AND d.deleted = 0
          AND d.accounting_unit_name = s.research_unit_name),
       s.research_unit_name, s.tax_exempt,
       s.cycle_start, s.cycle_end, s.stage_code, s.basic_info, s.status,
       '内网正式项目办字段同步', c.source_tag, CURRENT_TIMESTAMP, c.source_tag, CURRENT_TIMESTAMP,
       s.source_deleted, c.tenant_id
FROM cost_integration.project_office_fill s
CROSS JOIN tmp_sync_context c
JOIN public.cost_project p ON p.tenant_id = c.tenant_id AND p.project_code = s.project_code
WHERE NOT EXISTS (
    SELECT 1 FROM public.cost_project_basic b
    WHERE b.tenant_id = c.tenant_id AND b.project_code = s.project_code
);

DROP TABLE IF EXISTS tmp_sync_unit_cost_source;
CREATE TEMP TABLE tmp_sync_unit_cost_source ON COMMIT DELETE ROWS AS
SELECT p.id AS project_id, a.project_code, p.project_name, p.domain_code, p.domain_name,
       p.model_node_id, p.model_code, p.model_name,
       (SELECT min(d.id) FROM public.cost_unit_dict d
        WHERE d.tenant_id = c.tenant_id AND d.deleted = 0
          AND d.accounting_unit_name = a.unit_name) AS unit_id,
       a.unit_name, 'ALL'::varchar(32) AS stage_code,
       a.source_record_id, a.source_update_time,
       a.contract_amount, a.income_amount,
       NULL::numeric(18,2) AS target_cost_amount,
       0::numeric(18,2) AS book_cost_amount,
       NULL::numeric(18,2) AS approved_amount,
       a.source_deleted AS deleted, c.tenant_id, c.source_tag
FROM cost_integration.precontrol_project_unit_amount a
CROSS JOIN tmp_sync_context c
JOIN public.cost_project p ON p.tenant_id = c.tenant_id AND p.project_code = a.project_code;

UPDATE public.cost_unit_cost_detail d
SET project_id = s.project_id, project_name = s.project_name,
    domain_code = s.domain_code, domain_name = s.domain_name,
    model_node_id = s.model_node_id, model_code = s.model_code,
    model_name = s.model_name, unit_id = s.unit_id,
    stage_code = s.stage_code, source_record_id = s.source_record_id,
    source_update_time = s.source_update_time,
    contract_amount = s.contract_amount, income_amount = s.income_amount,
    creator = s.source_tag,
    updater = s.source_tag, update_time = CURRENT_TIMESTAMP, deleted = s.deleted
FROM tmp_sync_unit_cost_source s
WHERE d.tenant_id = s.tenant_id AND d.project_code = s.project_code
  AND d.unit_name = s.unit_name;

INSERT INTO public.cost_unit_cost_detail (
    project_id, project_code, project_name, domain_code, domain_name,
    model_node_id, model_code, model_name, unit_id, unit_name, stage_code,
    source_record_id, source_update_time, contract_amount, income_amount,
    target_cost_amount, book_cost_amount, approved_amount,
    creator, create_time, updater, update_time, deleted, tenant_id
)
SELECT s.project_id, s.project_code, s.project_name, s.domain_code, s.domain_name,
       s.model_node_id, s.model_code, s.model_name, s.unit_id, s.unit_name, s.stage_code,
       s.source_record_id, s.source_update_time, s.contract_amount, s.income_amount,
       s.target_cost_amount, s.book_cost_amount, s.approved_amount,
       s.source_tag, CURRENT_TIMESTAMP, s.source_tag, CURRENT_TIMESTAMP, s.deleted, s.tenant_id
FROM tmp_sync_unit_cost_source s
WHERE NOT EXISTS (
    SELECT 1 FROM public.cost_unit_cost_detail d
    WHERE d.tenant_id = s.tenant_id AND d.project_code = s.project_code
      AND d.unit_name = s.unit_name
);

UPDATE public.cost_unit_cost_detail d
SET deleted = 1, updater = c.source_tag, update_time = CURRENT_TIMESTAMP
FROM tmp_sync_context c
WHERE d.tenant_id = c.tenant_id AND d.creator = c.source_tag
  AND d.project_code IN (SELECT project_code FROM tmp_sync_project_source)
  AND NOT EXISTS (
      SELECT 1 FROM cost_integration.precontrol_project_unit_amount a
      WHERE a.project_code = d.project_code AND a.unit_name = d.unit_name
  );

DROP TABLE IF EXISTS tmp_sync_logical_work_order;
CREATE TEMP TABLE tmp_sync_logical_work_order ON COMMIT DELETE ROWS AS
SELECT r.id AS source_work_order_id, r.zyxmcode AS project_code,
       r.zyxmname AS project_name, r.accountorgcode AS accounting_unit_code,
       r.accountorgname AS unit_name,
       r.cusitemcode AS work_order_no, r.cusitemname AS work_order_name,
       max(f.stage_codes) AS stage_codes,
       (array_agg(f.max_stage_code ORDER BY
          CASE f.max_stage_code WHEN 'M' THEN 1 WHEN 'C' THEN 2 WHEN 'S' THEN 3
                               WHEN 'D' THEN 4 WHEN 'Z' THEN 5 ELSE 0 END DESC))[1] AS max_stage_code,
       max(f.subsystem_name) AS subsystem_name,
       max(f.product_short_name) AS product_short_name,
       max(f.quantity) AS quantity,
       bool_or(f.vertical_division) AS vertical_division,
       lower(btrim(COALESCE(r.isdisabled, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y') AS disabled,
       CASE WHEN lower(btrim(COALESCE(r.source_deleted, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
            THEN 1 ELSE 0 END::int2 AS deleted
FROM cost_integration.dwd_bd_bfcustomitem_gzl r
LEFT JOIN cost_integration.work_order_fill f
  ON f.source_work_order_id = r.id AND f.source_deleted = 0
GROUP BY r.id, r.zyxmcode, r.zyxmname, r.accountorgcode, r.accountorgname,
         r.cusitemcode, r.cusitemname, r.isdisabled, r.source_deleted;

DO $$
BEGIN
    IF EXISTS (
        SELECT project_code, unit_name, work_order_no
        FROM tmp_sync_logical_work_order
        GROUP BY project_code, unit_name, work_order_no HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '暂存源解析出了重复的逻辑工作令业务键';
    END IF;
END $$;

DROP TABLE IF EXISTS tmp_sync_snapshot_key;
CREATE TEMP TABLE tmp_sync_snapshot_key (
    project_code varchar(128) NOT NULL,
    unit_name varchar(255) NOT NULL,
    work_order_no varchar(128) NOT NULL,
    CONSTRAINT pk_tmp_sync_snapshot_key PRIMARY KEY (project_code, unit_name, work_order_no)
) ON COMMIT DELETE ROWS;

INSERT INTO tmp_sync_snapshot_key
SELECT DISTINCT d.project_code, d.accounting_unit_name, d.work_order_no
FROM public.cost_work_order_ledger_detail d
CROSS JOIN tmp_sync_context c
WHERE d.tenant_id = c.tenant_id
  AND d.project_code IN (SELECT project_code FROM tmp_sync_project_source)
  AND d.source_detail_id IN (SELECT ysnm FROM cost_integration.dws_bu_pz_pzmx_gzl)
  AND NOT EXISTS (
      SELECT 1 FROM tmp_sync_snapshot_key k
      WHERE k.project_code = d.project_code AND k.unit_name = d.accounting_unit_name
        AND k.work_order_no = d.work_order_no
  );

DROP TABLE IF EXISTS tmp_sync_work_order_source;
CREATE TEMP TABLE tmp_sync_work_order_source ON COMMIT DELETE ROWS AS
SELECT w.source_work_order_id, p.id AS project_id, w.project_code, p.project_name,
       (SELECT min(d.id) FROM public.cost_unit_dict d
        WHERE d.tenant_id = c.tenant_id AND d.deleted = 0
          AND d.accounting_unit_name = w.unit_name) AS unit_id,
       w.unit_name, w.accounting_unit_code, w.unit_name AS accounting_unit_name,
       ''::varchar(16) AS fiscal_year,
       w.work_order_no, w.work_order_name,
       w.stage_codes, w.max_stage_code, w.subsystem_name, w.product_short_name,
       w.quantity, w.vertical_division, w.disabled,
       w.deleted, c.tenant_id, c.source_tag
FROM tmp_sync_logical_work_order w
CROSS JOIN tmp_sync_context c
JOIN public.cost_project p ON p.tenant_id = c.tenant_id AND p.project_code = w.project_code;

UPDATE public.cost_work_order w
SET source_work_order_id = s.source_work_order_id,
    project_id = s.project_id, project_name = s.project_name,
    unit_id = s.unit_id, accounting_unit_code = s.accounting_unit_code,
    accounting_unit_name = s.accounting_unit_name,
    fiscal_year = s.fiscal_year, work_order_name = s.work_order_name,
    stage_codes = s.stage_codes, max_stage_code = s.max_stage_code,
    subsystem_name = s.subsystem_name, product_short_name = s.product_short_name,
    quantity = s.quantity, vertical_division = s.vertical_division,
    disabled = s.disabled,
    remark = '内网正式工作令同步，可在项目详情页补充固定金额',
    creator = s.source_tag, updater = s.source_tag,
    update_time = CURRENT_TIMESTAMP, deleted = s.deleted
FROM tmp_sync_work_order_source s
WHERE w.tenant_id = s.tenant_id AND w.project_code = s.project_code
  AND w.unit_name = s.unit_name AND w.work_order_no = s.work_order_no;

INSERT INTO public.cost_work_order (
    source_work_order_id, project_id, project_code, project_name, unit_id, unit_name,
    accounting_unit_code, accounting_unit_name, fiscal_year, work_order_no, work_order_name,
    product_target_cost, contract_amount, income_amount, stage_codes, max_stage_code,
    subsystem_name, product_short_name, quantity, vertical_division, disabled,
    approved_amount, status, remark, creator, create_time, updater, update_time,
    deleted, tenant_id
)
SELECT s.source_work_order_id, s.project_id, s.project_code, s.project_name,
       s.unit_id, s.unit_name, s.accounting_unit_code, s.accounting_unit_name,
       s.fiscal_year, s.work_order_no, s.work_order_name,
       NULL, NULL, NULL, s.stage_codes, s.max_stage_code,
       s.subsystem_name, s.product_short_name, s.quantity, s.vertical_division,
       s.disabled, NULL, 'DRAFT', '内网正式工作令同步，可在项目详情页补充固定金额',
       s.source_tag, CURRENT_TIMESTAMP, s.source_tag, CURRENT_TIMESTAMP,
       s.deleted, s.tenant_id
FROM tmp_sync_work_order_source s
WHERE NOT EXISTS (
    SELECT 1 FROM public.cost_work_order w
    WHERE w.tenant_id = s.tenant_id AND w.project_code = s.project_code
      AND w.unit_name = s.unit_name AND w.work_order_no = s.work_order_no
);

UPDATE public.cost_work_order w
SET deleted = 1, updater = c.source_tag, update_time = CURRENT_TIMESTAMP
FROM tmp_sync_context c
WHERE w.tenant_id = c.tenant_id AND w.creator = c.source_tag
  AND w.project_code IN (SELECT project_code FROM tmp_sync_project_source)
  AND NOT EXISTS (
      SELECT 1 FROM tmp_sync_logical_work_order s
      WHERE s.project_code = w.project_code AND s.unit_name = w.unit_name
        AND s.work_order_no = w.work_order_no
  );

DROP TABLE IF EXISTS tmp_sync_ledger_source;
CREATE TEMP TABLE tmp_sync_ledger_source ON COMMIT DELETE ROWS AS
SELECT l.ysnm AS source_detail_id, l.kjnd AS fiscal_year, l.kjqj AS accounting_period,
       CASE WHEN NULLIF(btrim(l.pzrq), '') IS NULL THEN NULL
            ELSE to_date(l.pzrq, 'YYYYMMDD') END AS voucher_date,
       l.pzbh AS voucher_no,
       COALESCE(NULLIF(btrim(l.dwid), ''), (
           SELECT min(d.accounting_unit_id) FROM public.cost_unit_dict d
           WHERE d.tenant_id = c.tenant_id AND d.deleted = 0
             AND d.accounting_unit_name = w.unit_name
       )) AS accounting_unit_id,
       COALESCE(NULLIF(btrim(l.dwbh), ''), w.accounting_unit_code) AS accounting_unit_code,
       w.unit_name AS accounting_unit_name,
       COALESCE(NULLIF(btrim(l.gldw), ''), (
           SELECT min(d.manage_unit_name) FROM public.cost_unit_dict d
           WHERE d.tenant_id = c.tenant_id AND d.deleted = 0
             AND d.accounting_unit_name = w.unit_name
       )) AS manage_unit_name,
       l.kmid AS subject_id, l.kmbh AS subject_code, l.kmmc AS subject_name,
       w.project_code AS project_code, l.xmnm AS source_project_id, p.project_name,
       COALESCE(NULLIF(btrim(l.gzlnm), ''), w.source_work_order_id) AS source_work_order_id,
       w.work_order_no, COALESCE(NULLIF(btrim(l.gzlmc), ''), w.work_order_name) AS work_order_name,
       btrim(l.jzfx) AS debit_credit,
       replace(btrim(l.je), ',', '')::numeric(18,2) AS amount,
       round(replace(btrim(l.je), ',', '')::numeric / 10000.0, 2) AS amount_wan,
       l.yt AS summary_text,
       CASE WHEN NULLIF(btrim(l.lastmodifiedtime), '') IS NULL THEN NULL
            ELSE l.lastmodifiedtime::timestamp END AS source_lastmodify,
       l.ejkmbh AS second_subject_code, l.ejkmmc AS second_subject_name,
       l.dwts AS source_timestamp, w.max_stage_code AS resolved_stage_code,
       p.id AS project_id, w.id AS work_order_id,
       CASE WHEN lower(btrim(COALESCE(l.source_deleted, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
            THEN 1 ELSE 0 END::int2 AS deleted,
       c.tenant_id, c.source_tag
FROM cost_integration.dws_bu_pz_pzmx_gzl l
CROSS JOIN tmp_sync_context c
JOIN public.cost_project p ON p.tenant_id = c.tenant_id AND p.project_code = l.xmbh
JOIN public.cost_work_order w ON w.tenant_id = c.tenant_id
  AND w.deleted = 0 AND w.project_code = l.xmbh
  AND (
      (NULLIF(btrim(l.gzlnm), '') IS NOT NULL
       AND w.source_work_order_id = btrim(l.gzlnm))
      OR
      (NULLIF(btrim(l.gzlnm), '') IS NULL
       AND w.work_order_no = l.gzllb
       AND (
           (NULLIF(btrim(l.dwbh), '') IS NOT NULL
            AND w.accounting_unit_code = btrim(l.dwbh))
           OR
           (NULLIF(btrim(l.dwmc), '') IS NOT NULL
            AND w.unit_name = btrim(l.dwmc))
       ))
  );

DO $$
DECLARE
    v_unmatched_count int8;
    v_duplicate_count int8;
BEGIN
    SELECT count(*) INTO v_unmatched_count
    FROM cost_integration.dws_bu_pz_pzmx_gzl l
    WHERE NOT EXISTS (
        SELECT 1 FROM tmp_sync_ledger_source s WHERE s.source_detail_id = l.ysnm
    );
    IF v_unmatched_count > 0 THEN
        RAISE EXCEPTION '存在 % 条账面明细无法关联逻辑工作令，请检查 gzlnm/source_work_order_id 及单位编码', v_unmatched_count;
    END IF;

    SELECT count(*) INTO v_duplicate_count
    FROM (
        SELECT source_detail_id FROM tmp_sync_ledger_source
        GROUP BY source_detail_id HAVING count(*) > 1
    ) duplicate_source;
    IF v_duplicate_count > 0 THEN
        RAISE EXCEPTION '存在 % 个账面源明细匹配到多个逻辑工作令，请先修正工作令源主键', v_duplicate_count;
    END IF;
END $$;

INSERT INTO tmp_sync_snapshot_key
SELECT DISTINCT s.project_code, s.accounting_unit_name, s.work_order_no
FROM tmp_sync_ledger_source s
WHERE NOT EXISTS (
    SELECT 1 FROM tmp_sync_snapshot_key k
    WHERE k.project_code = s.project_code
      AND k.unit_name = s.accounting_unit_name
      AND k.work_order_no = s.work_order_no
);

UPDATE public.cost_work_order_ledger_detail d
SET fiscal_year = s.fiscal_year, accounting_period = s.accounting_period,
    voucher_date = s.voucher_date, voucher_no = s.voucher_no,
    accounting_unit_id = s.accounting_unit_id,
    accounting_unit_code = s.accounting_unit_code,
    accounting_unit_name = s.accounting_unit_name,
    manage_unit_name = s.manage_unit_name,
    subject_id = s.subject_id, subject_code = s.subject_code,
    subject_name = s.subject_name, project_code = s.project_code,
    source_project_id = s.source_project_id, project_name = s.project_name,
    source_work_order_id = s.source_work_order_id,
    work_order_no = s.work_order_no, work_order_name = s.work_order_name,
    debit_credit = s.debit_credit, amount = s.amount,
    amount_wan = s.amount_wan, summary_text = s.summary_text,
    source_lastmodify = s.source_lastmodify,
    second_subject_code = s.second_subject_code,
    second_subject_name = s.second_subject_name,
    source_timestamp = s.source_timestamp,
    resolved_stage_code = s.resolved_stage_code,
    project_id = s.project_id, work_order_id = s.work_order_id,
    remark = '内网正式账面明细同步', creator = s.source_tag,
    updater = s.source_tag, update_time = CURRENT_TIMESTAMP, deleted = s.deleted
FROM tmp_sync_ledger_source s
WHERE d.tenant_id = s.tenant_id AND d.source_detail_id = s.source_detail_id;

INSERT INTO public.cost_work_order_ledger_detail (
    source_detail_id, fiscal_year, accounting_period, voucher_date, voucher_no,
    accounting_unit_id, accounting_unit_code, accounting_unit_name, manage_unit_name,
    subject_id, subject_code, subject_name, project_code, source_project_id, project_name,
    source_work_order_id, work_order_no, work_order_name, debit_credit, amount, amount_wan,
    summary_text, source_lastmodify, second_subject_code, second_subject_name,
    source_timestamp, resolved_stage_code, project_id, work_order_id,
    remark, creator, create_time, updater, update_time, deleted, tenant_id
)
SELECT s.source_detail_id, s.fiscal_year, s.accounting_period, s.voucher_date, s.voucher_no,
       s.accounting_unit_id, s.accounting_unit_code, s.accounting_unit_name, s.manage_unit_name,
       s.subject_id, s.subject_code, s.subject_name, s.project_code, s.source_project_id,
       s.project_name, s.source_work_order_id, s.work_order_no, s.work_order_name,
       s.debit_credit, s.amount, s.amount_wan, s.summary_text, s.source_lastmodify,
       s.second_subject_code, s.second_subject_name, s.source_timestamp,
       s.resolved_stage_code, s.project_id, s.work_order_id,
       '内网正式账面明细同步', s.source_tag, CURRENT_TIMESTAMP,
       s.source_tag, CURRENT_TIMESTAMP, s.deleted, s.tenant_id
FROM tmp_sync_ledger_source s
WHERE NOT EXISTS (
    SELECT 1 FROM public.cost_work_order_ledger_detail d
    WHERE d.tenant_id = s.tenant_id AND d.source_detail_id = s.source_detail_id
);

UPDATE public.cost_work_order_ledger_detail d
SET deleted = 1, updater = c.source_tag, update_time = CURRENT_TIMESTAMP
FROM tmp_sync_context c
WHERE d.tenant_id = c.tenant_id AND d.creator = c.source_tag
  AND d.project_code IN (SELECT project_code FROM tmp_sync_project_source)
  AND NOT EXISTS (
      SELECT 1 FROM cost_integration.dws_bu_pz_pzmx_gzl l WHERE l.ysnm = d.source_detail_id
  );

UPDATE public.cost_work_order w
SET book_cost_amount = 0, updater = c.source_tag, update_time = CURRENT_TIMESTAMP
FROM tmp_sync_snapshot_key k CROSS JOIN tmp_sync_context c
WHERE w.tenant_id = c.tenant_id AND w.deleted = 0
  AND w.project_code = k.project_code AND w.unit_name = k.unit_name
  AND w.work_order_no = k.work_order_no;

WITH debit_snapshot AS (
    SELECT d.project_code, d.accounting_unit_name AS unit_name,
           d.work_order_no,
           SUM(COALESCE(d.amount / 10000.0, d.amount_wan, 0)) AS book_cost_amount
    FROM public.cost_work_order_ledger_detail d
    JOIN tmp_sync_snapshot_key k ON k.project_code = d.project_code
      AND k.unit_name = d.accounting_unit_name AND k.work_order_no = d.work_order_no
    CROSS JOIN tmp_sync_context c
    WHERE d.tenant_id = c.tenant_id AND d.deleted = 0 AND btrim(d.debit_credit) = '借'
    GROUP BY d.project_code, d.accounting_unit_name, d.work_order_no
)
UPDATE public.cost_work_order w
SET book_cost_amount = s.book_cost_amount, updater = c.source_tag, update_time = CURRENT_TIMESTAMP
FROM debit_snapshot s CROSS JOIN tmp_sync_context c
WHERE w.tenant_id = c.tenant_id AND w.deleted = 0
  AND w.project_code = s.project_code AND w.unit_name = s.unit_name
  AND w.work_order_no = s.work_order_no;

DROP TABLE IF EXISTS tmp_sync_source_count;
CREATE TEMP TABLE tmp_sync_source_count ON COMMIT DELETE ROWS AS
SELECT sum(row_count)::int4 AS total_count
FROM (
    SELECT count(*) AS row_count FROM cost_integration.unit_dict
    UNION ALL SELECT count(*) FROM cost_integration.ads_lc_lshsxm2022
    UNION ALL SELECT count(*) FROM cost_integration.dwd_bd_bfcustomitem_gzl
    UNION ALL SELECT count(*) FROM cost_integration.precontrol_project_unit_amount
    UNION ALL SELECT count(*) FROM cost_integration.project_office_fill
    UNION ALL SELECT count(*) FROM cost_integration.work_order_fill
    UNION ALL SELECT count(*) FROM cost_integration.dws_bu_pz_pzmx_gzl
) x;

UPDATE public.cost_import_batch b
SET total_count = s.total_count, success_count = s.total_count, failure_count = 0,
    update_support = true, status = 'SUCCESS',
    remark = 'cost_integration 内网数据同步',
    updater = c.source_tag, update_time = CURRENT_TIMESTAMP, deleted = 0
FROM tmp_sync_source_count s CROSS JOIN tmp_sync_context c
WHERE b.tenant_id = c.tenant_id AND b.import_type = 'COST_INTEGRATION_SYNC'
  AND b.file_name = c.batch_code;

INSERT INTO public.cost_import_batch (
    import_type, file_name, total_count, success_count, failure_count,
    update_support, status, remark, creator, create_time, updater, update_time,
    deleted, tenant_id
)
SELECT 'COST_INTEGRATION_SYNC', c.batch_code, s.total_count, s.total_count, 0,
       true, 'SUCCESS', 'cost_integration 内网数据同步',
       c.source_tag, CURRENT_TIMESTAMP, c.source_tag, CURRENT_TIMESTAMP, 0, c.tenant_id
FROM tmp_sync_source_count s CROSS JOIN tmp_sync_context c
WHERE NOT EXISTS (
    SELECT 1 FROM public.cost_import_batch b
    WHERE b.tenant_id = c.tenant_id AND b.import_type = 'COST_INTEGRATION_SYNC'
      AND b.file_name = c.batch_code
);

DO $$
DECLARE
    v_tenant_id int8 := (SELECT tenant_id FROM tmp_sync_context);
BEGIN
    IF EXISTS (
        SELECT 1
        FROM cost_integration.precontrol_project_unit_amount s
        LEFT JOIN public.cost_unit_cost_detail d
          ON d.tenant_id = v_tenant_id AND d.project_code = s.project_code AND d.unit_name = s.unit_name
        WHERE d.id IS NULL OR d.stage_code <> 'ALL'
           OR s.contract_amount IS DISTINCT FROM d.contract_amount
           OR s.income_amount IS DISTINCT FROM d.income_amount
    ) THEN
        RAISE EXCEPTION '预分预控合同/到款同步后对账失败';
    END IF;

    IF EXISTS (
        SELECT w.id
        FROM public.cost_work_order w
        LEFT JOIN public.cost_work_order_ledger_detail d
         ON d.tenant_id = w.tenant_id AND d.deleted = 0
         AND d.project_code = w.project_code AND d.accounting_unit_name = w.unit_name
         AND d.work_order_no = w.work_order_no
        WHERE w.tenant_id = v_tenant_id AND w.deleted = 0
          AND w.project_code IN (SELECT project_code FROM tmp_sync_project_source)
        GROUP BY w.id, w.book_cost_amount
        HAVING abs(COALESCE(w.book_cost_amount, 0) -
                   COALESCE(SUM(CASE WHEN btrim(d.debit_credit) = '借'
                                     THEN COALESCE(d.amount / 10000.0, d.amount_wan, 0)
                                     ELSE 0 END), 0)) > 0.01
    ) THEN
        RAISE EXCEPTION '逻辑工作令跨年度账面快照同步后对账失败';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.cost_work_order_ledger_detail d
        WHERE d.tenant_id = v_tenant_id AND d.deleted = 0
          AND d.project_code IN (SELECT project_code FROM tmp_sync_project_source)
          AND (d.project_id IS NULL OR d.work_order_id IS NULL)
    ) THEN
        RAISE EXCEPTION '账面明细同步后仍存在未解析项目或工作令';
    END IF;
END $$;

COMMIT;

SELECT '同步完成' AS result,
       (SELECT tenant_id FROM cost_integration.sync_config WHERE id = 1) AS tenant_id,
       (SELECT batch_code FROM cost_integration.sync_config WHERE id = 1) AS batch_code;
