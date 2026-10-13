-- 成本金额同步模板（PostgreSQL 14+）
-- 用途：预分预控项目单位累计金额、逻辑工作令、工作令账面明细的幂等同步。
-- 金额口径：单位金额为万元；账面明细 amount 为元，amount_wan 为万元；仅“借”参与账面汇总。

BEGIN;

CREATE TEMP TABLE tmp_cost_sync_context (
    tenant_id int8 NOT NULL
) ON COMMIT DROP;
INSERT INTO tmp_cost_sync_context VALUES (124); -- 按内网租户修改

CREATE TEMP TABLE tmp_cost_unit_amount_sync (
    source_record_id   varchar(128),
    source_update_time timestamp,
    project_code       varchar(128) NOT NULL,
    project_name       varchar(255),
    unit_name          varchar(255) NOT NULL,
    contract_amount    numeric(18,2),
    income_amount      numeric(18,2),
    target_cost_amount numeric(18,2),
    approved_amount    numeric(18,2),
    source_deleted     int2 NOT NULL DEFAULT 0,
    UNIQUE (project_code, unit_name)
) ON COMMIT DROP;

CREATE TEMP TABLE tmp_cost_work_order_sync (
    source_work_order_id varchar(128),
    project_code         varchar(128) NOT NULL,
    project_name         varchar(255),
    unit_name            varchar(255) NOT NULL,
    accounting_unit_code varchar(128),
    accounting_unit_name varchar(255),
    work_order_no        varchar(128) NOT NULL,
    work_order_name      varchar(255),
    stage_codes          varchar(255),
    max_stage_code       varchar(64),
    subsystem_name       varchar(255),
    product_short_name   varchar(255),
    quantity             int4,
    vertical_division    bool,
    disabled             bool NOT NULL DEFAULT false,
    source_deleted       int2 NOT NULL DEFAULT 0,
    UNIQUE (project_code, unit_name, work_order_no)
) ON COMMIT DROP;

CREATE TEMP TABLE tmp_cost_ledger_sync (
    source_detail_id     varchar(128) NOT NULL UNIQUE,
    fiscal_year          varchar(16) NOT NULL,
    accounting_period    varchar(16),
    voucher_date         date,
    voucher_no           varchar(128),
    accounting_unit_id   varchar(128),
    accounting_unit_code varchar(128),
    accounting_unit_name varchar(255) NOT NULL,
    manage_unit_name     varchar(255),
    subject_id           varchar(128),
    subject_code         varchar(128),
    subject_name         varchar(255),
    project_code         varchar(128) NOT NULL,
    source_project_id    varchar(128),
    project_name         varchar(255),
    source_work_order_id varchar(128),
    work_order_no        varchar(128) NOT NULL,
    work_order_name      varchar(255),
    debit_credit         varchar(32) NOT NULL,
    amount               numeric(18,2),
    summary_text         varchar(1000),
    source_lastmodify    timestamp,
    second_subject_code  varchar(128),
    second_subject_name  varchar(255),
    source_timestamp     varchar(64),
    resolved_stage_code  varchar(64),
    source_deleted       int2 NOT NULL DEFAULT 0
) ON COMMIT DROP;

-- 工作流在这里批量写入三张临时表。允许某一类临时表为空，但源明细 ID 必须稳定。
-- INSERT INTO tmp_cost_unit_amount_sync (...) VALUES (...);
-- INSERT INTO tmp_cost_work_order_sync (...) VALUES (...);
-- INSERT INTO tmp_cost_ledger_sync (...) VALUES (...);

-- 自动校验：任一业务键无法唯一匹配或记账方向非法时终止事务。
DO $$
DECLARE
    v_tenant_id int8 := (SELECT tenant_id FROM tmp_cost_sync_context);
BEGIN
    IF EXISTS (
        SELECT 1 FROM tmp_cost_unit_amount_sync s
        LEFT JOIN (
            SELECT project_code, count(*) AS project_count
            FROM cost_project WHERE tenant_id = v_tenant_id AND deleted = 0
            GROUP BY project_code
        ) p ON p.project_code = s.project_code
        WHERE COALESCE(p.project_count, 0) <> 1
    ) THEN
        RAISE EXCEPTION '单位金额存在无法唯一匹配的项目编码';
    END IF;

    IF EXISTS (
        SELECT 1 FROM tmp_cost_work_order_sync s
        LEFT JOIN (
            SELECT project_code, count(*) AS project_count
            FROM cost_project WHERE tenant_id = v_tenant_id AND deleted = 0
            GROUP BY project_code
        ) p ON p.project_code = s.project_code
        WHERE COALESCE(p.project_count, 0) <> 1
    ) THEN
        RAISE EXCEPTION '工作令存在无法唯一匹配的项目编码';
    END IF;

    IF EXISTS (
        SELECT 1 FROM tmp_cost_ledger_sync l
        WHERE l.source_deleted = 0 AND btrim(l.debit_credit) NOT IN ('借', '贷')
    ) THEN
        RAISE EXCEPTION '账面明细记账方向必须标准化为借或贷';
    END IF;

    IF EXISTS (
        SELECT 1 FROM tmp_cost_ledger_sync l
        WHERE l.source_deleted = 0
          AND NOT EXISTS (
              SELECT 1 FROM tmp_cost_work_order_sync w
              WHERE w.project_code = l.project_code
                AND w.unit_name = l.accounting_unit_name
                AND w.work_order_no = l.work_order_no
                AND w.source_deleted = 0
          )
          AND NOT EXISTS (
              SELECT 1 FROM cost_work_order w
              WHERE w.tenant_id = v_tenant_id AND w.deleted = 0
                AND w.project_code = l.project_code
                AND w.unit_name = l.accounting_unit_name
                AND w.work_order_no = l.work_order_no
          )
    ) THEN
        RAISE EXCEPTION '账面明细存在缺少对应逻辑工作令的记录';
    END IF;
END $$;

-- 1. 预分预控项目单位累计金额。四项金额覆盖更新，不做累加。
INSERT INTO cost_unit_cost_detail (
    project_id, project_code, project_name, domain_code, domain_name, model_node_id, model_code, model_name,
    unit_id, unit_name, stage_code, source_record_id, source_update_time,
    contract_amount, income_amount, target_cost_amount, approved_amount,
    creator, create_time, updater, update_time, deleted, tenant_id
)
SELECT p.id, s.project_code, COALESCE(NULLIF(s.project_name, ''), p.project_name),
       p.domain_code, p.domain_name, p.model_node_id, p.model_code, p.model_name,
       (SELECT min(d.id) FROM cost_unit_dict d
        WHERE d.tenant_id = c.tenant_id AND d.deleted = 0
          AND d.accounting_unit_name = s.unit_name),
       s.unit_name, 'ALL', s.source_record_id, s.source_update_time,
       s.contract_amount, s.income_amount, s.target_cost_amount, s.approved_amount,
       'cost_sync', CURRENT_TIMESTAMP, 'cost_sync', CURRENT_TIMESTAMP, s.source_deleted, c.tenant_id
FROM tmp_cost_unit_amount_sync s
CROSS JOIN tmp_cost_sync_context c
JOIN cost_project p ON p.tenant_id = c.tenant_id AND p.deleted = 0
  AND p.project_code = s.project_code
ON CONFLICT (tenant_id, project_code, unit_name) DO UPDATE SET
    project_id = EXCLUDED.project_id, project_name = EXCLUDED.project_name,
    domain_code = EXCLUDED.domain_code, domain_name = EXCLUDED.domain_name,
    model_node_id = EXCLUDED.model_node_id, model_code = EXCLUDED.model_code, model_name = EXCLUDED.model_name,
    unit_id = EXCLUDED.unit_id, stage_code = 'ALL', source_record_id = EXCLUDED.source_record_id,
    source_update_time = EXCLUDED.source_update_time, contract_amount = EXCLUDED.contract_amount,
    income_amount = EXCLUDED.income_amount, target_cost_amount = EXCLUDED.target_cost_amount,
    approved_amount = EXCLUDED.approved_amount, updater = 'cost_sync', update_time = CURRENT_TIMESTAMP,
    deleted = EXCLUDED.deleted;

-- 2. 逻辑工作令。固定金额由研制单位维护，源映射同步不覆盖；账面由明细重建。
INSERT INTO cost_work_order (
    source_work_order_id, project_id, project_code, project_name, unit_id, unit_name,
    accounting_unit_code, accounting_unit_name, fiscal_year, work_order_no, work_order_name,
    stage_codes, max_stage_code, subsystem_name, product_short_name, quantity, vertical_division,
    disabled, creator, create_time, updater, update_time, deleted, tenant_id
)
SELECT s.source_work_order_id, p.id, s.project_code, COALESCE(NULLIF(s.project_name, ''), p.project_name),
       (SELECT min(d.id) FROM cost_unit_dict d
        WHERE d.tenant_id = c.tenant_id AND d.deleted = 0
          AND d.accounting_unit_name = s.unit_name),
       s.unit_name, s.accounting_unit_code, COALESCE(NULLIF(s.accounting_unit_name, ''), s.unit_name),
       '', s.work_order_no, s.work_order_name, s.stage_codes, s.max_stage_code,
       s.subsystem_name, s.product_short_name, s.quantity, s.vertical_division,
       s.disabled, 'cost_sync', CURRENT_TIMESTAMP, 'cost_sync', CURRENT_TIMESTAMP,
       s.source_deleted, c.tenant_id
FROM tmp_cost_work_order_sync s
CROSS JOIN tmp_cost_sync_context c
JOIN cost_project p ON p.tenant_id = c.tenant_id AND p.deleted = 0
  AND p.project_code = s.project_code
ON CONFLICT (tenant_id, project_code, unit_name, work_order_no) DO UPDATE SET
    source_work_order_id = EXCLUDED.source_work_order_id, project_id = EXCLUDED.project_id,
    project_name = EXCLUDED.project_name, unit_id = EXCLUDED.unit_id,
    accounting_unit_code = EXCLUDED.accounting_unit_code,
    accounting_unit_name = EXCLUDED.accounting_unit_name, work_order_name = EXCLUDED.work_order_name,
    stage_codes = COALESCE(NULLIF(EXCLUDED.stage_codes, ''), cost_work_order.stage_codes),
    max_stage_code = COALESCE(NULLIF(EXCLUDED.max_stage_code, ''), cost_work_order.max_stage_code),
    subsystem_name = COALESCE(NULLIF(EXCLUDED.subsystem_name, ''), cost_work_order.subsystem_name),
    product_short_name = COALESCE(NULLIF(EXCLUDED.product_short_name, ''), cost_work_order.product_short_name),
    quantity = COALESCE(EXCLUDED.quantity, cost_work_order.quantity),
    vertical_division = EXCLUDED.vertical_division, disabled = EXCLUDED.disabled,
    updater = 'cost_sync', update_time = CURRENT_TIMESTAMP, deleted = EXCLUDED.deleted;

-- 记录账面明细变更前后的业务键，避免明细改挂工作令后旧快照残留。
CREATE TEMP TABLE tmp_cost_snapshot_key (
    project_code varchar(128) NOT NULL,
    unit_name varchar(255) NOT NULL,
    work_order_no varchar(128) NOT NULL,
    PRIMARY KEY (project_code, unit_name, work_order_no)
) ON COMMIT DROP;
INSERT INTO tmp_cost_snapshot_key
SELECT project_code, accounting_unit_name, work_order_no FROM tmp_cost_ledger_sync
ON CONFLICT DO NOTHING;
INSERT INTO tmp_cost_snapshot_key
SELECT d.project_code, d.accounting_unit_name, d.work_order_no
FROM cost_work_order_ledger_detail d
JOIN tmp_cost_ledger_sync s ON s.source_detail_id = d.source_detail_id
CROSS JOIN tmp_cost_sync_context c
WHERE d.tenant_id = c.tenant_id
ON CONFLICT DO NOTHING;

-- 3. 账面明细按稳定源 ID 覆盖更新，万元字段由元换算。
INSERT INTO cost_work_order_ledger_detail (
    source_detail_id, fiscal_year, accounting_period, voucher_date, voucher_no,
    accounting_unit_id, accounting_unit_code, accounting_unit_name, manage_unit_name,
    subject_id, subject_code, subject_name, project_code, source_project_id, project_name,
    source_work_order_id, work_order_no, work_order_name, debit_credit, amount, amount_wan,
    summary_text, source_lastmodify, second_subject_code, second_subject_name, source_timestamp,
    resolved_stage_code, project_id, work_order_id, creator, create_time, updater, update_time,
    deleted, tenant_id
)
SELECT s.source_detail_id, s.fiscal_year, s.accounting_period, s.voucher_date, s.voucher_no,
       s.accounting_unit_id, s.accounting_unit_code, s.accounting_unit_name, s.manage_unit_name,
       s.subject_id, s.subject_code, s.subject_name, s.project_code, s.source_project_id,
       COALESCE(NULLIF(s.project_name, ''), p.project_name), s.source_work_order_id,
       s.work_order_no, s.work_order_name, btrim(s.debit_credit), s.amount,
       CASE WHEN s.amount IS NULL THEN NULL ELSE round(s.amount / 10000.0, 2) END,
       s.summary_text, s.source_lastmodify, s.second_subject_code, s.second_subject_name,
       s.source_timestamp, COALESCE(NULLIF(s.resolved_stage_code, ''), w.max_stage_code),
       p.id, w.id, 'cost_sync', CURRENT_TIMESTAMP, 'cost_sync', CURRENT_TIMESTAMP,
       s.source_deleted, c.tenant_id
FROM tmp_cost_ledger_sync s
CROSS JOIN tmp_cost_sync_context c
JOIN cost_project p ON p.tenant_id = c.tenant_id AND p.deleted = 0
  AND p.project_code = s.project_code
JOIN cost_work_order w ON w.tenant_id = c.tenant_id
  AND w.project_code = s.project_code AND w.unit_name = s.accounting_unit_name
  AND w.work_order_no = s.work_order_no
ON CONFLICT (tenant_id, source_detail_id) DO UPDATE SET
    fiscal_year = EXCLUDED.fiscal_year, accounting_period = EXCLUDED.accounting_period,
    voucher_date = EXCLUDED.voucher_date, voucher_no = EXCLUDED.voucher_no,
    accounting_unit_id = EXCLUDED.accounting_unit_id,
    accounting_unit_code = EXCLUDED.accounting_unit_code,
    accounting_unit_name = EXCLUDED.accounting_unit_name, manage_unit_name = EXCLUDED.manage_unit_name,
    subject_id = EXCLUDED.subject_id, subject_code = EXCLUDED.subject_code, subject_name = EXCLUDED.subject_name,
    project_code = EXCLUDED.project_code, source_project_id = EXCLUDED.source_project_id,
    project_name = EXCLUDED.project_name, source_work_order_id = EXCLUDED.source_work_order_id,
    work_order_no = EXCLUDED.work_order_no, work_order_name = EXCLUDED.work_order_name,
    debit_credit = EXCLUDED.debit_credit, amount = EXCLUDED.amount, amount_wan = EXCLUDED.amount_wan,
    summary_text = EXCLUDED.summary_text, source_lastmodify = EXCLUDED.source_lastmodify,
    second_subject_code = EXCLUDED.second_subject_code,
    second_subject_name = EXCLUDED.second_subject_name, source_timestamp = EXCLUDED.source_timestamp,
    resolved_stage_code = EXCLUDED.resolved_stage_code, project_id = EXCLUDED.project_id,
    work_order_id = EXCLUDED.work_order_id, updater = 'cost_sync',
    update_time = CURRENT_TIMESTAMP, deleted = EXCLUDED.deleted;

-- 4. 仅重建本批受影响逻辑工作令的跨年度借方账面快照。
UPDATE cost_work_order w
SET book_cost_amount = 0, update_time = CURRENT_TIMESTAMP
FROM tmp_cost_snapshot_key k, tmp_cost_sync_context c
WHERE w.tenant_id = c.tenant_id AND w.project_code = k.project_code
  AND w.unit_name = k.unit_name AND w.work_order_no = k.work_order_no;

WITH debit_snapshot AS (
    SELECT d.project_code, d.accounting_unit_name AS unit_name, d.work_order_no,
           SUM(COALESCE(d.amount / 10000.0, d.amount_wan, 0)) AS book_cost_amount
    FROM cost_work_order_ledger_detail d
    JOIN tmp_cost_snapshot_key k ON k.project_code = d.project_code
      AND k.unit_name = d.accounting_unit_name AND k.work_order_no = d.work_order_no
    CROSS JOIN tmp_cost_sync_context c
    WHERE d.tenant_id = c.tenant_id AND d.deleted = 0 AND btrim(d.debit_credit) = '借'
    GROUP BY d.project_code, d.accounting_unit_name, d.work_order_no
)
UPDATE cost_work_order w
SET book_cost_amount = s.book_cost_amount, update_time = CURRENT_TIMESTAMP
FROM debit_snapshot s, tmp_cost_sync_context c
WHERE w.tenant_id = c.tenant_id AND w.project_code = s.project_code
  AND w.unit_name = s.unit_name AND w.work_order_no = s.work_order_no;

-- 对账：以下两条查询都应返回 0 行。
SELECT s.project_code, s.unit_name,
       s.contract_amount AS source_contract, d.contract_amount AS target_contract,
       s.income_amount AS source_income, d.income_amount AS target_income,
       s.target_cost_amount AS source_target, d.target_cost_amount AS target_target,
       s.approved_amount AS source_approved, d.approved_amount AS target_approved
FROM tmp_cost_unit_amount_sync s
CROSS JOIN tmp_cost_sync_context c
JOIN cost_unit_cost_detail d ON d.tenant_id = c.tenant_id
  AND d.project_code = s.project_code AND d.unit_name = s.unit_name
WHERE s.contract_amount IS DISTINCT FROM d.contract_amount
   OR s.income_amount IS DISTINCT FROM d.income_amount
   OR s.target_cost_amount IS DISTINCT FROM d.target_cost_amount
   OR s.approved_amount IS DISTINCT FROM d.approved_amount
   OR d.stage_code <> 'ALL';

SELECT w.project_code, w.unit_name, w.work_order_no,
       w.book_cost_amount AS snapshot_amount,
       COALESCE(SUM(CASE WHEN d.deleted = 0 AND btrim(d.debit_credit) = '借'
                         THEN COALESCE(d.amount / 10000.0, d.amount_wan, 0) ELSE 0 END), 0) AS ledger_amount
FROM cost_work_order w
CROSS JOIN tmp_cost_sync_context c
JOIN tmp_cost_snapshot_key k ON k.project_code = w.project_code AND k.unit_name = w.unit_name
  AND k.work_order_no = w.work_order_no
LEFT JOIN cost_work_order_ledger_detail d ON d.tenant_id = w.tenant_id
  AND d.project_code = w.project_code AND d.accounting_unit_name = w.unit_name
  AND d.work_order_no = w.work_order_no
WHERE w.tenant_id = c.tenant_id
GROUP BY w.id, w.project_code, w.unit_name, w.work_order_no, w.book_cost_amount
HAVING abs(COALESCE(w.book_cost_amount, 0) -
           COALESCE(SUM(CASE WHEN d.deleted = 0 AND btrim(d.debit_credit) = '借'
                             THEN COALESCE(d.amount / 10000.0, d.amount_wan, 0) ELSE 0 END), 0)) > 0.01;

COMMIT;
