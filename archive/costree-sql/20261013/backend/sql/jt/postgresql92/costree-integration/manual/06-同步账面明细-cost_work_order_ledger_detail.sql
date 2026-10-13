-- 成本库内网分表同步 06：账面明细 cost_work_order_ledger_detail
-- 账面原值 amount 单位为元；amount_wan = amount / 10000。
-- 借、贷全部导入，仅借方参与后续账面快照、预警和八项组成。

BEGIN;
SELECT pg_advisory_xact_lock(hashtext('costree-manual-ledger-sync'));

DROP TABLE IF EXISTS tmp_manual_context;
CREATE TEMP TABLE tmp_manual_context ON COMMIT PRESERVE ROWS AS
SELECT 124::int8 AS tenant_id, 'manual_ledger_sync'::varchar(64) AS source_tag;

DROP TABLE IF EXISTS tmp_manual_ledger_raw;

-- =====================================================================
-- 【现场只修改本段】把内网账面原表整理成以下固定输出列。
-- source_detail_id 必须使用原表真正唯一的明细主键，不能拼接年度或行号。
-- amount_text 必须是“元”；actual_unit_name 必须是实际核算单位。
-- source_work_order_id 优先使用工作令字典源主键，缺失时才走业务键兜底。
-- =====================================================================
CREATE TEMP TABLE tmp_manual_ledger_raw ON COMMIT PRESERVE ROWS AS
SELECT
    btrim(s.ysnm)::varchar(128) AS source_detail_id,
    NULLIF(btrim(s.kjnd), '')::varchar(16) AS fiscal_year,
    NULLIF(btrim(s.kjqj), '')::varchar(16) AS accounting_period,
    NULLIF(btrim(s.pzrq), '')::varchar(32) AS voucher_date_text,
    NULLIF(btrim(s.pzbh), '')::varchar(128) AS voucher_no,
    NULLIF(btrim(s.dwid), '')::varchar(128) AS accounting_unit_id,
    btrim(s.dwbh)::varchar(128) AS actual_unit_code,
    btrim(s.dwmc)::varchar(255) AS actual_unit_name,
    NULLIF(btrim(s.gldw), '')::varchar(255) AS source_manage_unit_name,
    NULLIF(btrim(s.kmid), '')::varchar(128) AS subject_id,
    NULLIF(btrim(s.kmbh), '')::varchar(128) AS subject_code,
    NULLIF(btrim(s.kmmc), '')::varchar(255) AS subject_name,
    btrim(s.xmbh)::varchar(128) AS project_code,
    NULLIF(btrim(s.xmnm), '')::varchar(128) AS source_project_id,
    NULLIF(btrim(s.xmmc), '')::varchar(255) AS project_name,
    NULLIF(btrim(s.gzlnm), '')::varchar(128) AS source_work_order_id,
    btrim(s.gzllb)::varchar(128) AS work_order_no,
    NULLIF(btrim(s.gzlmc), '')::varchar(255) AS work_order_name,
    btrim(s.jzfx)::varchar(32) AS debit_credit_text,
    NULLIF(btrim(s.je), '')::varchar(64) AS amount_text,
    NULLIF(btrim(s.yt), '')::varchar(1000) AS summary_text,
    NULLIF(btrim(s.lastmodifiedtime), '')::varchar(64) AS source_lastmodify_text,
    NULLIF(btrim(s.ejkmbh), '')::varchar(128) AS second_subject_code,
    NULLIF(btrim(s.ejkmmc), '')::varchar(255) AS second_subject_name,
    NULLIF(btrim(s.dwts), '')::varchar(64) AS source_timestamp,
    CASE WHEN lower(btrim(COALESCE(s.source_deleted, '0'))) IN
        ('1', 'true', 't', '是', 'yes', 'y') THEN 1 ELSE 0 END::int2 AS deleted
FROM cost_integration.dws_bu_pz_pzmx_gzl s;
-- =========================【现场字段映射区结束】=========================

DO $$
DECLARE
    v_tenant_id int8 := (SELECT tenant_id FROM tmp_manual_context);
BEGIN
    IF EXISTS (
        SELECT 1 FROM tmp_manual_ledger_raw
        WHERE source_detail_id IS NULL OR btrim(source_detail_id) = ''
           OR project_code IS NULL OR btrim(project_code) = ''
           OR actual_unit_code IS NULL OR btrim(actual_unit_code) = ''
           OR actual_unit_name IS NULL OR btrim(actual_unit_name) = ''
           OR work_order_no IS NULL OR btrim(work_order_no) = ''
           OR amount_text IS NULL OR btrim(amount_text) = ''
    ) THEN
        RAISE EXCEPTION '账面明细存在空源主键、项目、实际单位、工作令编号或金额';
    END IF;

    IF EXISTS (
        SELECT source_detail_id FROM tmp_manual_ledger_raw
        GROUP BY source_detail_id HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '账面原表 source_detail_id 不唯一，禁止继续同步';
    END IF;

    IF EXISTS (
        SELECT 1 FROM tmp_manual_ledger_raw
        WHERE amount_text !~ '^[+-]?[0-9]+([.][0-9]+)?$'
    ) THEN
        RAISE EXCEPTION '账面金额存在无法转换为数字的 je/amount 值';
    END IF;

    IF EXISTS (
        SELECT 1 FROM tmp_manual_ledger_raw
        WHERE voucher_date_text IS NOT NULL
          AND voucher_date_text !~ '^[0-9]{8}$'
          AND voucher_date_text !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
    ) THEN
        RAISE EXCEPTION '凭证日期只支持 YYYYMMDD 或 YYYY-MM-DD 格式';
    END IF;

    IF EXISTS (
        SELECT 1 FROM tmp_manual_ledger_raw
        WHERE upper(debit_credit_text) NOT IN ('借', '贷', 'DEBIT', 'CREDIT')
    ) THEN
        RAISE EXCEPTION '记账方向只允许借/贷或 DEBIT/CREDIT';
    END IF;

    IF EXISTS (
        SELECT source_detail_id
        FROM cost_work_order_ledger_detail
        WHERE tenant_id = v_tenant_id
        GROUP BY source_detail_id HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION '目标账面明细存在重复 source_detail_id';
    END IF;
END $$;

DROP TABLE IF EXISTS tmp_manual_ledger_source;
CREATE TEMP TABLE tmp_manual_ledger_source ON COMMIT PRESERVE ROWS AS
SELECT
    r.source_detail_id, r.fiscal_year, r.accounting_period,
    CASE
        WHEN r.voucher_date_text IS NULL THEN NULL
        WHEN r.voucher_date_text ~ '^[0-9]{8}$'
            THEN to_date(r.voucher_date_text, 'YYYYMMDD')
        ELSE to_date(substr(r.voucher_date_text, 1, 10), 'YYYY-MM-DD')
    END AS voucher_date,
    r.voucher_no, r.accounting_unit_id, r.actual_unit_code, r.actual_unit_name,
    r.source_manage_unit_name, r.subject_id, r.subject_code, r.subject_name,
    r.project_code, r.source_project_id, r.project_name,
    r.source_work_order_id, r.work_order_no, r.work_order_name,
    CASE WHEN upper(r.debit_credit_text) IN ('借', 'DEBIT') THEN '借' ELSE '贷' END::varchar(32)
        AS debit_credit,
    r.amount_text::numeric(18,2) AS amount,
    r.summary_text,
    CASE
        WHEN r.source_lastmodify_text ~
             '^[0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9]{2}:[0-9]{2}:[0-9]{2}'
        THEN to_timestamp(
            replace(substr(r.source_lastmodify_text, 1, 19), 'T', ' '),
            'YYYY-MM-DD HH24:MI:SS'
        )
        ELSE NULL
    END AS source_lastmodify,
    r.second_subject_code, r.second_subject_name, r.source_timestamp, r.deleted
FROM tmp_manual_ledger_raw r;

DROP TABLE IF EXISTS tmp_manual_ledger_match;
CREATE TEMP TABLE tmp_manual_ledger_match ON COMMIT PRESERVE ROWS AS
SELECT
    s.*,
    COALESCE(
        CASE WHEN s.source_work_order_id IS NOT NULL THEN (
            SELECT min(w.id) FROM cost_work_order w
            WHERE w.tenant_id = c.tenant_id
              AND w.source_work_order_id = s.source_work_order_id
        ) ELSE NULL END,
        (
            SELECT min(w.id) FROM cost_work_order w
            WHERE w.tenant_id = c.tenant_id
              AND w.project_code = s.project_code
              AND w.unit_name = s.actual_unit_name
              AND w.work_order_no = s.work_order_no
        )
    ) AS matched_work_order_id
FROM tmp_manual_ledger_source s
CROSS JOIN tmp_manual_context c;

DO $$
DECLARE
    v_tenant_id int8 := (SELECT tenant_id FROM tmp_manual_context);
BEGIN
    IF EXISTS (
        SELECT 1 FROM tmp_manual_ledger_match s
        WHERE s.deleted = 0
          AND NOT EXISTS (
              SELECT 1 FROM cost_project p
              WHERE p.tenant_id = v_tenant_id AND p.deleted = 0
                AND p.project_code = s.project_code
          )
    ) THEN
        RAISE EXCEPTION '账面明细存在无法匹配 cost_project 的项目编号';
    END IF;

    IF EXISTS (
        SELECT 1 FROM tmp_manual_ledger_match s
        WHERE s.deleted = 0
          AND NOT EXISTS (
              SELECT 1 FROM cost_unit_dict d
              WHERE d.tenant_id = v_tenant_id AND d.deleted = 0
                AND d.accounting_unit_code = s.actual_unit_code
                AND d.accounting_unit_name = s.actual_unit_name
          )
    ) THEN
        RAISE EXCEPTION '账面明细存在无法按编码 + 名称匹配单位字典的实际核算单位';
    END IF;

    IF EXISTS (
        SELECT 1 FROM tmp_manual_ledger_match
        WHERE deleted = 0 AND matched_work_order_id IS NULL
    ) THEN
        RAISE EXCEPTION '账面明细存在无法关联工作令的记录';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM tmp_manual_ledger_match s
        JOIN cost_work_order w ON w.id = s.matched_work_order_id
        WHERE s.deleted = 0
          AND (w.project_code <> s.project_code
            OR w.unit_name <> s.actual_unit_name
            OR w.work_order_no <> s.work_order_no)
    ) THEN
        RAISE EXCEPTION '源工作令主键匹配结果与项目、实际单位或工作令编号不一致';
    END IF;
END $$;

DROP TABLE IF EXISTS tmp_manual_ledger_ready;
CREATE TEMP TABLE tmp_manual_ledger_ready ON COMMIT PRESERVE ROWS AS
SELECT
    s.source_detail_id, s.fiscal_year, s.accounting_period, s.voucher_date, s.voucher_no,
    COALESCE(s.accounting_unit_id, d.accounting_unit_id) AS accounting_unit_id,
    d.accounting_unit_code, d.accounting_unit_name, d.manage_unit_name,
    s.subject_id, s.subject_code, s.subject_name,
    p.project_code, s.source_project_id, COALESCE(s.project_name, p.project_name) AS project_name,
    w.source_work_order_id, w.work_order_no,
    COALESCE(s.work_order_name, w.work_order_name) AS work_order_name,
    s.debit_credit, s.amount, (s.amount / 10000.0)::numeric(18,2) AS amount_wan,
    s.summary_text, s.source_lastmodify,
    s.second_subject_code, s.second_subject_name, s.source_timestamp,
    w.max_stage_code AS resolved_stage_code,
    p.id AS project_id, w.id AS work_order_id, s.deleted
FROM tmp_manual_ledger_match s
JOIN tmp_manual_context c ON 1 = 1
JOIN cost_project p
  ON p.tenant_id = c.tenant_id AND p.deleted = 0
 AND p.project_code = s.project_code
JOIN cost_unit_dict d
  ON d.tenant_id = c.tenant_id AND d.deleted = 0
 AND d.accounting_unit_code = s.actual_unit_code
 AND d.accounting_unit_name = s.actual_unit_name
JOIN cost_work_order w ON w.id = s.matched_work_order_id;

UPDATE cost_work_order_ledger_detail d
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
    deleted = s.deleted,
    remark = '内网账面明细分表增量同步',
    updater = c.source_tag,
    update_time = CURRENT_TIMESTAMP
FROM tmp_manual_ledger_ready s
CROSS JOIN tmp_manual_context c
WHERE d.tenant_id = c.tenant_id
  AND d.source_detail_id = s.source_detail_id;

INSERT INTO cost_work_order_ledger_detail (
    source_detail_id, fiscal_year, accounting_period, voucher_date, voucher_no,
    accounting_unit_id, accounting_unit_code, accounting_unit_name, manage_unit_name,
    subject_id, subject_code, subject_name,
    project_code, source_project_id, project_name,
    source_work_order_id, work_order_no, work_order_name,
    debit_credit, amount, amount_wan, summary_text, source_lastmodify,
    second_subject_code, second_subject_name, source_timestamp,
    resolved_stage_code, project_id, work_order_id,
    remark, creator, updater, deleted, tenant_id
)
SELECT
    s.source_detail_id, s.fiscal_year, s.accounting_period, s.voucher_date, s.voucher_no,
    s.accounting_unit_id, s.accounting_unit_code, s.accounting_unit_name, s.manage_unit_name,
    s.subject_id, s.subject_code, s.subject_name,
    s.project_code, s.source_project_id, s.project_name,
    s.source_work_order_id, s.work_order_no, s.work_order_name,
    s.debit_credit, s.amount, s.amount_wan, s.summary_text, s.source_lastmodify,
    s.second_subject_code, s.second_subject_name, s.source_timestamp,
    s.resolved_stage_code, s.project_id, s.work_order_id,
    '内网账面明细分表增量同步', c.source_tag, c.source_tag, s.deleted, c.tenant_id
FROM tmp_manual_ledger_ready s
CROSS JOIN tmp_manual_context c
WHERE NOT EXISTS (
    SELECT 1 FROM cost_work_order_ledger_detail d
    WHERE d.tenant_id = c.tenant_id
      AND d.source_detail_id = s.source_detail_id
);

-- 导入后验收：三项都应为 0；方向分布用于确认贷方已保留。
SELECT count(*) AS source_ledger_not_written
FROM tmp_manual_ledger_ready s
CROSS JOIN tmp_manual_context c
WHERE NOT EXISTS (
    SELECT 1 FROM cost_work_order_ledger_detail d
    WHERE d.tenant_id = c.tenant_id
      AND d.source_detail_id = s.source_detail_id
);

SELECT count(*) AS amount_unit_conversion_error
FROM cost_work_order_ledger_detail d
CROSS JOIN tmp_manual_context c
WHERE d.tenant_id = c.tenant_id AND d.deleted = 0
  AND abs(COALESCE(d.amount_wan, 0) - COALESCE(d.amount, 0) / 10000.0) > 0.01;

SELECT debit_credit, count(*) AS detail_count, sum(amount_wan) AS amount_wan
FROM cost_work_order_ledger_detail d
CROSS JOIN tmp_manual_context c
WHERE d.tenant_id = c.tenant_id AND d.deleted = 0
GROUP BY debit_credit
ORDER BY debit_credit;

COMMIT;
