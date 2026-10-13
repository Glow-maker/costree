-- 成本金额同步模板（MySQL 8.0+）
-- 用途：预分预控项目单位累计金额、年度工作令、工作令账面明细的幂等同步。
-- 使用顺序：创建暂存表 -> 工作流写暂存表 -> 查看校验结果 -> 执行业务落库 -> 查看对账结果。
-- 金额口径：单位金额为万元；账面明细 amount 为元，amount_wan 为万元；仅“借”参与账面汇总。

SET @sync_tenant_id = 124; -- 按内网租户修改

DROP TEMPORARY TABLE IF EXISTS tmp_cost_unit_amount_sync;
CREATE TEMPORARY TABLE tmp_cost_unit_amount_sync (
  source_record_id   varchar(128) NULL,
  source_update_time datetime NULL,
  project_code       varchar(128) NOT NULL,
  project_name       varchar(255) NULL,
  unit_name          varchar(255) NOT NULL,
  contract_amount    decimal(18,2) NULL,
  income_amount      decimal(18,2) NULL,
  target_cost_amount decimal(18,2) NULL,
  approved_amount    decimal(18,2) NULL,
  source_deleted     tinyint NOT NULL DEFAULT 0,
  UNIQUE KEY uk_tmp_unit_amount (project_code, unit_name)
);

DROP TEMPORARY TABLE IF EXISTS tmp_cost_work_order_sync;
CREATE TEMPORARY TABLE tmp_cost_work_order_sync (
  source_work_order_id varchar(128) NULL,
  project_code         varchar(128) NOT NULL,
  project_name         varchar(255) NULL,
  unit_name            varchar(255) NOT NULL,
  accounting_unit_code varchar(128) NULL,
  accounting_unit_name varchar(255) NULL,
  fiscal_year          varchar(16) NOT NULL,
  work_order_no        varchar(128) NOT NULL,
  work_order_name      varchar(255) NULL,
  stage_codes          varchar(255) NULL,
  max_stage_code       varchar(64) NULL,
  subsystem_name       varchar(255) NULL,
  product_short_name   varchar(255) NULL,
  quantity             int NULL,
  vertical_division    tinyint NULL,
  disabled             tinyint NOT NULL DEFAULT 0,
  source_deleted       tinyint NOT NULL DEFAULT 0,
  UNIQUE KEY uk_tmp_work_order (project_code, unit_name, work_order_no, fiscal_year)
);

DROP TEMPORARY TABLE IF EXISTS tmp_cost_ledger_sync;
CREATE TEMPORARY TABLE tmp_cost_ledger_sync (
  source_detail_id     varchar(128) NOT NULL,
  fiscal_year          varchar(16) NOT NULL,
  accounting_period    varchar(16) NULL,
  voucher_date         date NULL,
  voucher_no           varchar(128) NULL,
  accounting_unit_id   varchar(128) NULL,
  accounting_unit_code varchar(128) NULL,
  accounting_unit_name varchar(255) NOT NULL,
  manage_unit_name     varchar(255) NULL,
  subject_id           varchar(128) NULL,
  subject_code         varchar(128) NULL,
  subject_name         varchar(255) NULL,
  project_code         varchar(128) NOT NULL,
  source_project_id    varchar(128) NULL,
  project_name         varchar(255) NULL,
  source_work_order_id varchar(128) NULL,
  work_order_no        varchar(128) NOT NULL,
  work_order_name      varchar(255) NULL,
  debit_credit         varchar(32) NOT NULL,
  amount               decimal(18,2) NULL,
  summary_text         varchar(1000) NULL,
  source_lastmodify    datetime NULL,
  second_subject_code  varchar(128) NULL,
  second_subject_name  varchar(255) NULL,
  source_timestamp     varchar(64) NULL,
  resolved_stage_code  varchar(64) NULL,
  source_deleted       tinyint NOT NULL DEFAULT 0,
  UNIQUE KEY uk_tmp_ledger_source (source_detail_id)
);

-- 工作流在这里批量写入三张临时表。允许某一类临时表为空，但源明细 ID 必须稳定。
-- INSERT INTO tmp_cost_unit_amount_sync (...) VALUES (...);
-- INSERT INTO tmp_cost_work_order_sync (...) VALUES (...);
-- INSERT INTO tmp_cost_ledger_sync (...) VALUES (...);

-- 校验结果必须全部为 0 行。
SELECT '单位金额项目不存在或项目编码重复' AS error_type, s.project_code, s.unit_name
FROM tmp_cost_unit_amount_sync s
LEFT JOIN (
  SELECT project_code, COUNT(*) AS project_count
  FROM cost_project
  WHERE tenant_id = @sync_tenant_id AND deleted = b'0'
  GROUP BY project_code
) p ON p.project_code = s.project_code
WHERE COALESCE(p.project_count, 0) <> 1;

SELECT '年度工作令项目不存在或项目编码重复' AS error_type, s.project_code, s.unit_name,
       s.work_order_no, s.fiscal_year
FROM tmp_cost_work_order_sync s
LEFT JOIN (
  SELECT project_code, COUNT(*) AS project_count
  FROM cost_project
  WHERE tenant_id = @sync_tenant_id AND deleted = b'0'
  GROUP BY project_code
) p ON p.project_code = s.project_code
WHERE COALESCE(p.project_count, 0) <> 1;

SELECT '账面明细缺少对应年度工作令' AS error_type, l.source_detail_id, l.project_code,
       l.accounting_unit_name, l.work_order_no, l.fiscal_year
FROM tmp_cost_ledger_sync l
WHERE l.source_deleted = 0
  AND NOT EXISTS (
    SELECT 1 FROM tmp_cost_work_order_sync w
    WHERE w.project_code = l.project_code
      AND w.unit_name = l.accounting_unit_name
      AND w.work_order_no = l.work_order_no
      AND w.fiscal_year = l.fiscal_year
      AND w.source_deleted = 0
  )
  AND NOT EXISTS (
    SELECT 1 FROM cost_work_order w
    WHERE w.tenant_id = @sync_tenant_id AND w.deleted = b'0'
      AND w.project_code = l.project_code
      AND w.unit_name = l.accounting_unit_name
      AND w.work_order_no = l.work_order_no
      AND w.fiscal_year = l.fiscal_year
  );

SELECT '账面明细记账方向不是借或贷' AS error_type, source_detail_id, debit_credit
FROM tmp_cost_ledger_sync
WHERE source_deleted = 0 AND TRIM(debit_credit) NOT IN ('借', '贷');

-- 若上方存在错误，下面的 CHECK 会终止脚本，禁止带错落库。
DROP TEMPORARY TABLE IF EXISTS tmp_cost_sync_guard;
CREATE TEMPORARY TABLE tmp_cost_sync_guard (
  ok tinyint NOT NULL,
  CONSTRAINT chk_tmp_cost_sync_guard CHECK (ok = 1)
);
INSERT INTO tmp_cost_sync_guard (ok)
SELECT 0
WHERE EXISTS (
  SELECT 1
  FROM tmp_cost_unit_amount_sync s
  LEFT JOIN (
    SELECT project_code, COUNT(*) AS project_count
    FROM cost_project
    WHERE tenant_id = @sync_tenant_id AND deleted = b'0'
    GROUP BY project_code
  ) p ON p.project_code = s.project_code
  WHERE COALESCE(p.project_count, 0) <> 1
)
OR EXISTS (
  SELECT 1
  FROM tmp_cost_work_order_sync s
  LEFT JOIN (
    SELECT project_code, COUNT(*) AS project_count
    FROM cost_project
    WHERE tenant_id = @sync_tenant_id AND deleted = b'0'
    GROUP BY project_code
  ) p ON p.project_code = s.project_code
  WHERE COALESCE(p.project_count, 0) <> 1
)
OR EXISTS (
  SELECT 1 FROM tmp_cost_ledger_sync l
  WHERE l.source_deleted = 0
    AND TRIM(l.debit_credit) NOT IN ('借', '贷')
)
OR EXISTS (
  SELECT 1 FROM tmp_cost_ledger_sync l
  WHERE l.source_deleted = 0
    AND NOT EXISTS (
      SELECT 1 FROM tmp_cost_work_order_sync w
      WHERE w.project_code = l.project_code
        AND w.unit_name = l.accounting_unit_name
        AND w.work_order_no = l.work_order_no
        AND w.fiscal_year = l.fiscal_year
        AND w.source_deleted = 0
    )
    AND NOT EXISTS (
      SELECT 1 FROM cost_work_order w
      WHERE w.tenant_id = @sync_tenant_id AND w.deleted = b'0'
        AND w.project_code = l.project_code
        AND w.unit_name = l.accounting_unit_name
        AND w.work_order_no = l.work_order_no
        AND w.fiscal_year = l.fiscal_year
    )
);

START TRANSACTION;

-- 1. 预分预控项目单位累计金额。四项金额覆盖更新，不做累加。
INSERT INTO cost_unit_cost_detail (
  project_id, project_code, project_name, domain_code, domain_name, model_node_id, model_code, model_name,
  unit_id, unit_name, stage_code, source_record_id, source_update_time,
  contract_amount, income_amount, target_cost_amount, approved_amount,
  creator, create_time, updater, update_time, deleted, tenant_id
)
SELECT p.id, s.project_code, COALESCE(NULLIF(s.project_name, ''), p.project_name),
       p.domain_code, p.domain_name, p.model_node_id, p.model_code, p.model_name,
       (SELECT MIN(d.id) FROM cost_unit_dict d
        WHERE d.tenant_id = @sync_tenant_id AND d.deleted = b'0'
          AND d.accounting_unit_name = s.unit_name),
       s.unit_name, 'ALL', s.source_record_id, s.source_update_time,
       s.contract_amount, s.income_amount, s.target_cost_amount, s.approved_amount,
       'cost_sync', CURRENT_TIMESTAMP, 'cost_sync', CURRENT_TIMESTAMP, s.source_deleted, @sync_tenant_id
FROM tmp_cost_unit_amount_sync s
JOIN cost_project p ON p.tenant_id = @sync_tenant_id AND p.deleted = b'0'
  AND p.project_code = s.project_code
ON DUPLICATE KEY UPDATE
  project_id = VALUES(project_id), project_name = VALUES(project_name),
  domain_code = VALUES(domain_code), domain_name = VALUES(domain_name),
  model_node_id = VALUES(model_node_id), model_code = VALUES(model_code), model_name = VALUES(model_name),
  unit_id = VALUES(unit_id), stage_code = 'ALL', source_record_id = VALUES(source_record_id),
  source_update_time = VALUES(source_update_time), contract_amount = VALUES(contract_amount),
  income_amount = VALUES(income_amount), target_cost_amount = VALUES(target_cost_amount),
  approved_amount = VALUES(approved_amount), updater = 'cost_sync', update_time = CURRENT_TIMESTAMP,
  deleted = VALUES(deleted);

-- 2. 年度工作令。合同、目标和账面不从人工填报或源映射写入。
INSERT INTO cost_work_order (
  source_work_order_id, project_id, project_code, project_name, unit_id, unit_name,
  accounting_unit_code, accounting_unit_name, fiscal_year, work_order_no, work_order_name,
  stage_codes, max_stage_code, subsystem_name, product_short_name, quantity, vertical_division,
  disabled, creator, create_time, updater, update_time, deleted, tenant_id
)
SELECT s.source_work_order_id, p.id, s.project_code, COALESCE(NULLIF(s.project_name, ''), p.project_name),
       (SELECT MIN(d.id) FROM cost_unit_dict d
        WHERE d.tenant_id = @sync_tenant_id AND d.deleted = b'0'
          AND d.accounting_unit_name = s.unit_name),
       s.unit_name, s.accounting_unit_code, COALESCE(NULLIF(s.accounting_unit_name, ''), s.unit_name),
       s.fiscal_year, s.work_order_no, s.work_order_name, s.stage_codes, s.max_stage_code,
       s.subsystem_name, s.product_short_name, s.quantity, COALESCE(s.vertical_division, 0),
       s.disabled, 'cost_sync', CURRENT_TIMESTAMP, 'cost_sync', CURRENT_TIMESTAMP,
       s.source_deleted, @sync_tenant_id
FROM tmp_cost_work_order_sync s
JOIN cost_project p ON p.tenant_id = @sync_tenant_id AND p.deleted = b'0'
  AND p.project_code = s.project_code
ON DUPLICATE KEY UPDATE
  source_work_order_id = VALUES(source_work_order_id), project_id = VALUES(project_id),
  project_name = VALUES(project_name), unit_id = VALUES(unit_id),
  accounting_unit_code = VALUES(accounting_unit_code), accounting_unit_name = VALUES(accounting_unit_name),
  work_order_name = VALUES(work_order_name),
  stage_codes = COALESCE(NULLIF(VALUES(stage_codes), ''), stage_codes),
  max_stage_code = COALESCE(NULLIF(VALUES(max_stage_code), ''), max_stage_code),
  subsystem_name = COALESCE(NULLIF(VALUES(subsystem_name), ''), subsystem_name),
  product_short_name = COALESCE(NULLIF(VALUES(product_short_name), ''), product_short_name),
  quantity = COALESCE(VALUES(quantity), quantity), vertical_division = VALUES(vertical_division),
  disabled = VALUES(disabled), updater = 'cost_sync', update_time = CURRENT_TIMESTAMP,
  deleted = VALUES(deleted);

-- 记录账面明细变更前后的业务键，避免明细改挂工作令后旧年度快照残留。
DROP TEMPORARY TABLE IF EXISTS tmp_cost_snapshot_key;
CREATE TEMPORARY TABLE tmp_cost_snapshot_key (
  project_code varchar(128) NOT NULL,
  unit_name varchar(255) NOT NULL,
  work_order_no varchar(128) NOT NULL,
  fiscal_year varchar(16) NOT NULL,
  PRIMARY KEY (project_code, unit_name, work_order_no, fiscal_year)
);
INSERT IGNORE INTO tmp_cost_snapshot_key
SELECT project_code, accounting_unit_name, work_order_no, fiscal_year FROM tmp_cost_ledger_sync;
INSERT IGNORE INTO tmp_cost_snapshot_key
SELECT d.project_code, d.accounting_unit_name, d.work_order_no, COALESCE(d.fiscal_year, '')
FROM cost_work_order_ledger_detail d
JOIN tmp_cost_ledger_sync s ON s.source_detail_id = d.source_detail_id
WHERE d.tenant_id = @sync_tenant_id;

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
       s.work_order_no, s.work_order_name, TRIM(s.debit_credit), s.amount,
       CASE WHEN s.amount IS NULL THEN NULL ELSE ROUND(s.amount / 10000.0, 2) END,
       s.summary_text, s.source_lastmodify, s.second_subject_code, s.second_subject_name,
       s.source_timestamp, COALESCE(NULLIF(s.resolved_stage_code, ''), w.max_stage_code),
       p.id, w.id, 'cost_sync', CURRENT_TIMESTAMP, 'cost_sync', CURRENT_TIMESTAMP,
       s.source_deleted, @sync_tenant_id
FROM tmp_cost_ledger_sync s
JOIN cost_project p ON p.tenant_id = @sync_tenant_id AND p.deleted = b'0'
  AND p.project_code = s.project_code
JOIN cost_work_order w ON w.tenant_id = @sync_tenant_id
  AND w.project_code = s.project_code AND w.unit_name = s.accounting_unit_name
  AND w.work_order_no = s.work_order_no AND w.fiscal_year = s.fiscal_year
ON DUPLICATE KEY UPDATE
  fiscal_year = VALUES(fiscal_year), accounting_period = VALUES(accounting_period),
  voucher_date = VALUES(voucher_date), voucher_no = VALUES(voucher_no),
  accounting_unit_id = VALUES(accounting_unit_id), accounting_unit_code = VALUES(accounting_unit_code),
  accounting_unit_name = VALUES(accounting_unit_name), manage_unit_name = VALUES(manage_unit_name),
  subject_id = VALUES(subject_id), subject_code = VALUES(subject_code), subject_name = VALUES(subject_name),
  project_code = VALUES(project_code), source_project_id = VALUES(source_project_id),
  project_name = VALUES(project_name), source_work_order_id = VALUES(source_work_order_id),
  work_order_no = VALUES(work_order_no), work_order_name = VALUES(work_order_name),
  debit_credit = VALUES(debit_credit), amount = VALUES(amount), amount_wan = VALUES(amount_wan),
  summary_text = VALUES(summary_text), source_lastmodify = VALUES(source_lastmodify),
  second_subject_code = VALUES(second_subject_code), second_subject_name = VALUES(second_subject_name),
  source_timestamp = VALUES(source_timestamp), resolved_stage_code = VALUES(resolved_stage_code),
  project_id = VALUES(project_id), work_order_id = VALUES(work_order_id),
  updater = 'cost_sync', update_time = CURRENT_TIMESTAMP, deleted = VALUES(deleted);

-- 4. 仅重建本批受影响工作令年度账面快照；原始元字段优先，amount_wan 仅作兼容兜底。
UPDATE cost_work_order w
JOIN tmp_cost_snapshot_key k ON k.project_code = w.project_code AND k.unit_name = w.unit_name
  AND k.work_order_no = w.work_order_no AND k.fiscal_year = w.fiscal_year
SET w.book_cost_amount = 0, w.update_time = CURRENT_TIMESTAMP
WHERE w.tenant_id = @sync_tenant_id;

UPDATE cost_work_order w
JOIN (
  SELECT d.project_code, d.accounting_unit_name AS unit_name, d.work_order_no,
         COALESCE(d.fiscal_year, '') AS fiscal_year,
         SUM(COALESCE(d.amount / 10000.0, d.amount_wan, 0)) AS book_cost_amount
  FROM cost_work_order_ledger_detail d
  JOIN tmp_cost_snapshot_key k ON k.project_code = d.project_code
    AND k.unit_name = d.accounting_unit_name AND k.work_order_no = d.work_order_no
    AND k.fiscal_year = COALESCE(d.fiscal_year, '')
  WHERE d.tenant_id = @sync_tenant_id AND d.deleted = b'0' AND TRIM(d.debit_credit) = '借'
  GROUP BY d.project_code, d.accounting_unit_name, d.work_order_no, COALESCE(d.fiscal_year, '')
) s ON s.project_code = w.project_code AND s.unit_name = w.unit_name
  AND s.work_order_no = w.work_order_no AND s.fiscal_year = w.fiscal_year
SET w.book_cost_amount = s.book_cost_amount, w.update_time = CURRENT_TIMESTAMP
WHERE w.tenant_id = @sync_tenant_id;

COMMIT;

-- 对账：单位金额应与暂存表逐行一致；年度工作令快照应等于借方明细元金额/10000。
SELECT s.project_code, s.unit_name,
       s.contract_amount AS source_contract, d.contract_amount AS target_contract,
       s.income_amount AS source_income, d.income_amount AS target_income,
       s.target_cost_amount AS source_target, d.target_cost_amount AS target_target,
       s.approved_amount AS source_approved, d.approved_amount AS target_approved
FROM tmp_cost_unit_amount_sync s
JOIN cost_unit_cost_detail d ON d.tenant_id = @sync_tenant_id
  AND d.project_code = s.project_code AND d.unit_name = s.unit_name
WHERE NOT (s.contract_amount <=> d.contract_amount)
   OR NOT (s.income_amount <=> d.income_amount)
   OR NOT (s.target_cost_amount <=> d.target_cost_amount)
   OR NOT (s.approved_amount <=> d.approved_amount)
   OR d.stage_code <> 'ALL';

SELECT w.project_code, w.unit_name, w.work_order_no, w.fiscal_year,
       w.book_cost_amount AS snapshot_amount,
       COALESCE(SUM(CASE WHEN d.deleted = b'0' AND TRIM(d.debit_credit) = '借'
                         THEN COALESCE(d.amount / 10000.0, d.amount_wan, 0) ELSE 0 END), 0) AS ledger_amount
FROM cost_work_order w
JOIN tmp_cost_snapshot_key k ON k.project_code = w.project_code AND k.unit_name = w.unit_name
  AND k.work_order_no = w.work_order_no AND k.fiscal_year = w.fiscal_year
LEFT JOIN cost_work_order_ledger_detail d ON d.tenant_id = w.tenant_id
  AND d.project_code = w.project_code AND d.accounting_unit_name = w.unit_name
  AND d.work_order_no = w.work_order_no AND COALESCE(d.fiscal_year, '') = w.fiscal_year
WHERE w.tenant_id = @sync_tenant_id
GROUP BY w.id, w.project_code, w.unit_name, w.work_order_no, w.fiscal_year, w.book_cost_amount
HAVING ABS(COALESCE(w.book_cost_amount, 0) - ledger_amount) > 0.01;
