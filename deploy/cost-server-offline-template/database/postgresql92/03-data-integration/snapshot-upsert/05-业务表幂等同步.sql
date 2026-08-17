-- 中间表到成本库业务表的幂等同步。
-- PostgreSQL 9.2.4 / GaussDB 8.2.1 兼容：不用 MERGE、ON CONFLICT。
-- 现场需把业务 schema costree_mvp 和租户 124 调整为实际值。

BEGIN;

LOCK TABLE cost_sync_stage.sync_control IN EXCLUSIVE MODE;

DROP TABLE IF EXISTS tmp_cost_sync_context;
CREATE TEMP TABLE tmp_cost_sync_context ON COMMIT PRESERVE ROWS AS
SELECT tenant_id, batch_code, source_tag
FROM cost_sync_stage.sync_control
WHERE id = 1 AND load_status = 'READY';

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM tmp_cost_sync_context) THEN
        RAISE EXCEPTION '当前批次不是 READY，请先完成装载和 04 导入前检查';
    END IF;
END $$;

-- ---------------------------------------------------------------------
-- 1. 单位字典：源系统拥有全部单位映射字段。
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_cost_sync_unit;
CREATE TEMP TABLE tmp_cost_sync_unit ON COMMIT PRESERVE ROWS AS
SELECT
    NULLIF(btrim(s.accounting_unit_id), '')::varchar(128) AS accounting_unit_id,
    btrim(s.accounting_unit_code)::varchar(128) AS accounting_unit_code,
    btrim(s.accounting_unit_name)::varchar(255) AS accounting_unit_name,
    NULLIF(btrim(s.manage_unit_code), '')::varchar(128) AS manage_unit_code,
    NULLIF(btrim(s.manage_unit_name), '')::varchar(255) AS manage_unit_name,
    COALESCE(
        NULLIF(upper(btrim(s.manage_unit_group)), ''),
        CASE btrim(COALESCE(s.manage_unit_name, ''))
            WHEN '院部' THEN 'HEAD_OFFICE'
            WHEN '八部' THEN 'OVERALL'
            WHEN '509所' THEN 'OVERALL'
            WHEN '800所' THEN 'ASSEMBLY'
            WHEN '149厂' THEN 'ASSEMBLY'
            WHEN '812所' THEN 'ASSEMBLY'
            WHEN '电子所' THEN 'PROFESSIONAL'
            WHEN '动力所' THEN 'PROFESSIONAL'
            WHEN '811所' THEN 'PROFESSIONAL'
            WHEN '802所' THEN 'PROFESSIONAL'
            WHEN '803所' THEN 'PROFESSIONAL'
            WHEN '基础所' THEN 'FOUNDATION'
            WHEN '院外单位' THEN 'OUTER'
            ELSE NULL
        END
    )::varchar(32) AS manage_unit_group,
    NULLIF(btrim(s.contact_unit_code), '')::varchar(128) AS contact_unit_code,
    NULLIF(btrim(s.contact_unit_name), '')::varchar(128) AS contact_unit_name,
    CASE WHEN lower(btrim(COALESCE(s.inside_group, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
         THEN true ELSE false END AS inside_group,
    CASE WHEN lower(btrim(COALESCE(s.inside_institute, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
         THEN true ELSE false END AS inside_institute,
    CASE WHEN lower(btrim(COALESCE(s.disabled, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
         THEN 'DISABLE' ELSE 'ENABLE' END::varchar(32) AS status,
    CASE WHEN lower(btrim(COALESCE(s.source_deleted, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
         THEN 1 ELSE 0 END::int2 AS deleted
FROM cost_sync_stage.stg_unit_dict s;

UPDATE "costree_mvp".cost_unit_dict d
SET accounting_unit_id = s.accounting_unit_id,
    accounting_unit_name = s.accounting_unit_name,
    manage_unit_code = s.manage_unit_code,
    manage_unit_name = s.manage_unit_name,
    manage_unit_group = s.manage_unit_group,
    contact_unit_code = s.contact_unit_code,
    contact_unit_name = s.contact_unit_name,
    inside_group = s.inside_group,
    inside_institute = s.inside_institute,
    status = s.status,
    deleted = s.deleted,
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_cost_sync_unit s
CROSS JOIN tmp_cost_sync_context c
WHERE d.tenant_id = c.tenant_id
  AND d.accounting_unit_code = s.accounting_unit_code;

INSERT INTO "costree_mvp".cost_unit_dict (
    accounting_unit_id, accounting_unit_code, accounting_unit_name,
    manage_unit_code, manage_unit_name, manage_unit_group,
    contact_unit_code, contact_unit_name, inside_group, inside_institute,
    status, remark, creator, create_time, updater, update_time, deleted, tenant_id
)
SELECT
    s.accounting_unit_id, s.accounting_unit_code, s.accounting_unit_name,
    s.manage_unit_code, s.manage_unit_name, s.manage_unit_group,
    s.contact_unit_code, s.contact_unit_name, s.inside_group, s.inside_institute,
    s.status, '外部单位字典全量快照同步', c.source_tag, CURRENT_TIMESTAMP,
    c.source_tag, CURRENT_TIMESTAMP, s.deleted, c.tenant_id
FROM tmp_cost_sync_unit s
CROSS JOIN tmp_cost_sync_context c
WHERE s.deleted = 0
  AND NOT EXISTS (
      SELECT 1 FROM "costree_mvp".cost_unit_dict d
      WHERE d.tenant_id = c.tenant_id
        AND d.accounting_unit_code = s.accounting_unit_code
  );

-- ---------------------------------------------------------------------
-- 2. 型号目录树：先写节点，再回填父 ID 和领域编码。
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_cost_sync_node;
CREATE TEMP TABLE tmp_cost_sync_node ON COMMIT PRESERVE ROWS AS
SELECT
    btrim(s.node_code)::varchar(128) AS node_code,
    NULLIF(btrim(s.parent_node_code), '')::varchar(128) AS parent_node_code,
    btrim(s.node_name)::varchar(255) AS node_name,
    upper(btrim(s.node_type))::varchar(32) AS node_type,
    NULLIF(btrim(s.domain_code), '')::varchar(128) AS domain_code,
    CASE WHEN btrim(COALESCE(s.sort_no, '')) ~ '^[+-]?[0-9]+$'
         THEN btrim(s.sort_no)::int4 ELSE 0 END AS sort_no,
    COALESCE(NULLIF(upper(btrim(s.status)), ''), 'ENABLE')::varchar(32) AS status,
    CASE WHEN lower(btrim(COALESCE(s.source_deleted, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
         THEN 1 ELSE 0 END::int2 AS deleted
FROM cost_sync_stage.stg_model_node s;

UPDATE "costree_mvp".cost_model_node n
SET node_name = s.node_name,
    node_type = s.node_type,
    domain_code = CASE WHEN s.node_type = 'DOMAIN' THEN s.node_code ELSE s.domain_code END,
    sort = s.sort_no,
    status = s.status,
    deleted = s.deleted,
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_cost_sync_node s
CROSS JOIN tmp_cost_sync_context c
WHERE n.tenant_id = c.tenant_id
  AND n.node_code = s.node_code;

INSERT INTO "costree_mvp".cost_model_node (
    parent_id, node_code, node_name, node_type, domain_code, sort, status,
    remark, creator, create_time, updater, update_time, deleted, tenant_id
)
SELECT
    0, s.node_code, s.node_name, s.node_type,
    CASE WHEN s.node_type = 'DOMAIN' THEN s.node_code ELSE s.domain_code END,
    s.sort_no, s.status, '外部主业项目树全量快照同步',
    c.source_tag, CURRENT_TIMESTAMP, c.source_tag, CURRENT_TIMESTAMP,
    s.deleted, c.tenant_id
FROM tmp_cost_sync_node s
CROSS JOIN tmp_cost_sync_context c
WHERE s.deleted = 0
  AND NOT EXISTS (
      SELECT 1 FROM "costree_mvp".cost_model_node n
      WHERE n.tenant_id = c.tenant_id AND n.node_code = s.node_code
  );

UPDATE "costree_mvp".cost_model_node n
SET parent_id = CASE WHEN s.node_type = 'DOMAIN' THEN 0 ELSE p.id END,
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_cost_sync_node s
CROSS JOIN tmp_cost_sync_context c
LEFT JOIN "costree_mvp".cost_model_node p
  ON p.tenant_id = c.tenant_id AND p.node_code = s.parent_node_code
WHERE n.tenant_id = c.tenant_id
  AND n.node_code = s.node_code;

UPDATE "costree_mvp".cost_model_node n
SET domain_code = CASE
        WHEN s.node_type = 'DOMAIN' THEN s.node_code
        WHEN s.node_type = 'SERIES' THEN COALESCE(s.domain_code, p.node_code)
        ELSE COALESCE(s.domain_code, gp.node_code, p.domain_code)
    END,
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_cost_sync_node s
CROSS JOIN tmp_cost_sync_context c
LEFT JOIN "costree_mvp".cost_model_node p
  ON p.tenant_id = c.tenant_id AND p.node_code = s.parent_node_code
LEFT JOIN "costree_mvp".cost_model_node gp
  ON gp.tenant_id = c.tenant_id AND gp.id = p.parent_id
WHERE n.tenant_id = c.tenant_id
  AND n.node_code = s.node_code;

-- ---------------------------------------------------------------------
-- 3. 项目锚点：只更新源项目属性，保留填报、审核和预警状态。
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_cost_sync_project;
CREATE TEMP TABLE tmp_cost_sync_project ON COMMIT PRESERVE ROWS AS
SELECT
    btrim(s.project_code)::varchar(128) AS project_code,
    btrim(s.project_name)::varchar(255) AS project_name,
    m.id AS model_node_id,
    COALESCE(NULLIF(btrim(s.domain_code), ''), dom.node_code, m.domain_code)::varchar(128) AS domain_code,
    COALESCE(NULLIF(btrim(s.domain_name), ''), dom.node_name)::varchar(255) AS domain_name,
    COALESCE(NULLIF(btrim(s.category_code), ''), series.node_code)::varchar(128) AS category_code,
    COALESCE(NULLIF(btrim(s.category_name), ''), series.node_name)::varchar(255) AS category_name,
    COALESCE(NULLIF(btrim(s.model_code), ''), m.node_code)::varchar(128) AS model_code,
    COALESCE(NULLIF(btrim(s.model_name), ''), m.node_name, s.project_name)::varchar(255) AS model_name,
    CASE WHEN lower(btrim(COALESCE(s.source_deleted, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
         THEN 1 ELSE 0 END::int2 AS deleted
FROM cost_sync_stage.stg_project s
CROSS JOIN tmp_cost_sync_context c
LEFT JOIN "costree_mvp".cost_model_node m
  ON m.tenant_id = c.tenant_id AND m.node_code = s.model_node_code
LEFT JOIN "costree_mvp".cost_model_node series
  ON series.tenant_id = c.tenant_id AND series.id = m.parent_id
LEFT JOIN "costree_mvp".cost_model_node dom
  ON dom.tenant_id = c.tenant_id AND dom.id = series.parent_id;

UPDATE "costree_mvp".cost_project p
SET project_name = s.project_name,
    model_node_id = s.model_node_id,
    domain_code = s.domain_code,
    domain_name = s.domain_name,
    category_code = s.category_code,
    category_name = s.category_name,
    model_code = s.model_code,
    model_name = s.model_name,
    deleted = s.deleted,
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_cost_sync_project s
CROSS JOIN tmp_cost_sync_context c
WHERE p.tenant_id = c.tenant_id
  AND p.project_code = s.project_code;

INSERT INTO "costree_mvp".cost_project (
    project_code, project_name, model_node_id,
    domain_code, domain_name, category_code, category_name, model_code, model_name,
    remark, creator, create_time, updater, update_time, deleted, tenant_id
)
SELECT
    s.project_code, s.project_name, s.model_node_id,
    s.domain_code, s.domain_name, s.category_code, s.category_name, s.model_code, s.model_name,
    '外部主业项目全量快照同步', c.source_tag, CURRENT_TIMESTAMP,
    c.source_tag, CURRENT_TIMESTAMP, s.deleted, c.tenant_id
FROM tmp_cost_sync_project s
CROSS JOIN tmp_cost_sync_context c
WHERE s.deleted = 0
  AND NOT EXISTS (
      SELECT 1 FROM "costree_mvp".cost_project p
      WHERE p.tenant_id = c.tenant_id AND p.project_code = s.project_code
  );

-- ---------------------------------------------------------------------
-- 4. 项目单位金额：只同步合同、到款；目标和审定保持项目办填写值。
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_cost_sync_amount;
CREATE TEMP TABLE tmp_cost_sync_amount ON COMMIT PRESERVE ROWS AS
SELECT
    NULLIF(btrim(s.source_record_id), '')::varchar(128) AS source_record_id,
    CASE
        WHEN btrim(COALESCE(s.source_update_time, '')) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9]{2}:[0-9]{2}:[0-9]{2}'
        THEN to_timestamp(replace(substr(btrim(s.source_update_time), 1, 19), 'T', ' '), 'YYYY-MM-DD HH24:MI:SS')
        ELSE NULL
    END AS source_update_time,
    btrim(s.project_code)::varchar(128) AS project_code,
    COALESCE(NULLIF(btrim(s.project_name), ''), p.project_name)::varchar(255) AS project_name,
    p.id AS project_id,
    p.domain_code, p.domain_name, p.model_node_id, p.model_code, p.model_name,
    d.unit_id,
    d.accounting_unit_code,
    d.accounting_unit_name AS unit_name,
    CASE WHEN btrim(COALESCE(s.contract_amount_wan, '')) = '' THEN NULL
         ELSE btrim(s.contract_amount_wan)::numeric(18,2) END AS contract_amount,
    CASE WHEN btrim(COALESCE(s.income_amount_wan, '')) = '' THEN NULL
         ELSE btrim(s.income_amount_wan)::numeric(18,2) END AS income_amount,
    CASE WHEN lower(btrim(COALESCE(s.source_deleted, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
         THEN 1 ELSE 0 END::int2 AS deleted
FROM cost_sync_stage.stg_unit_amount s
CROSS JOIN tmp_cost_sync_context c
LEFT JOIN "costree_mvp".cost_project p
  ON p.tenant_id = c.tenant_id AND p.project_code = s.project_code
LEFT JOIN "costree_mvp".cost_unit_dict d
  ON d.tenant_id = c.tenant_id AND d.accounting_unit_code = s.accounting_unit_code;

DROP TABLE IF EXISTS tmp_cost_sync_amount_match;
CREATE TEMP TABLE tmp_cost_sync_amount_match ON COMMIT PRESERVE ROWS AS
SELECT s.*,
       COALESCE(
           CASE WHEN s.source_record_id IS NOT NULL THEN (
               SELECT min(x.id) FROM "costree_mvp".cost_unit_cost_detail x
               WHERE x.tenant_id = c.tenant_id AND x.source_record_id = s.source_record_id
           ) ELSE NULL END,
           (
               SELECT min(x.id) FROM "costree_mvp".cost_unit_cost_detail x
               WHERE x.tenant_id = c.tenant_id
                 AND x.project_code = s.project_code AND x.unit_name = s.unit_name
           )
       ) AS target_id
FROM tmp_cost_sync_amount s
CROSS JOIN tmp_cost_sync_context c;

UPDATE "costree_mvp".cost_unit_cost_detail x
SET project_id = COALESCE(s.project_id, x.project_id),
    project_code = s.project_code,
    project_name = COALESCE(s.project_name, x.project_name),
    domain_code = COALESCE(s.domain_code, x.domain_code),
    domain_name = COALESCE(s.domain_name, x.domain_name),
    model_node_id = COALESCE(s.model_node_id, x.model_node_id),
    model_code = COALESCE(s.model_code, x.model_code),
    model_name = COALESCE(s.model_name, x.model_name),
    unit_id = COALESCE(s.unit_id, x.unit_id),
    unit_name = COALESCE(s.unit_name, x.unit_name),
    stage_code = 'ALL',
    source_record_id = COALESCE(s.source_record_id, x.source_record_id),
    source_update_time = COALESCE(s.source_update_time, x.source_update_time),
    contract_amount = s.contract_amount,
    income_amount = s.income_amount,
    deleted = s.deleted,
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_cost_sync_amount_match s
CROSS JOIN tmp_cost_sync_context c
WHERE x.id = s.target_id;

INSERT INTO "costree_mvp".cost_unit_cost_detail (
    project_id, project_code, project_name, domain_code, domain_name,
    model_node_id, model_code, model_name, unit_id, unit_name, stage_code,
    source_record_id, source_update_time, contract_amount, income_amount,
    target_cost_amount, book_cost_amount, approved_amount,
    remark, creator, create_time, updater, update_time, deleted, tenant_id
)
SELECT
    s.project_id, s.project_code, s.project_name, s.domain_code, s.domain_name,
    s.model_node_id, s.model_code, s.model_name, s.unit_id, s.unit_name, 'ALL',
    s.source_record_id, s.source_update_time, s.contract_amount, s.income_amount,
    NULL, NULL, NULL,
    '预分预控项目单位金额全量快照同步；目标和审定由项目办维护',
    c.source_tag, CURRENT_TIMESTAMP, c.source_tag, CURRENT_TIMESTAMP, 0, c.tenant_id
FROM tmp_cost_sync_amount_match s
CROSS JOIN tmp_cost_sync_context c
WHERE s.deleted = 0 AND s.target_id IS NULL;

-- ---------------------------------------------------------------------
-- 5. 工作令：只同步字典归属；研制单位填写字段不在 UPDATE SET 中。
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_cost_sync_work_order;
CREATE TEMP TABLE tmp_cost_sync_work_order ON COMMIT PRESERVE ROWS AS
SELECT
    NULLIF(btrim(s.source_work_order_id), '')::varchar(128) AS source_work_order_id,
    p.id AS project_id,
    btrim(s.project_code)::varchar(128) AS project_code,
    COALESCE(NULLIF(btrim(s.project_name), ''), p.project_name)::varchar(255) AS project_name,
    d.unit_id,
    d.accounting_unit_code,
    d.accounting_unit_name AS unit_name,
    btrim(s.work_order_no)::varchar(128) AS work_order_no,
    NULLIF(btrim(s.work_order_name), '')::varchar(255) AS work_order_name,
    CASE WHEN lower(btrim(COALESCE(s.disabled, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
         THEN true ELSE false END AS disabled,
    CASE WHEN lower(btrim(COALESCE(s.source_deleted, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
         THEN 1 ELSE 0 END::int2 AS deleted
FROM cost_sync_stage.stg_work_order s
CROSS JOIN tmp_cost_sync_context c
LEFT JOIN "costree_mvp".cost_project p
  ON p.tenant_id = c.tenant_id AND p.project_code = s.project_code
LEFT JOIN "costree_mvp".cost_unit_dict d
  ON d.tenant_id = c.tenant_id AND d.accounting_unit_code = s.accounting_unit_code;

DROP TABLE IF EXISTS tmp_cost_sync_work_order_match;
CREATE TEMP TABLE tmp_cost_sync_work_order_match ON COMMIT PRESERVE ROWS AS
SELECT s.*,
       COALESCE(
           CASE WHEN s.source_work_order_id IS NOT NULL THEN (
               SELECT min(x.id) FROM "costree_mvp".cost_work_order x
               WHERE x.tenant_id = c.tenant_id
                 AND x.source_work_order_id = s.source_work_order_id
           ) ELSE NULL END,
           (
               SELECT min(x.id) FROM "costree_mvp".cost_work_order x
               WHERE x.tenant_id = c.tenant_id
                 AND x.project_code = s.project_code
                 AND x.unit_name = s.unit_name
                 AND x.work_order_no = s.work_order_no
           )
       ) AS target_id
FROM tmp_cost_sync_work_order s
CROSS JOIN tmp_cost_sync_context c;

UPDATE "costree_mvp".cost_work_order w
SET source_work_order_id = COALESCE(s.source_work_order_id, w.source_work_order_id),
    project_id = COALESCE(s.project_id, w.project_id),
    project_code = s.project_code,
    project_name = COALESCE(s.project_name, w.project_name),
    unit_id = COALESCE(s.unit_id, w.unit_id),
    unit_name = COALESCE(s.unit_name, w.unit_name),
    accounting_unit_code = COALESCE(s.accounting_unit_code, w.accounting_unit_code),
    accounting_unit_name = COALESCE(s.unit_name, w.accounting_unit_name),
    fiscal_year = '',
    work_order_no = s.work_order_no,
    work_order_name = COALESCE(s.work_order_name, w.work_order_name),
    disabled = s.disabled,
    deleted = s.deleted,
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_cost_sync_work_order_match s
CROSS JOIN tmp_cost_sync_context c
WHERE w.id = s.target_id;

INSERT INTO "costree_mvp".cost_work_order (
    source_work_order_id, project_id, project_code, project_name,
    unit_id, unit_name, accounting_unit_code, accounting_unit_name,
    fiscal_year, work_order_no, work_order_name,
    product_target_cost, contract_amount, income_amount, book_cost_amount,
    stage_codes, max_stage_code, subsystem_name, product_short_name,
    quantity, vertical_division, disabled, approved_amount, status,
    remark, creator, create_time, updater, update_time, deleted, tenant_id
)
SELECT
    s.source_work_order_id, s.project_id, s.project_code, s.project_name,
    s.unit_id, s.unit_name, s.accounting_unit_code, s.unit_name,
    '', s.work_order_no, s.work_order_name,
    NULL, NULL, NULL, 0,
    NULL, NULL, NULL, NULL,
    NULL, NULL, s.disabled, NULL, 'DRAFT',
    '外部工作令字典全量快照同步；填报字段由研制单位维护',
    c.source_tag, CURRENT_TIMESTAMP, c.source_tag, CURRENT_TIMESTAMP, 0, c.tenant_id
FROM tmp_cost_sync_work_order_match s
CROSS JOIN tmp_cost_sync_context c
WHERE s.deleted = 0 AND s.target_id IS NULL;

-- ---------------------------------------------------------------------
-- 6. 账面明细：源系统拥有全部明细字段，借贷都保留。
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_cost_sync_ledger;
CREATE TEMP TABLE tmp_cost_sync_ledger ON COMMIT PRESERVE ROWS AS
SELECT
    btrim(s.source_detail_id)::varchar(128) AS source_detail_id,
    NULLIF(btrim(s.fiscal_year), '')::varchar(16) AS fiscal_year,
    NULLIF(btrim(s.accounting_period), '')::varchar(16) AS accounting_period,
    CASE
        WHEN btrim(COALESCE(s.voucher_date, '')) = '' THEN NULL
        WHEN btrim(s.voucher_date) ~ '^[0-9]{8}$' THEN to_date(btrim(s.voucher_date), 'YYYYMMDD')
        ELSE to_date(substr(btrim(s.voucher_date), 1, 10), 'YYYY-MM-DD')
    END AS voucher_date,
    NULLIF(btrim(s.voucher_no), '')::varchar(128) AS voucher_no,
    COALESCE(NULLIF(btrim(s.accounting_unit_id), ''), d.accounting_unit_id)::varchar(128) AS accounting_unit_id,
    d.accounting_unit_code,
    d.accounting_unit_name,
    d.manage_unit_name,
    NULLIF(btrim(s.subject_id), '')::varchar(128) AS subject_id,
    NULLIF(btrim(s.subject_code), '')::varchar(128) AS subject_code,
    NULLIF(btrim(s.subject_name), '')::varchar(255) AS subject_name,
    p.id AS project_id,
    btrim(s.project_code)::varchar(128) AS project_code,
    NULLIF(btrim(s.source_project_id), '')::varchar(128) AS source_project_id,
    COALESCE(NULLIF(btrim(s.project_name), ''), p.project_name)::varchar(255) AS project_name,
    NULLIF(btrim(s.source_work_order_id), '')::varchar(128) AS source_work_order_id,
    btrim(s.work_order_no)::varchar(128) AS work_order_no,
    NULLIF(btrim(s.work_order_name), '')::varchar(255) AS work_order_name,
    CASE WHEN upper(btrim(s.debit_credit)) IN ('借', 'DEBIT', 'D') THEN '借' ELSE '贷' END::varchar(32) AS debit_credit,
    btrim(s.amount_yuan)::numeric(18,2) AS amount,
    (btrim(s.amount_yuan)::numeric / 10000.0)::numeric(18,2) AS amount_wan,
    NULLIF(btrim(s.summary_text), '')::varchar(1000) AS summary_text,
    CASE
        WHEN btrim(COALESCE(s.source_lastmodify, '')) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9]{2}:[0-9]{2}:[0-9]{2}'
        THEN to_timestamp(replace(substr(btrim(s.source_lastmodify), 1, 19), 'T', ' '), 'YYYY-MM-DD HH24:MI:SS')
        ELSE NULL
    END AS source_lastmodify,
    NULLIF(btrim(s.second_subject_code), '')::varchar(128) AS second_subject_code,
    NULLIF(btrim(s.second_subject_name), '')::varchar(255) AS second_subject_name,
    NULLIF(btrim(s.source_timestamp), '')::varchar(64) AS source_timestamp,
    CASE WHEN lower(btrim(COALESCE(s.source_deleted, '0'))) IN ('1', 'true', 't', '是', 'yes', 'y')
         THEN 1 ELSE 0 END::int2 AS deleted
FROM cost_sync_stage.stg_ledger_detail s
CROSS JOIN tmp_cost_sync_context c
LEFT JOIN "costree_mvp".cost_project p
  ON p.tenant_id = c.tenant_id AND p.project_code = s.project_code
LEFT JOIN "costree_mvp".cost_unit_dict d
  ON d.tenant_id = c.tenant_id AND d.accounting_unit_code = s.accounting_unit_code;

DROP TABLE IF EXISTS tmp_cost_sync_ledger_match;
CREATE TEMP TABLE tmp_cost_sync_ledger_match ON COMMIT PRESERVE ROWS AS
SELECT s.*,
       COALESCE(
           CASE WHEN s.source_work_order_id IS NOT NULL THEN (
               SELECT min(w.id) FROM "costree_mvp".cost_work_order w
               WHERE w.tenant_id = c.tenant_id
                 AND w.source_work_order_id = s.source_work_order_id
           ) ELSE NULL END,
           (
               SELECT min(w.id) FROM "costree_mvp".cost_work_order w
               WHERE w.tenant_id = c.tenant_id
                 AND w.project_code = s.project_code
                 AND w.unit_name = s.accounting_unit_name
                 AND w.work_order_no = s.work_order_no
           )
       ) AS work_order_id,
       (
           SELECT min(d.id) FROM "costree_mvp".cost_work_order_ledger_detail d
           WHERE d.tenant_id = c.tenant_id AND d.source_detail_id = s.source_detail_id
       ) AS target_id
FROM tmp_cost_sync_ledger s
CROSS JOIN tmp_cost_sync_context c;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM tmp_cost_sync_ledger_match
        WHERE deleted = 0
          AND (project_id IS NULL OR accounting_unit_name IS NULL OR work_order_id IS NULL)
    ) THEN
        RAISE EXCEPTION '账面明细同步时仍有活动记录无法关联项目、实际单位或工作令';
    END IF;
END $$;

UPDATE "costree_mvp".cost_work_order_ledger_detail d
SET fiscal_year = s.fiscal_year,
    accounting_period = s.accounting_period,
    voucher_date = s.voucher_date,
    voucher_no = s.voucher_no,
    accounting_unit_id = COALESCE(s.accounting_unit_id, d.accounting_unit_id),
    accounting_unit_code = COALESCE(s.accounting_unit_code, d.accounting_unit_code),
    accounting_unit_name = COALESCE(s.accounting_unit_name, d.accounting_unit_name),
    manage_unit_name = COALESCE(s.manage_unit_name, d.manage_unit_name),
    subject_id = s.subject_id,
    subject_code = s.subject_code,
    subject_name = s.subject_name,
    project_code = s.project_code,
    source_project_id = s.source_project_id,
    project_name = COALESCE(s.project_name, d.project_name),
    source_work_order_id = COALESCE(s.source_work_order_id, d.source_work_order_id),
    work_order_no = s.work_order_no,
    work_order_name = COALESCE(s.work_order_name, d.work_order_name),
    debit_credit = s.debit_credit,
    amount = s.amount,
    amount_wan = s.amount_wan,
    summary_text = s.summary_text,
    source_lastmodify = s.source_lastmodify,
    second_subject_code = s.second_subject_code,
    second_subject_name = s.second_subject_name,
    source_timestamp = s.source_timestamp,
    project_id = COALESCE(s.project_id, d.project_id),
    work_order_id = COALESCE(s.work_order_id, d.work_order_id),
    deleted = s.deleted,
    remark = '外部账面明细全量快照同步',
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_cost_sync_ledger_match s
CROSS JOIN tmp_cost_sync_context c
WHERE d.id = s.target_id;

INSERT INTO "costree_mvp".cost_work_order_ledger_detail (
    source_detail_id, fiscal_year, accounting_period, voucher_date, voucher_no,
    accounting_unit_id, accounting_unit_code, accounting_unit_name, manage_unit_name,
    subject_id, subject_code, subject_name,
    project_code, source_project_id, project_name,
    source_work_order_id, work_order_no, work_order_name,
    debit_credit, amount, amount_wan, summary_text, source_lastmodify,
    second_subject_code, second_subject_name, source_timestamp,
    resolved_stage_code, project_id, work_order_id,
    remark, creator, create_time, updater, update_time, deleted, tenant_id
)
SELECT
    s.source_detail_id, s.fiscal_year, s.accounting_period, s.voucher_date, s.voucher_no,
    s.accounting_unit_id, s.accounting_unit_code, s.accounting_unit_name, s.manage_unit_name,
    s.subject_id, s.subject_code, s.subject_name,
    s.project_code, s.source_project_id, s.project_name,
    s.source_work_order_id, s.work_order_no, s.work_order_name,
    s.debit_credit, s.amount, s.amount_wan, s.summary_text, s.source_lastmodify,
    s.second_subject_code, s.second_subject_name, s.source_timestamp,
    w.max_stage_code, s.project_id, s.work_order_id,
    '外部账面明细全量快照同步', c.source_tag, CURRENT_TIMESTAMP,
    c.source_tag, CURRENT_TIMESTAMP, 0, c.tenant_id
FROM tmp_cost_sync_ledger_match s
CROSS JOIN tmp_cost_sync_context c
JOIN "costree_mvp".cost_work_order w ON w.id = s.work_order_id
WHERE s.deleted = 0 AND s.target_id IS NULL;

UPDATE cost_sync_stage.sync_control
SET load_status = 'BUSINESS_SYNCED',
    synced_at = CURRENT_TIMESTAMP,
    remark = '业务表 UPDATE + INSERT 已完成，等待重算账面和最终验收'
WHERE id = 1;

UPDATE cost_sync_stage.sync_history h
SET stage_row_count = (
        SELECT count(*) FROM cost_sync_stage.stg_unit_dict
    ) + (
        SELECT count(*) FROM cost_sync_stage.stg_model_node
    ) + (
        SELECT count(*) FROM cost_sync_stage.stg_project
    ) + (
        SELECT count(*) FROM cost_sync_stage.stg_unit_amount
    ) + (
        SELECT count(*) FROM cost_sync_stage.stg_work_order
    ) + (
        SELECT count(*) FROM cost_sync_stage.stg_ledger_detail
    ),
    sync_status = 'BUSINESS_SYNCED',
    finish_time = NULL,
    remark = '业务表幂等同步完成'
FROM tmp_cost_sync_context c
WHERE h.batch_code = c.batch_code AND h.tenant_id = c.tenant_id;

INSERT INTO cost_sync_stage.sync_history (
    batch_code, tenant_id, source_tag, stage_row_count, sync_status, start_time, remark
)
SELECT c.batch_code, c.tenant_id, c.source_tag,
       (SELECT count(*) FROM cost_sync_stage.stg_unit_dict)
       + (SELECT count(*) FROM cost_sync_stage.stg_model_node)
       + (SELECT count(*) FROM cost_sync_stage.stg_project)
       + (SELECT count(*) FROM cost_sync_stage.stg_unit_amount)
       + (SELECT count(*) FROM cost_sync_stage.stg_work_order)
       + (SELECT count(*) FROM cost_sync_stage.stg_ledger_detail),
       'BUSINESS_SYNCED', CURRENT_TIMESTAMP, '业务表幂等同步完成'
FROM tmp_cost_sync_context c
WHERE NOT EXISTS (
    SELECT 1 FROM cost_sync_stage.sync_history h
    WHERE h.batch_code = c.batch_code AND h.tenant_id = c.tenant_id
);

COMMIT;

SELECT tenant_id, batch_code, load_status, loaded_at, synced_at, remark
FROM cost_sync_stage.sync_control
WHERE id = 1;
