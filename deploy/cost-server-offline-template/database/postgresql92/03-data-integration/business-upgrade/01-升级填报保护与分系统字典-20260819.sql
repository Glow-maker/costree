-- 20260819 项目办填报字段、阶段多选、成本分系统字典和纵向分工空值语义升级。
-- 兼容 PostgreSQL 9.2.x 与 GaussDB(DWS) 8.2.1，可重复执行。
-- 不批量修改历史 vertical_division=false；脚本末尾只输出审计清单。

BEGIN;

SELECT pg_advisory_xact_lock(hashtext('costree-schema-upgrade-20260819'));

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'product_attachment_type') THEN
        ALTER TABLE cost_project_basic ADD COLUMN product_attachment_type varchar(32) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'user_name') THEN
        ALTER TABLE cost_project_basic ADD COLUMN user_name varchar(255) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'acquire_method') THEN
        ALTER TABLE cost_project_basic ADD COLUMN acquire_method varchar(128) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'batch_category') THEN
        ALTER TABLE cost_project_basic ADD COLUMN batch_category varchar(128) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'platform_series') THEN
        ALTER TABLE cost_project_basic ADD COLUMN platform_series varchar(128) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'target_price') THEN
        ALTER TABLE cost_project_basic ADD COLUMN target_price numeric(18,2) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'competitor_unit_1') THEN
        ALTER TABLE cost_project_basic ADD COLUMN competitor_unit_1 varchar(255) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'competitor_price_1') THEN
        ALTER TABLE cost_project_basic ADD COLUMN competitor_price_1 numeric(18,2) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'competitor_unit_2') THEN
        ALTER TABLE cost_project_basic ADD COLUMN competitor_unit_2 varchar(255) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'competitor_price_2') THEN
        ALTER TABLE cost_project_basic ADD COLUMN competitor_price_2 numeric(18,2) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'tax_exempt') THEN
        ALTER TABLE cost_project_basic ADD COLUMN tax_exempt varchar(16) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'cycle_start') THEN
        ALTER TABLE cost_project_basic ADD COLUMN cycle_start varchar(16) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'cost_project_basic' AND column_name = 'cycle_end') THEN
        ALTER TABLE cost_project_basic ADD COLUMN cycle_end varchar(16) NULL DEFAULT NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relkind = 'S' AND relname = 'cost_subsystem_dict_seq') THEN
        EXECUTE 'CREATE SEQUENCE cost_subsystem_dict_seq START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1';
    END IF;
END $$;

ALTER TABLE cost_project_basic ALTER COLUMN stage_code TYPE varchar(255);
ALTER TABLE cost_work_order ALTER COLUMN vertical_division DROP DEFAULT;

CREATE TABLE IF NOT EXISTS cost_subsystem_dict
(
    id             int8         NOT NULL DEFAULT nextval('cost_subsystem_dict_seq'),
    subsystem_name varchar(100) NOT NULL,
    sort_no        int4         NOT NULL DEFAULT 0,
    status         varchar(32)  NOT NULL DEFAULT 'ENABLE',
    remark         varchar(500) NULL     DEFAULT NULL,
    creator        varchar(64)  NULL     DEFAULT '',
    create_time    timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater        varchar(64)  NULL     DEFAULT '',
    update_time    timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted        int2         NOT NULL DEFAULT 0,
    tenant_id      int8         NOT NULL DEFAULT 0,
    CONSTRAINT pk_cost_subsystem_dict PRIMARY KEY (id)
);

DO $$
DECLARE
    v_is_dws bool;
BEGIN
    v_is_dws := position('gaussdb' in lower(version())) > 0 OR position('dws' in lower(version())) > 0;
    IF EXISTS (
        SELECT 1 FROM pg_indexes WHERE schemaname = current_schema() AND indexname = 'uk_cost_subsystem_dict_name'
    ) AND NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = current_schema()
          AND tablename = 'cost_subsystem_dict'
          AND indexname = 'uk_cost_subsystem_dict_name'
          AND (v_is_dws OR indexdef LIKE 'CREATE UNIQUE INDEX%')
          AND indexdef LIKE '%(tenant_id, subsystem_name)%'
    ) THEN
        RAISE EXCEPTION '索引 uk_cost_subsystem_dict_name 已存在但定义错误，请 DBA 核对后处理';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = current_schema() AND indexname = 'uk_cost_subsystem_dict_name') THEN
        IF v_is_dws THEN
            EXECUTE 'CREATE INDEX uk_cost_subsystem_dict_name ON cost_subsystem_dict (tenant_id, subsystem_name)';
        ELSE
            EXECUTE 'CREATE UNIQUE INDEX uk_cost_subsystem_dict_name ON cost_subsystem_dict (tenant_id, subsystem_name)';
        END IF;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = current_schema() AND indexname = 'idx_cost_subsystem_dict_status') THEN
        EXECUTE 'CREATE INDEX idx_cost_subsystem_dict_status ON cost_subsystem_dict (tenant_id, status, sort_no, deleted)';
    END IF;
END $$;

INSERT INTO cost_subsystem_dict
    (subsystem_name, sort_no, status, creator, create_time, updater, update_time, deleted, tenant_id)
SELECT source.subsystem_name,
       row_number() OVER (PARTITION BY source.tenant_id ORDER BY source.subsystem_name) * 10,
       'ENABLE', 'upgrade-20260819', CURRENT_TIMESTAMP, 'upgrade-20260819', CURRENT_TIMESTAMP, 0,
       source.tenant_id
FROM (
    SELECT DISTINCT tenant_id, btrim(regexp_split_to_table(subsystem_name, ',')) AS subsystem_name
    FROM cost_project_basic
    WHERE deleted = 0 AND subsystem_name IS NOT NULL AND btrim(subsystem_name) <> ''
    UNION
    SELECT DISTINCT tenant_id, btrim(regexp_split_to_table(subsystem_name, ',')) AS subsystem_name
    FROM cost_work_order
    WHERE deleted = 0 AND subsystem_name IS NOT NULL AND btrim(subsystem_name) <> ''
) source
WHERE source.subsystem_name <> ''
  AND NOT EXISTS (
      SELECT 1 FROM cost_subsystem_dict target
      WHERE target.tenant_id = source.tenant_id
        AND target.subsystem_name = source.subsystem_name
  );

UPDATE cost_schema_migration
SET description = '项目办填报字段、阶段多选和成本分系统字典',
    installed_on = CURRENT_TIMESTAMP,
    installed_by = CURRENT_USER
WHERE version = '20260819';

INSERT INTO cost_schema_migration(version, description, installed_on, installed_by)
SELECT '20260819', '项目办填报字段、阶段多选和成本分系统字典', CURRENT_TIMESTAMP, CURRENT_USER
WHERE NOT EXISTS (SELECT 1 FROM cost_schema_migration WHERE version = '20260819');

COMMIT;

SELECT tenant_id, project_code, unit_name, work_order_no, work_order_name,
       vertical_division, status, updater, update_time
FROM cost_work_order
WHERE deleted = 0 AND vertical_division = false
ORDER BY tenant_id, project_code, unit_name, work_order_no;
