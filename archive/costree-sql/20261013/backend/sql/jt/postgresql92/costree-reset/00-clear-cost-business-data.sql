-- 成本库指定租户业务数据清理脚本。
-- 适用 PostgreSQL 9.2.x / GaussDB(DWS) 8.2.1。
-- 本脚本保留表结构、序列、cost_schema_migration 和平台公共数据。
-- 执行前必须停止成本服务和所有同步任务，并完成数据库备份。

BEGIN;

SELECT pg_advisory_xact_lock(hashtext('costree-business-data-reset'));

DROP TABLE IF EXISTS tmp_cost_reset_context;
CREATE TEMP TABLE tmp_cost_reset_context
(
    tenant_id        int8        NOT NULL,
    confirmation_key varchar(64) NOT NULL
) ON COMMIT DELETE ROWS;

-- 内网租户不是 124 时，必须同时修改 tenant_id 和 confirmation_key。
INSERT INTO tmp_cost_reset_context (tenant_id, confirmation_key)
VALUES (124, 'RESET_COST_TENANT_124');

DO $$
DECLARE
    v_tenant_id int8;
    v_confirmation_key varchar(64);
    v_missing_tables text;
BEGIN
    SELECT tenant_id, confirmation_key
      INTO v_tenant_id, v_confirmation_key
    FROM tmp_cost_reset_context;

    IF v_confirmation_key <> 'RESET_COST_TENANT_' || v_tenant_id::varchar THEN
        RAISE EXCEPTION '清理确认码不匹配，已停止执行';
    END IF;

    SELECT string_agg(required.table_name, ', ' ORDER BY required.table_name)
      INTO v_missing_tables
    FROM (VALUES
              ('cost_import_batch'),
              ('cost_import_error'),
              ('cost_model_node'),
              ('cost_project'),
              ('cost_project_basic'),
              ('cost_unit_cost_detail'),
              ('cost_unit_dict'),
              ('cost_warning_record'),
              ('cost_work_order'),
              ('cost_work_order_ledger_detail')
         ) AS required(table_name)
    WHERE NOT EXISTS (
        SELECT 1
        FROM information_schema.tables actual
        WHERE actual.table_schema = current_schema()
          AND actual.table_name = required.table_name
    );

    IF v_missing_tables IS NOT NULL THEN
        RAISE EXCEPTION '缺少成本业务表：%', v_missing_tables;
    END IF;
END $$;

SELECT table_name, row_count
FROM (
    SELECT 'cost_warning_record'::varchar AS table_name, count(*) AS row_count
    FROM cost_warning_record target, tmp_cost_reset_context context
    WHERE target.tenant_id = context.tenant_id
    UNION ALL
    SELECT 'cost_work_order_ledger_detail', count(*)
    FROM cost_work_order_ledger_detail target, tmp_cost_reset_context context
    WHERE target.tenant_id = context.tenant_id
    UNION ALL
    SELECT 'cost_work_order', count(*)
    FROM cost_work_order target, tmp_cost_reset_context context
    WHERE target.tenant_id = context.tenant_id
    UNION ALL
    SELECT 'cost_unit_cost_detail', count(*)
    FROM cost_unit_cost_detail target, tmp_cost_reset_context context
    WHERE target.tenant_id = context.tenant_id
    UNION ALL
    SELECT 'cost_project_basic', count(*)
    FROM cost_project_basic target, tmp_cost_reset_context context
    WHERE target.tenant_id = context.tenant_id
    UNION ALL
    SELECT 'cost_project', count(*)
    FROM cost_project target, tmp_cost_reset_context context
    WHERE target.tenant_id = context.tenant_id
    UNION ALL
    SELECT 'cost_model_node', count(*)
    FROM cost_model_node target, tmp_cost_reset_context context
    WHERE target.tenant_id = context.tenant_id
    UNION ALL
    SELECT 'cost_unit_dict', count(*)
    FROM cost_unit_dict target, tmp_cost_reset_context context
    WHERE target.tenant_id = context.tenant_id
    UNION ALL
    SELECT 'cost_import_error', count(*)
    FROM cost_import_error target, tmp_cost_reset_context context
    WHERE target.tenant_id = context.tenant_id
    UNION ALL
    SELECT 'cost_import_batch', count(*)
    FROM cost_import_batch target, tmp_cost_reset_context context
    WHERE target.tenant_id = context.tenant_id
) before_reset
ORDER BY table_name;

DELETE FROM cost_warning_record target
USING tmp_cost_reset_context context
WHERE target.tenant_id = context.tenant_id;

DELETE FROM cost_work_order_ledger_detail target
USING tmp_cost_reset_context context
WHERE target.tenant_id = context.tenant_id;

DELETE FROM cost_work_order target
USING tmp_cost_reset_context context
WHERE target.tenant_id = context.tenant_id;

DELETE FROM cost_unit_cost_detail target
USING tmp_cost_reset_context context
WHERE target.tenant_id = context.tenant_id;

DELETE FROM cost_project_basic target
USING tmp_cost_reset_context context
WHERE target.tenant_id = context.tenant_id;

DELETE FROM cost_project target
USING tmp_cost_reset_context context
WHERE target.tenant_id = context.tenant_id;

DELETE FROM cost_model_node target
USING tmp_cost_reset_context context
WHERE target.tenant_id = context.tenant_id;

DELETE FROM cost_unit_dict target
USING tmp_cost_reset_context context
WHERE target.tenant_id = context.tenant_id;

DELETE FROM cost_import_error target
USING tmp_cost_reset_context context
WHERE target.tenant_id = context.tenant_id;

DELETE FROM cost_import_batch target
USING tmp_cost_reset_context context
WHERE target.tenant_id = context.tenant_id;

DO $$
DECLARE
    v_tenant_id int8;
    v_remaining_count int8;
BEGIN
    SELECT tenant_id INTO v_tenant_id FROM tmp_cost_reset_context;

    SELECT sum(row_count) INTO v_remaining_count
    FROM (
        SELECT count(*) AS row_count FROM cost_warning_record WHERE tenant_id = v_tenant_id
        UNION ALL
        SELECT count(*) FROM cost_work_order_ledger_detail WHERE tenant_id = v_tenant_id
        UNION ALL
        SELECT count(*) FROM cost_work_order WHERE tenant_id = v_tenant_id
        UNION ALL
        SELECT count(*) FROM cost_unit_cost_detail WHERE tenant_id = v_tenant_id
        UNION ALL
        SELECT count(*) FROM cost_project_basic WHERE tenant_id = v_tenant_id
        UNION ALL
        SELECT count(*) FROM cost_project WHERE tenant_id = v_tenant_id
        UNION ALL
        SELECT count(*) FROM cost_model_node WHERE tenant_id = v_tenant_id
        UNION ALL
        SELECT count(*) FROM cost_unit_dict WHERE tenant_id = v_tenant_id
        UNION ALL
        SELECT count(*) FROM cost_import_error WHERE tenant_id = v_tenant_id
        UNION ALL
        SELECT count(*) FROM cost_import_batch WHERE tenant_id = v_tenant_id
    ) remaining;

    IF COALESCE(v_remaining_count, 0) <> 0 THEN
        RAISE EXCEPTION '租户 % 仍有 % 条成本业务数据，清理事务已回滚',
            v_tenant_id, v_remaining_count;
    END IF;
END $$;

COMMIT;

SELECT version, description, installed_on, installed_by
FROM cost_schema_migration
WHERE version IN ('20260722', '20260728')
ORDER BY version;
