-- 成本库 PostgreSQL 9.2 / GaussDB(DWS) 8.2.1 升级后验收脚本。
-- 目标结构版本：20260819。所有 error_count 应为 0。

SELECT current_database() AS database_name,
       current_user AS database_user,
       current_setting('server_version') AS server_version,
       CASE WHEN position('gaussdb' in lower(version())) > 0
                  OR position('dws' in lower(version())) > 0
            THEN 'GaussDB(DWS)' ELSE 'PostgreSQL 9.2' END AS database_engine,
       CURRENT_TIMESTAMP AS verified_at;

SELECT version, description, installed_on, installed_by
FROM cost_schema_migration
ORDER BY installed_on DESC, version DESC;

WITH required_column(table_name, column_name) AS (
    VALUES
        ('cost_project_basic', 'product_attachment_type'),
        ('cost_project_basic', 'tax_exempt'),
        ('cost_project_basic', 'cycle_start'),
        ('cost_project_basic', 'cycle_end'),
        ('cost_project_basic', 'quantity'),
        ('cost_project_basic', 'product_short_name'),
        ('cost_project_basic', 'vertical_division'),
        ('cost_project_basic', 'user_name'),
        ('cost_project_basic', 'acquire_method'),
        ('cost_project_basic', 'batch_category'),
        ('cost_project_basic', 'platform_series'),
        ('cost_project_basic', 'target_price'),
        ('cost_project_basic', 'competitor_unit_1'),
        ('cost_project_basic', 'competitor_price_1'),
        ('cost_project_basic', 'competitor_unit_2'),
        ('cost_project_basic', 'competitor_price_2'),
        ('cost_unit_cost_detail', 'approved_amount'),
        ('cost_unit_cost_detail', 'source_record_id'),
        ('cost_unit_cost_detail', 'source_update_time'),
        ('cost_unit_dict', 'manage_unit_group'),
        ('cost_work_order', 'source_work_order_id'),
        ('cost_work_order', 'accounting_unit_code'),
        ('cost_work_order', 'accounting_unit_name'),
        ('cost_work_order', 'fiscal_year'),
        ('cost_work_order', 'contract_amount'),
        ('cost_work_order', 'income_amount'),
        ('cost_work_order', 'disabled'),
        ('cost_work_order', 'approved_amount')
)
SELECT r.table_name, r.column_name AS missing_required_column
FROM required_column r
LEFT JOIN information_schema.columns c
  ON c.table_schema = current_schema()
 AND c.table_name = r.table_name
 AND c.column_name = r.column_name
WHERE c.column_name IS NULL
ORDER BY r.table_name, r.column_name;

WITH required_index(index_name) AS (
    VALUES ('uk_cost_unit_cost_project_unit'),
           ('uk_cost_work_order_business'),
           ('uk_cost_ledger_source_detail'),
           ('idx_cost_unit_dict_manage_group'),
           ('idx_cost_work_order_source'),
           ('uk_cost_user_project_scope'),
           ('uk_cost_user_unit_scope'),
           ('uk_cost_user_domain_scope_user'),
           ('idx_cost_user_domain_scope_domain'),
           ('uk_cost_subsystem_dict_name'),
           ('idx_cost_subsystem_dict_status')
)
SELECT r.index_name AS missing_required_index
FROM required_index r
WHERE NOT EXISTS (
    SELECT 1 FROM pg_indexes i
    WHERE i.schemaname = current_schema() AND i.indexname = r.index_name
)
ORDER BY r.index_name;

BEGIN;

DROP TABLE IF EXISTS tmp_cost_verify_results;
CREATE TEMP TABLE tmp_cost_verify_results
(
    check_name  varchar(128) NOT NULL,
    error_count bigint       NOT NULL
) ON COMMIT DELETE ROWS;

INSERT INTO tmp_cost_verify_results(check_name, error_count)
    SELECT 'schema_version_20260819',
           CASE WHEN EXISTS (
               SELECT 1 FROM cost_schema_migration WHERE version = '20260819'
           ) THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'subsystem_dict_table', CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = current_schema() AND table_name = 'cost_subsystem_dict'
    ) THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'project_basic_stage_code_length', CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema() AND table_name = 'cost_project_basic'
          AND column_name = 'stage_code' AND character_maximum_length >= 255
    ) THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'work_order_vertical_division_default', CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema() AND table_name = 'cost_work_order'
          AND column_name = 'vertical_division' AND column_default IS NOT NULL
    ) THEN 1::bigint ELSE 0::bigint END
    UNION ALL
    SELECT 'project_scope_table', CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = current_schema() AND table_name = 'cost_user_project_scope'
    ) THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'unit_scope_table', CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = current_schema() AND table_name = 'cost_user_unit_scope'
    ) THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'domain_scope_table', CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = current_schema() AND table_name = 'cost_user_domain_scope'
    ) THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'project_scope_duplicate_key', count(*)
    FROM (
        SELECT 1 FROM cost_user_project_scope
        GROUP BY tenant_id, user_id, project_code HAVING count(*) > 1
    ) duplicate_scope
    UNION ALL
    SELECT 'unit_scope_duplicate_key', count(*)
    FROM (
        SELECT 1 FROM cost_user_unit_scope
        GROUP BY tenant_id, user_id, manage_unit_code HAVING count(*) > 1
    ) duplicate_scope
    UNION ALL
    SELECT 'domain_scope_duplicate_user', count(*)
    FROM (
        SELECT 1 FROM cost_user_domain_scope
        GROUP BY tenant_id, user_id HAVING count(*) > 1
    ) duplicate_scope
    UNION ALL
    SELECT 'project_scope_business_guard_index',
           CASE WHEN EXISTS (
               SELECT 1 FROM pg_indexes i
               WHERE i.schemaname = current_schema()
                 AND i.tablename = 'cost_user_project_scope'
                 AND i.indexname = 'uk_cost_user_project_scope'
                 AND ((position('gaussdb' in lower(version())) > 0
                       OR position('dws' in lower(version())) > 0)
                      OR i.indexdef LIKE 'CREATE UNIQUE INDEX%')
                 AND i.indexdef LIKE '%(tenant_id, user_id, project_code)%'
           )
           THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'unit_scope_business_guard_index',
           CASE WHEN EXISTS (
               SELECT 1 FROM pg_indexes i
               WHERE i.schemaname = current_schema()
                 AND i.tablename = 'cost_user_unit_scope'
                 AND i.indexname = 'uk_cost_user_unit_scope'
                 AND ((position('gaussdb' in lower(version())) > 0
                       OR position('dws' in lower(version())) > 0)
                      OR i.indexdef LIKE 'CREATE UNIQUE INDEX%')
                 AND i.indexdef LIKE '%(tenant_id, user_id, manage_unit_code)%'
           )
           THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'domain_scope_business_guard_index',
           CASE WHEN EXISTS (
               SELECT 1 FROM pg_indexes i
               WHERE i.schemaname = current_schema()
                 AND i.tablename = 'cost_user_domain_scope'
                 AND i.indexname = 'uk_cost_user_domain_scope_user'
                 AND ((position('gaussdb' in lower(version())) > 0
                       OR position('dws' in lower(version())) > 0)
                      OR i.indexdef LIKE 'CREATE UNIQUE INDEX%')
                 AND i.indexdef LIKE '%(tenant_id, user_id)%'
           )
           THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'domain_scope_invalid_business_key', count(*)
    FROM cost_user_domain_scope
    WHERE user_id IS NULL
       OR domain_code IS NULL OR btrim(domain_code) = ''
    UNION ALL
    SELECT 'domain_scope_non_active_record', count(*)
    FROM cost_user_domain_scope
    WHERE deleted <> 0
    UNION ALL
    SELECT 'domain_scope_orphan_domain', count(*)
    FROM cost_user_domain_scope domain_scope
    WHERE domain_scope.deleted = 0
      AND NOT EXISTS (
          SELECT 1
          FROM cost_project project
          WHERE project.tenant_id = domain_scope.tenant_id
            AND project.domain_code = domain_scope.domain_code
            AND project.deleted = 0
      )
    UNION ALL
    SELECT 'unit_cost_business_guard_index',
           CASE WHEN EXISTS (
               SELECT 1 FROM pg_indexes i
               WHERE i.schemaname = current_schema()
                 AND i.indexname = 'uk_cost_unit_cost_project_unit'
                  AND ((position('gaussdb' in lower(version())) > 0
                        OR position('dws' in lower(version())) > 0)
                       OR i.indexdef LIKE 'CREATE UNIQUE INDEX%')
                  AND i.indexdef LIKE '%(tenant_id, project_code, unit_name)%'
           )
           THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'work_order_business_guard_index',
           CASE WHEN EXISTS (
               SELECT 1 FROM pg_indexes i
               WHERE i.schemaname = current_schema()
                 AND i.indexname = 'uk_cost_work_order_business'
                  AND ((position('gaussdb' in lower(version())) > 0
                        OR position('dws' in lower(version())) > 0)
                       OR i.indexdef LIKE 'CREATE UNIQUE INDEX%')
                 AND i.indexdef LIKE '%(tenant_id, project_code, unit_name, work_order_no)%'
           )
           THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'ledger_business_guard_index',
           CASE WHEN EXISTS (
               SELECT 1 FROM pg_indexes i
               WHERE i.schemaname = current_schema()
                 AND i.indexname = 'uk_cost_ledger_source_detail'
                  AND ((position('gaussdb' in lower(version())) > 0
                        OR position('dws' in lower(version())) > 0)
                       OR i.indexdef LIKE 'CREATE UNIQUE INDEX%')
                 AND i.indexdef LIKE '%(tenant_id, source_detail_id)%'
           )
           THEN 0::bigint ELSE 1::bigint END
    UNION ALL
    SELECT 'unit_cost_invalid_business_key', count(*)
    FROM cost_unit_cost_detail
    WHERE project_code IS NULL OR btrim(project_code) = ''
       OR unit_name IS NULL OR btrim(unit_name) = ''
    UNION ALL
    SELECT 'unit_cost_duplicate_business_key', count(*)
    FROM (
        SELECT 1
        FROM cost_unit_cost_detail
        GROUP BY tenant_id, project_code, unit_name
        HAVING count(*) > 1
    ) duplicate_key
    UNION ALL
    SELECT 'unit_cost_non_all_stage', count(*)
    FROM cost_unit_cost_detail
    WHERE stage_code IS DISTINCT FROM 'ALL'
    UNION ALL
    SELECT 'work_order_invalid_business_key', count(*)
    FROM cost_work_order
    WHERE project_code IS NULL OR btrim(project_code) = ''
       OR unit_name IS NULL OR btrim(unit_name) = ''
       OR work_order_no IS NULL OR btrim(work_order_no) = ''
    UNION ALL
    SELECT 'work_order_duplicate_business_key', count(*)
    FROM (
        SELECT 1
        FROM cost_work_order
        GROUP BY tenant_id, project_code, unit_name, work_order_no
        HAVING count(*) > 1
    ) duplicate_key
    UNION ALL
    SELECT 'work_order_legacy_fiscal_year', count(*)
    FROM cost_work_order
    WHERE fiscal_year IS DISTINCT FROM ''
    UNION ALL
    SELECT 'ledger_missing_source_detail_id', count(*)
    FROM cost_work_order_ledger_detail
    WHERE source_detail_id IS NULL OR btrim(source_detail_id) = ''
    UNION ALL
    SELECT 'ledger_duplicate_source_detail_id', count(*)
    FROM (
        SELECT 1
        FROM cost_work_order_ledger_detail
        GROUP BY tenant_id, source_detail_id
        HAVING count(*) > 1
    ) duplicate_source
    UNION ALL
    SELECT 'ledger_unmatched_active_work_order', count(*)
    FROM cost_work_order_ledger_detail
    WHERE deleted = 0 AND work_order_id IS NULL
    UNION ALL
    SELECT 'ledger_orphan_work_order_id', count(*)
    FROM cost_work_order_ledger_detail detail
    LEFT JOIN cost_work_order work_order ON work_order.id = detail.work_order_id
    WHERE detail.work_order_id IS NOT NULL AND work_order.id IS NULL
    UNION ALL
    SELECT 'warning_orphan_work_order_id', count(*)
    FROM cost_warning_record warning
    LEFT JOIN cost_work_order work_order ON work_order.id = warning.work_order_id
    WHERE warning.work_order_id IS NOT NULL AND work_order.id IS NULL
    UNION ALL
    SELECT 'ledger_amount_wan_mismatch', count(*)
    FROM cost_work_order_ledger_detail
    WHERE amount IS NOT NULL
      AND amount_wan IS DISTINCT FROM round(amount / 10000.0, 2)
    UNION ALL
    SELECT 'work_order_debit_snapshot_mismatch', count(*)
    FROM (
        SELECT work_order.id,
               COALESCE(work_order.book_cost_amount, 0) AS snapshot_amount,
               COALESCE(sum(CASE
                   WHEN detail.deleted = 0
                    AND btrim(COALESCE(detail.debit_credit, '')) = '借'
                   THEN COALESCE(detail.amount / 10000.0, detail.amount_wan, 0)
                   ELSE 0
               END), 0) AS debit_amount
        FROM cost_work_order work_order
        LEFT JOIN cost_work_order_ledger_detail detail ON detail.work_order_id = work_order.id
        GROUP BY work_order.id, work_order.book_cost_amount
    ) snapshot
    WHERE abs(snapshot.snapshot_amount - snapshot.debit_amount) > 0.01
    UNION ALL
    SELECT 'unit_dict_invalid_manage_group', count(*)
    FROM cost_unit_dict
    WHERE manage_unit_group IS NOT NULL
      AND manage_unit_group NOT IN ('HEAD_OFFICE', 'OVERALL', 'ASSEMBLY', 'PROFESSIONAL', 'FOUNDATION', 'OUTER')
    UNION ALL
    SELECT 'subsystem_dict_duplicate_name', count(*)
    FROM (
        SELECT 1 FROM cost_subsystem_dict
        GROUP BY tenant_id, subsystem_name HAVING count(*) > 1
    ) duplicate_subsystem
    UNION ALL
    SELECT 'subsystem_dict_invalid_record', count(*)
    FROM cost_subsystem_dict
    WHERE subsystem_name IS NULL OR btrim(subsystem_name) = ''
       OR status NOT IN ('ENABLE', 'DISABLE') OR deleted <> 0
    UNION ALL
    SELECT 'subsystem_dict_business_guard_index',
           CASE WHEN EXISTS (
               SELECT 1 FROM pg_indexes i
               WHERE i.schemaname = current_schema()
                 AND i.tablename = 'cost_subsystem_dict'
                 AND i.indexname = 'uk_cost_subsystem_dict_name'
                 AND ((position('gaussdb' in lower(version())) > 0
                       OR position('dws' in lower(version())) > 0)
                      OR i.indexdef LIKE 'CREATE UNIQUE INDEX%')
                 AND i.indexdef LIKE '%(tenant_id, subsystem_name)%'
           ) THEN 0::bigint ELSE 1::bigint END
;

SELECT check_name, error_count,
       CASE WHEN error_count = 0 THEN 'OK' ELSE 'ERROR' END AS status
FROM tmp_cost_verify_results
ORDER BY check_name;

SELECT btrim(COALESCE(debit_credit, '')) AS debit_credit,
       count(*) AS detail_count,
       sum(COALESCE(amount / 10000.0, amount_wan, 0)) AS amount_wan
FROM cost_work_order_ledger_detail
WHERE deleted = 0
GROUP BY btrim(COALESCE(debit_credit, ''))
ORDER BY debit_credit;

SELECT sum(CASE WHEN inside_institute = true AND manage_unit_group IS NULL THEN 1 ELSE 0 END)
           AS unclassified_internal_unit_count,
       sum(CASE WHEN inside_institute = false AND manage_unit_group = 'OUTER' THEN 1 ELSE 0 END)
           AS classified_outer_unit_count
FROM cost_unit_dict
WHERE deleted = 0;

DO $$
DECLARE
    failed_checks text;
BEGIN
    SELECT string_agg(check_name || '=' || error_count, ', ' ORDER BY check_name)
      INTO failed_checks
    FROM tmp_cost_verify_results
    WHERE error_count <> 0;

    IF failed_checks IS NOT NULL THEN
        RAISE EXCEPTION '成本库升级后验收失败：%', failed_checks;
    END IF;
END $$;

COMMIT;
