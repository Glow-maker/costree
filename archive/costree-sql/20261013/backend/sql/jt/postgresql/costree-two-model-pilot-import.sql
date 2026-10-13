/*
 Costree two-model pilot import script for PostgreSQL.

 Purpose:
   Import two selected intranet projects into the cost module:
     ads_lc_lshsxm2022       -> cost_model_node / cost_project
     dwd_bd_bfcustomitem_gzl -> cost_work_order
     dws_bu_pz_pzmx_gzl      -> cost_work_order_ledger_detail

 Usage:
   1. Run costree-cost.sql first.
   2. Edit only the "CONFIG AREA" below.
   3. Run this file in psql, DBeaver, or another PostgreSQL client.

 Notes:
   - This script is intentionally scoped to a pilot. It creates one pilot
     domain and one pilot series, then hangs the selected projects as MODEL
     nodes. Formal domain/series parsing should be implemented after the
     intranet tree level rules are confirmed.
   - The script is idempotent by natural keys and will not duplicate rows.
   - Work-order business fields filled later by users are not overwritten:
     product_target_cost, stage_codes, max_stage_code, subsystem_name,
     product_short_name, quantity, approved_amount.
   - amount_unit and sign_mode are provisional until finance confirms the
     unit of je and debit/credit sign rule.
*/

BEGIN;

-- ======================================================================
-- CONFIG AREA: change these values before executing in intranet.
-- ======================================================================

-- Source table schemas. Change public for work-order ref if DBA confirms
-- another schema name.
DROP VIEW IF EXISTS _cost_src_project_tree;
DROP VIEW IF EXISTS _cost_src_work_order_ref;
DROP VIEW IF EXISTS _cost_src_ledger_detail;

CREATE TEMP VIEW _cost_src_project_tree AS
SELECT * FROM sc_8001_cw.ads_lc_lshsxm2022;

CREATE TEMP VIEW _cost_src_work_order_ref AS
SELECT * FROM public.dwd_bd_bfcustomitem_gzl;

CREATE TEMP VIEW _cost_src_ledger_detail AS
SELECT * FROM sc_8001_fidw.dws_bu_pz_pzmx_gzl;

DROP TABLE IF EXISTS _cost_pilot_params;
CREATE TEMP TABLE _cost_pilot_params
(
    project_code_1 varchar(128) NOT NULL,
    project_code_2 varchar(128) NULL,
    tenant_id      bigint       NOT NULL,
    domain_code    varchar(128) NOT NULL,
    domain_name    varchar(255) NOT NULL,
    series_code    varchar(128) NOT NULL,
    series_name    varchar(255) NOT NULL,
    amount_unit    varchar(16)  NOT NULL,
    sign_mode      varchar(64)  NOT NULL
);

INSERT INTO _cost_pilot_params
(
    project_code_1,
    project_code_2,
    tenant_id,
    domain_code,
    domain_name,
    series_code,
    series_name,
    amount_unit,
    sign_mode
)
VALUES
(
    'CHANGE_ME_PROJECT_CODE_1',
    'CHANGE_ME_PROJECT_CODE_2',
    124,
    'INTRANET_PILOT',
    '内网试点领域',
    'TWO_MODEL_PILOT',
    '两型号试点系列',
    'YUAN',   -- YUAN: je is yuan; WAN: je is already ten-thousand yuan
    'AS_IS'  -- AS_IS / DEBIT_POSITIVE_CREDIT_NEGATIVE / CREDIT_POSITIVE_DEBIT_NEGATIVE
);

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM _cost_pilot_params
        WHERE project_code_1 LIKE 'CHANGE_ME%'
           OR project_code_2 LIKE 'CHANGE_ME%'
    ) THEN
        RAISE EXCEPTION 'Please edit project_code_1/project_code_2 in costree-two-model-pilot-import.sql before running it.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM _cost_pilot_params
        WHERE amount_unit NOT IN ('YUAN', 'WAN')
           OR sign_mode NOT IN ('AS_IS', 'DEBIT_POSITIVE_CREDIT_NEGATIVE', 'CREDIT_POSITIVE_DEBIT_NEGATIVE')
    ) THEN
        RAISE EXCEPTION 'Invalid amount_unit or sign_mode in _cost_pilot_params.';
    END IF;
END $$;

-- Keep sequences safe when the database was initialized with explicit IDs.
SELECT setval('cost_model_node_seq', COALESCE((SELECT MAX(id) FROM cost_model_node), 1), (SELECT MAX(id) IS NOT NULL FROM cost_model_node));
SELECT setval('cost_project_seq', COALESCE((SELECT MAX(id) FROM cost_project), 1), (SELECT MAX(id) IS NOT NULL FROM cost_project));
SELECT setval('cost_work_order_seq', COALESCE((SELECT MAX(id) FROM cost_work_order), 1), (SELECT MAX(id) IS NOT NULL FROM cost_work_order));
SELECT setval('cost_work_order_ledger_detail_seq', COALESCE((SELECT MAX(id) FROM cost_work_order_ledger_detail), 1), (SELECT MAX(id) IS NOT NULL FROM cost_work_order_ledger_detail));

-- ======================================================================
-- 1. Read the two pilot projects from intranet project tree.
-- ======================================================================

DROP TABLE IF EXISTS _cost_pilot_projects;
CREATE TEMP TABLE _cost_pilot_projects AS
WITH normalized_project_source AS (
    SELECT
        p.tenant_id,
        NULLIF(BTRIM(s.lshsxm_xmnm), '') AS source_project_id,
        NULLIF(BTRIM(s.lshsxm_xmbh), '') AS project_code,
        COALESCE(NULLIF(BTRIM(s.lshsxm_xmmc), ''), NULLIF(BTRIM(s.lshsxm_xmbh), '')) AS project_name,
        NULLIF(BTRIM(s.lshsxm_xmlx), '') AS source_project_category,
        NULLIF(BTRIM(s.lshsxm_dwbh), '') AS source_unit_code,
        NULLIF(BTRIM(s.lshsxm_js), '') AS source_level_no,
        NULLIF(BTRIM(s.lshsxm_mx), '') AS source_is_detail,
        NULLIF(BTRIM(s.disabled), '') AS source_disabled,
        NULLIF(BTRIM(s.lshsxm_zt), '') AS source_status
    FROM _cost_src_project_tree s
    CROSS JOIN _cost_pilot_params p
)
SELECT DISTINCT ON (project_code)
       tenant_id,
       source_project_id,
       project_code,
       project_name,
       source_project_category,
       source_unit_code,
       source_level_no,
       source_is_detail,
       source_disabled,
       source_status
FROM normalized_project_source n
JOIN _cost_pilot_params p ON p.tenant_id = n.tenant_id
WHERE n.project_code IN (p.project_code_1, p.project_code_2)
ORDER BY project_code, source_project_id NULLS LAST;

DO $$
DECLARE
    v_count int;
BEGIN
    SELECT COUNT(*) INTO v_count FROM _cost_pilot_projects;
    IF v_count = 0 THEN
        RAISE EXCEPTION 'No source project rows found. Check project_code_1/project_code_2 and _cost_src_project_tree.';
    ELSIF v_count < 2 THEN
        RAISE NOTICE 'Only % pilot project row(s) found. Continue importing what was found.', v_count;
    ELSE
        RAISE NOTICE 'Found % pilot project rows.', v_count;
    END IF;
END $$;

-- ======================================================================
-- 2. Create/update the pilot DOMAIN/SERIES/MODEL tree.
-- ======================================================================

INSERT INTO cost_model_node
(
    parent_id, node_code, node_name, node_type, domain_code, sort, status,
    remark, creator, updater, tenant_id
)
SELECT
    0,
    'DOMAIN_' || p.domain_code,
    p.domain_name,
    'DOMAIN',
    p.domain_code,
    900,
    'ENABLE',
    '两型号试点导入：临时领域节点',
    'cost_pilot_import',
    'cost_pilot_import',
    p.tenant_id
FROM _cost_pilot_params p
WHERE NOT EXISTS (
    SELECT 1
    FROM cost_model_node n
    WHERE n.deleted = 0
      AND n.tenant_id = p.tenant_id
      AND n.node_code = 'DOMAIN_' || p.domain_code
);

UPDATE cost_model_node n
SET node_name = p.domain_name,
    node_type = 'DOMAIN',
    parent_id = 0,
    domain_code = p.domain_code,
    status = 'ENABLE',
    updater = 'cost_pilot_import',
    update_time = CURRENT_TIMESTAMP
FROM _cost_pilot_params p
WHERE n.deleted = 0
  AND n.tenant_id = p.tenant_id
  AND n.node_code = 'DOMAIN_' || p.domain_code;

INSERT INTO cost_model_node
(
    parent_id, node_code, node_name, node_type, domain_code, sort, status,
    remark, creator, updater, tenant_id
)
SELECT
    d.id,
    'SERIES_' || p.series_code,
    p.series_name,
    'SERIES',
    p.domain_code,
    10,
    'ENABLE',
    '两型号试点导入：临时系列节点',
    'cost_pilot_import',
    'cost_pilot_import',
    p.tenant_id
FROM _cost_pilot_params p
JOIN cost_model_node d
  ON d.deleted = 0
 AND d.tenant_id = p.tenant_id
 AND d.node_code = 'DOMAIN_' || p.domain_code
WHERE NOT EXISTS (
    SELECT 1
    FROM cost_model_node n
    WHERE n.deleted = 0
      AND n.tenant_id = p.tenant_id
      AND n.node_code = 'SERIES_' || p.series_code
);

UPDATE cost_model_node n
SET node_name = p.series_name,
    node_type = 'SERIES',
    parent_id = d.id,
    domain_code = p.domain_code,
    status = 'ENABLE',
    updater = 'cost_pilot_import',
    update_time = CURRENT_TIMESTAMP
FROM _cost_pilot_params p
JOIN cost_model_node d
  ON d.deleted = 0
 AND d.tenant_id = p.tenant_id
 AND d.node_code = 'DOMAIN_' || p.domain_code
WHERE n.deleted = 0
  AND n.tenant_id = p.tenant_id
  AND n.node_code = 'SERIES_' || p.series_code;

DROP TABLE IF EXISTS _cost_pilot_model_rows;
CREATE TEMP TABLE _cost_pilot_model_rows AS
SELECT
    sp.tenant_id,
    sp.source_project_id,
    sp.project_code,
    sp.project_name,
    p.domain_code,
    p.domain_name,
    'SERIES_' || p.series_code AS category_code,
    p.series_name AS category_name,
    (
        'MODEL_' ||
        LEFT(
            COALESCE(
                NULLIF(UPPER(REGEXP_REPLACE(sp.project_code, '[^0-9A-Za-z]+', '_', 'g')), ''),
                'SRC_' || SUBSTRING(MD5(sp.project_code), 1, 16)
            ),
            120
        )
    ) AS model_code,
    sp.project_name AS model_name,
    ROW_NUMBER() OVER (ORDER BY sp.project_code) * 10 AS sort_no
FROM _cost_pilot_projects sp
CROSS JOIN _cost_pilot_params p;

INSERT INTO cost_model_node
(
    parent_id, node_code, node_name, node_type, domain_code, sort, status,
    remark, creator, updater, tenant_id
)
SELECT
    series.id,
    m.model_code,
    m.model_name,
    'MODEL',
    m.domain_code,
    m.sort_no,
    'ENABLE',
    '两型号试点导入：source_project_id=' || COALESCE(m.source_project_id, ''),
    'cost_pilot_import',
    'cost_pilot_import',
    m.tenant_id
FROM _cost_pilot_model_rows m
JOIN cost_model_node series
  ON series.deleted = 0
 AND series.tenant_id = m.tenant_id
 AND series.node_code = m.category_code
WHERE NOT EXISTS (
    SELECT 1
    FROM cost_model_node n
    WHERE n.deleted = 0
      AND n.tenant_id = m.tenant_id
      AND n.node_code = m.model_code
);

UPDATE cost_model_node n
SET node_name = m.model_name,
    node_type = 'MODEL',
    parent_id = series.id,
    domain_code = m.domain_code,
    status = 'ENABLE',
    updater = 'cost_pilot_import',
    update_time = CURRENT_TIMESTAMP
FROM _cost_pilot_model_rows m
JOIN cost_model_node series
  ON series.deleted = 0
 AND series.tenant_id = m.tenant_id
 AND series.node_code = m.category_code
WHERE n.deleted = 0
  AND n.tenant_id = m.tenant_id
  AND n.node_code = m.model_code;

-- ======================================================================
-- 3. Create/update cost_project cards.
-- ======================================================================

DROP TABLE IF EXISTS _cost_pilot_project_targets;
CREATE TEMP TABLE _cost_pilot_project_targets AS
SELECT
    m.*,
    mn.id AS model_node_id
FROM _cost_pilot_model_rows m
JOIN cost_model_node mn
  ON mn.deleted = 0
 AND mn.tenant_id = m.tenant_id
 AND mn.node_code = m.model_code;

UPDATE cost_project p
SET project_name = s.project_name,
    model_node_id = s.model_node_id,
    domain_code = s.domain_code,
    domain_name = s.domain_name,
    category_code = s.category_code,
    category_name = s.category_name,
    model_code = s.model_code,
    model_name = s.model_name,
    updater = 'cost_pilot_import',
    update_time = CURRENT_TIMESTAMP
FROM _cost_pilot_project_targets s
WHERE p.deleted = 0
  AND p.tenant_id = s.tenant_id
  AND p.project_code = s.project_code;

INSERT INTO cost_project
(
    project_code, project_name, model_node_id, domain_code, domain_name,
    category_code, category_name, model_code, model_name,
    project_office_status, unit_fill_status, audit_status, warning_status,
    remark, creator, updater, tenant_id
)
SELECT
    s.project_code,
    s.project_name,
    s.model_node_id,
    s.domain_code,
    s.domain_name,
    s.category_code,
    s.category_name,
    s.model_code,
    s.model_name,
    'NOT_FILLED',
    'NOT_FILLED',
    'DRAFT',
    'NORMAL',
    '两型号试点导入：source_project_id=' || COALESCE(s.source_project_id, ''),
    'cost_pilot_import',
    'cost_pilot_import',
    s.tenant_id
FROM _cost_pilot_project_targets s
WHERE NOT EXISTS (
    SELECT 1
    FROM cost_project p
    WHERE p.deleted = 0
      AND p.tenant_id = s.tenant_id
      AND p.project_code = s.project_code
);

-- ======================================================================
-- 4. Create/update cost_work_order from work-order project mapping.
-- ======================================================================

DROP TABLE IF EXISTS _cost_pilot_work_order_rows;
CREATE TEMP TABLE _cost_pilot_work_order_rows AS
WITH raw_rows AS (
    SELECT
        p.tenant_id,
        cp.id AS project_id,
        cp.project_code,
        cp.project_name,
        COALESCE(NULLIF(BTRIM(r.id), ''), NULLIF(BTRIM(r.cusitemcode), '')) AS source_work_order_id,
        NULLIF(BTRIM(r.accountorgcode), '') AS accounting_unit_code,
        NULLIF(BTRIM(r.accountorgname), '') AS accounting_unit_name,
        NULLIF(BTRIM(r.cusitemcode), '') AS work_order_no,
        COALESCE(NULLIF(BTRIM(r.cusitemname), ''), NULLIF(BTRIM(r.cusitemcode), '')) AS work_order_name,
        CASE
            WHEN COALESCE(NULLIF(BTRIM(r.isdisabled), ''), NULLIF(BTRIM(r.ifstopname), ''), '') IN
                 ('1', 'Y', 'YES', 'TRUE', 'true', '是', '停用', '已停用')
                THEN TRUE
            ELSE FALSE
        END AS disabled,
        ROW_NUMBER() OVER (
            PARTITION BY COALESCE(NULLIF(BTRIM(r.id), ''), NULLIF(BTRIM(r.cusitemcode), ''))
            ORDER BY NULLIF(BTRIM(r.cusitemcode), '')
        ) AS rn
    FROM _cost_src_work_order_ref r
    CROSS JOIN _cost_pilot_params p
    JOIN _cost_pilot_projects sp
      ON NULLIF(BTRIM(r.zyxmcode), '') = sp.project_code
      OR NULLIF(BTRIM(r.zyxmid), '') = sp.source_project_id
    JOIN cost_project cp
      ON cp.deleted = 0
     AND cp.tenant_id = p.tenant_id
     AND cp.project_code = sp.project_code
    WHERE NULLIF(BTRIM(r.cusitemcode), '') IS NOT NULL
)
SELECT *
FROM raw_rows
WHERE rn = 1;

UPDATE cost_work_order wo
SET project_id = s.project_id,
    project_code = s.project_code,
    project_name = s.project_name,
    unit_name = COALESCE(s.accounting_unit_name, wo.unit_name),
    accounting_unit_code = s.accounting_unit_code,
    accounting_unit_name = s.accounting_unit_name,
    work_order_name = s.work_order_name,
    disabled = s.disabled,
    updater = 'cost_pilot_import',
    update_time = CURRENT_TIMESTAMP
FROM _cost_pilot_work_order_rows s
WHERE wo.deleted = 0
  AND wo.tenant_id = s.tenant_id
  AND (
        (wo.source_work_order_id IS NOT NULL AND wo.source_work_order_id = s.source_work_order_id)
        OR (wo.project_code = s.project_code AND wo.work_order_no = s.work_order_no)
      );

INSERT INTO cost_work_order
(
    source_work_order_id, project_id, project_code, project_name,
    unit_name, accounting_unit_code, accounting_unit_name,
    work_order_no, work_order_name,
    vertical_division, disabled, status,
    remark, creator, updater, tenant_id
)
SELECT
    s.source_work_order_id,
    s.project_id,
    s.project_code,
    s.project_name,
    s.accounting_unit_name,
    s.accounting_unit_code,
    s.accounting_unit_name,
    s.work_order_no,
    s.work_order_name,
    FALSE,
    s.disabled,
    'DRAFT',
    '两型号试点导入：目标成本、阶段、分系统需后续补充',
    'cost_pilot_import',
    'cost_pilot_import',
    s.tenant_id
FROM _cost_pilot_work_order_rows s
WHERE NOT EXISTS (
    SELECT 1
    FROM cost_work_order wo
    WHERE wo.deleted = 0
      AND wo.tenant_id = s.tenant_id
      AND (
            (wo.source_work_order_id IS NOT NULL AND wo.source_work_order_id = s.source_work_order_id)
            OR (wo.project_code = s.project_code AND wo.work_order_no = s.work_order_no)
          )
);

-- ======================================================================
-- 5. Create/update ledger detail rows.
-- ======================================================================

DROP TABLE IF EXISTS _cost_pilot_ledger_rows;
CREATE TEMP TABLE _cost_pilot_ledger_rows AS
WITH filtered AS (
    SELECT
        p.tenant_id,
        d.*
    FROM _cost_src_ledger_detail d
    CROSS JOIN _cost_pilot_params p
    WHERE NULLIF(BTRIM(d.xmbh), '') IN (p.project_code_1, p.project_code_2)
       OR NULLIF(BTRIM(d.gzlnm), '') IN (
            SELECT source_work_order_id
            FROM cost_work_order
            WHERE deleted = 0
              AND tenant_id = p.tenant_id
              AND project_code IN (p.project_code_1, p.project_code_2)
              AND source_work_order_id IS NOT NULL
       )
       OR NULLIF(BTRIM(d.gzllb), '') IN (
            SELECT work_order_no
            FROM cost_work_order
            WHERE deleted = 0
              AND tenant_id = p.tenant_id
              AND project_code IN (p.project_code_1, p.project_code_2)
       )
),
parsed AS (
    SELECT
        f.tenant_id,
        COALESCE(
            NULLIF(BTRIM(f.ysnm), ''),
            NULLIF(BTRIM(f.id), ''),
            'GEN_' || SUBSTRING(MD5(
                COALESCE(f.kjnd, '') || '|' ||
                COALESCE(f.kjqj, '') || '|' ||
                COALESCE(f.pzbh, '') || '|' ||
                COALESCE(f.xmbh, '') || '|' ||
                COALESCE(f.gzllb, '') || '|' ||
                COALESCE(f.je, '')
            ), 1, 24)
        ) AS source_detail_id,
        NULLIF(BTRIM(f.kjnd), '') AS fiscal_year,
        NULLIF(BTRIM(f.kjqj), '') AS accounting_period,
        CASE
            WHEN NULLIF(BTRIM(f.pzrq), '') ~ '^[0-9]{8}$'
                THEN TO_DATE(NULLIF(BTRIM(f.pzrq), ''), 'YYYYMMDD')
            ELSE NULL
        END AS voucher_date,
        NULLIF(BTRIM(f.pzbh), '') AS voucher_no,
        NULLIF(BTRIM(f.dwid), '') AS accounting_unit_id,
        NULLIF(BTRIM(f.dwbh), '') AS accounting_unit_code,
        NULLIF(BTRIM(f.dwmc), '') AS accounting_unit_name,
        NULLIF(BTRIM(f.gldw), '') AS manage_unit_name,
        NULLIF(BTRIM(f.kmid), '') AS subject_id,
        NULLIF(BTRIM(f.kmbh), '') AS subject_code,
        NULLIF(BTRIM(f.kmmc), '') AS subject_name,
        NULLIF(BTRIM(f.xmbh), '') AS source_project_code,
        NULLIF(BTRIM(f.xmnm), '') AS source_project_id,
        NULLIF(BTRIM(f.xmmc), '') AS source_project_name,
        NULLIF(BTRIM(f.gzlnm), '') AS source_work_order_id,
        NULLIF(BTRIM(f.gzllb), '') AS work_order_no,
        NULLIF(BTRIM(f.gzlmc), '') AS work_order_name,
        NULLIF(BTRIM(f.jzfx), '') AS debit_credit,
        CASE
            WHEN REPLACE(REPLACE(REPLACE(REPLACE(BTRIM(COALESCE(f.je, '')), ',', ''), '，', ''), ' ', ''), E'\t', '') ~ '^-?[0-9]+(\.[0-9]+)?$'
                THEN REPLACE(REPLACE(REPLACE(REPLACE(BTRIM(COALESCE(f.je, '')), ',', ''), '，', ''), ' ', ''), E'\t', '')::numeric
            ELSE NULL
        END AS raw_amount,
        NULLIF(BTRIM(f.yt), '') AS summary_text,
        CASE
            WHEN NULLIF(BTRIM(f.lastmodifiedtime), '') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
                THEN SUBSTRING(NULLIF(BTRIM(f.lastmodifiedtime), ''), 1, 19)::timestamp
            WHEN NULLIF(BTRIM(f.lastmodifiedtime), '') ~ '^[0-9]{14}$'
                THEN TO_TIMESTAMP(NULLIF(BTRIM(f.lastmodifiedtime), ''), 'YYYYMMDDHH24MISS')::timestamp
            ELSE NULL
        END AS source_lastmodify,
        NULLIF(BTRIM(f.ejkmbh), '') AS second_subject_code,
        NULLIF(BTRIM(f.ejkmmc), '') AS second_subject_name,
        NULLIF(BTRIM(f.dwts), '') AS source_timestamp
    FROM filtered f
),
signed AS (
    SELECT
        p.*,
        CASE
            WHEN cfg.sign_mode = 'DEBIT_POSITIVE_CREDIT_NEGATIVE'
                 AND p.debit_credit IN ('贷', 'C', 'Credit', 'CREDIT')
                THEN -p.raw_amount
            WHEN cfg.sign_mode = 'CREDIT_POSITIVE_DEBIT_NEGATIVE'
                 AND p.debit_credit IN ('借', 'D', 'Debit', 'DEBIT')
                THEN -p.raw_amount
            ELSE p.raw_amount
        END AS signed_amount,
        cfg.amount_unit
    FROM parsed p
    CROSS JOIN _cost_pilot_params cfg
),
matched AS (
    SELECT
        s.*,
        wo.id AS matched_work_order_id,
        COALESCE(wo.project_id, cp.id) AS matched_project_id,
        COALESCE(wo.project_code, cp.project_code, s.source_project_code) AS matched_project_code,
        COALESCE(wo.project_name, cp.project_name, s.source_project_name) AS matched_project_name,
        wo.max_stage_code AS matched_stage_code
    FROM signed s
    LEFT JOIN LATERAL (
        SELECT w.*
        FROM cost_work_order w
        WHERE w.deleted = 0
          AND w.tenant_id = s.tenant_id
          AND (
                (s.source_work_order_id IS NOT NULL AND w.source_work_order_id = s.source_work_order_id)
                OR (s.source_project_code IS NOT NULL AND w.project_code = s.source_project_code AND w.work_order_no = s.work_order_no)
                OR (s.accounting_unit_code IS NOT NULL AND w.accounting_unit_code = s.accounting_unit_code AND w.work_order_no = s.work_order_no)
              )
        ORDER BY
            CASE
                WHEN s.source_work_order_id IS NOT NULL AND w.source_work_order_id = s.source_work_order_id THEN 1
                WHEN s.source_project_code IS NOT NULL AND w.project_code = s.source_project_code AND w.work_order_no = s.work_order_no THEN 2
                ELSE 3
            END,
            w.id
        LIMIT 1
    ) wo ON TRUE
    LEFT JOIN cost_project cp
      ON cp.deleted = 0
     AND cp.tenant_id = s.tenant_id
     AND cp.project_code = s.source_project_code
)
SELECT
    tenant_id,
    source_detail_id,
    fiscal_year,
    accounting_period,
    voucher_date,
    voucher_no,
    accounting_unit_id,
    accounting_unit_code,
    accounting_unit_name,
    manage_unit_name,
    subject_id,
    subject_code,
    subject_name,
    matched_project_code AS project_code,
    source_project_id,
    matched_project_name AS project_name,
    source_work_order_id,
    work_order_no,
    work_order_name,
    debit_credit,
    ROUND(signed_amount, 2)::numeric(18, 2) AS amount,
    CASE
        WHEN amount_unit = 'YUAN' THEN ROUND(signed_amount / 10000, 2)::numeric(18, 2)
        ELSE ROUND(signed_amount, 2)::numeric(18, 2)
    END AS amount_wan,
    summary_text,
    source_lastmodify,
    second_subject_code,
    second_subject_name,
    source_timestamp,
    matched_stage_code AS resolved_stage_code,
    matched_project_id AS project_id,
    matched_work_order_id AS work_order_id,
    CASE
        WHEN matched_work_order_id IS NULL THEN '两型号试点导入：未匹配到工作令'
        ELSE '两型号试点导入'
    END AS remark
FROM matched;

UPDATE cost_work_order_ledger_detail t
SET fiscal_year = s.fiscal_year,
    accounting_period = s.accounting_period,
    voucher_date = s.voucher_date,
    voucher_no = s.voucher_no,
    accounting_unit_id = s.accounting_unit_id,
    accounting_unit_code = s.accounting_unit_code,
    accounting_unit_name = s.accounting_unit_name,
    manage_unit_name = s.manage_unit_name,
    subject_id = s.subject_id,
    subject_code = s.subject_code,
    subject_name = s.subject_name,
    project_code = s.project_code,
    source_project_id = s.source_project_id,
    project_name = s.project_name,
    source_work_order_id = s.source_work_order_id,
    work_order_no = s.work_order_no,
    work_order_name = s.work_order_name,
    debit_credit = s.debit_credit,
    amount = s.amount,
    amount_wan = s.amount_wan,
    summary_text = s.summary_text,
    source_lastmodify = s.source_lastmodify,
    second_subject_code = s.second_subject_code,
    second_subject_name = s.second_subject_name,
    source_timestamp = s.source_timestamp,
    resolved_stage_code = s.resolved_stage_code,
    project_id = s.project_id,
    work_order_id = s.work_order_id,
    remark = s.remark,
    updater = 'cost_pilot_import',
    update_time = CURRENT_TIMESTAMP
FROM _cost_pilot_ledger_rows s
WHERE t.deleted = 0
  AND t.tenant_id = s.tenant_id
  AND t.source_detail_id = s.source_detail_id;

INSERT INTO cost_work_order_ledger_detail
(
    source_detail_id, fiscal_year, accounting_period, voucher_date, voucher_no,
    accounting_unit_id, accounting_unit_code, accounting_unit_name, manage_unit_name,
    subject_id, subject_code, subject_name,
    project_code, source_project_id, project_name,
    source_work_order_id, work_order_no, work_order_name,
    debit_credit, amount, amount_wan, summary_text, source_lastmodify,
    second_subject_code, second_subject_name, source_timestamp,
    resolved_stage_code, project_id, work_order_id,
    remark, creator, updater, tenant_id
)
SELECT
    s.source_detail_id,
    s.fiscal_year,
    s.accounting_period,
    s.voucher_date,
    s.voucher_no,
    s.accounting_unit_id,
    s.accounting_unit_code,
    s.accounting_unit_name,
    s.manage_unit_name,
    s.subject_id,
    s.subject_code,
    s.subject_name,
    s.project_code,
    s.source_project_id,
    s.project_name,
    s.source_work_order_id,
    s.work_order_no,
    s.work_order_name,
    s.debit_credit,
    s.amount,
    s.amount_wan,
    s.summary_text,
    s.source_lastmodify,
    s.second_subject_code,
    s.second_subject_name,
    s.source_timestamp,
    s.resolved_stage_code,
    s.project_id,
    s.work_order_id,
    s.remark,
    'cost_pilot_import',
    'cost_pilot_import',
    s.tenant_id
FROM _cost_pilot_ledger_rows s
WHERE NOT EXISTS (
    SELECT 1
    FROM cost_work_order_ledger_detail t
    WHERE t.deleted = 0
      AND t.tenant_id = s.tenant_id
      AND t.source_detail_id = s.source_detail_id
);

-- Fill book_cost_amount only when it is still empty. Ledger aggregation remains
-- the source of truth for current pages.
WITH ledger_sum AS (
    SELECT
        work_order_id,
        SUM(COALESCE(amount_wan, amount / 10000, 0))::numeric(18, 2) AS book_cost_amount
    FROM cost_work_order_ledger_detail
    WHERE deleted = 0
      AND tenant_id = (SELECT tenant_id FROM _cost_pilot_params LIMIT 1)
      AND work_order_id IN (
          SELECT id
          FROM cost_work_order
          WHERE deleted = 0
            AND tenant_id = (SELECT tenant_id FROM _cost_pilot_params LIMIT 1)
            AND project_code IN (
                (SELECT project_code_1 FROM _cost_pilot_params LIMIT 1),
                (SELECT project_code_2 FROM _cost_pilot_params LIMIT 1)
            )
      )
    GROUP BY work_order_id
)
UPDATE cost_work_order wo
SET book_cost_amount = ledger_sum.book_cost_amount,
    updater = 'cost_pilot_import',
    update_time = CURRENT_TIMESTAMP
FROM ledger_sum
WHERE wo.id = ledger_sum.work_order_id
  AND wo.book_cost_amount IS NULL;

-- ======================================================================
-- 6. Verification result sets.
-- ======================================================================

SELECT 'pilot_projects_from_source' AS item, COUNT(*) AS row_count FROM _cost_pilot_projects;
SELECT 'cost_project_rows' AS item, COUNT(*) AS row_count
FROM cost_project p
JOIN _cost_pilot_params cfg ON p.tenant_id = cfg.tenant_id
WHERE p.deleted = 0
  AND p.project_code IN (cfg.project_code_1, cfg.project_code_2);

SELECT 'cost_work_order_rows' AS item, COUNT(*) AS row_count
FROM cost_work_order w
JOIN _cost_pilot_params cfg ON w.tenant_id = cfg.tenant_id
WHERE w.deleted = 0
  AND w.project_code IN (cfg.project_code_1, cfg.project_code_2);

SELECT 'cost_ledger_rows' AS item, COUNT(*) AS row_count
FROM cost_work_order_ledger_detail l
JOIN _cost_pilot_params cfg ON l.tenant_id = cfg.tenant_id
WHERE l.deleted = 0
  AND l.project_code IN (cfg.project_code_1, cfg.project_code_2);

SELECT
    p.project_code,
    p.project_name,
    p.model_node_id,
    p.domain_name,
    p.category_name,
    p.model_name
FROM cost_project p
JOIN _cost_pilot_params cfg ON p.tenant_id = cfg.tenant_id
WHERE p.deleted = 0
  AND p.project_code IN (cfg.project_code_1, cfg.project_code_2)
ORDER BY p.project_code;

SELECT
    w.project_code,
    w.work_order_no,
    w.work_order_name,
    w.accounting_unit_code,
    w.accounting_unit_name,
    w.product_target_cost,
    w.stage_codes,
    w.max_stage_code,
    w.subsystem_name,
    w.book_cost_amount,
    w.disabled
FROM cost_work_order w
JOIN _cost_pilot_params cfg ON w.tenant_id = cfg.tenant_id
WHERE w.deleted = 0
  AND w.project_code IN (cfg.project_code_1, cfg.project_code_2)
ORDER BY w.project_code, w.work_order_no;

SELECT
    l.project_code,
    l.work_order_no,
    COUNT(*) AS ledger_detail_count,
    SUM(COALESCE(l.amount_wan, l.amount / 10000, 0))::numeric(18, 2) AS book_cost_wan,
    SUM(CASE WHEN l.work_order_id IS NULL THEN 1 ELSE 0 END) AS unmatched_ledger_count
FROM cost_work_order_ledger_detail l
JOIN _cost_pilot_params cfg ON l.tenant_id = cfg.tenant_id
WHERE l.deleted = 0
  AND l.project_code IN (cfg.project_code_1, cfg.project_code_2)
GROUP BY l.project_code, l.work_order_no
ORDER BY l.project_code, l.work_order_no;

COMMIT;
