-- 20260820 预警分析与闭环处置升级（PostgreSQL，可重复执行）。
BEGIN;
SELECT pg_advisory_xact_lock(hashtext('costree-schema-upgrade-20260820-warning'));

ALTER TABLE cost_warning_record
 ADD COLUMN IF NOT EXISTS project_code varchar(100), ADD COLUMN IF NOT EXISTS project_name varchar(255),
 ADD COLUMN IF NOT EXISTS domain_code varchar(100), ADD COLUMN IF NOT EXISTS domain_name varchar(255),
 ADD COLUMN IF NOT EXISTS model_code varchar(100), ADD COLUMN IF NOT EXISTS model_name varchar(255),
 ADD COLUMN IF NOT EXISTS cycle_no int4, ADD COLUMN IF NOT EXISTS workflow_status varchar(32),
 ADD COLUMN IF NOT EXISTS active_marker int2, ADD COLUMN IF NOT EXISTS initiator_user_id int8,
 ADD COLUMN IF NOT EXISTS initiator_user_name varchar(128), ADD COLUMN IF NOT EXISTS initiated_time timestamp,
 ADD COLUMN IF NOT EXISTS disposition_user_id int8, ADD COLUMN IF NOT EXISTS disposition_user_name varchar(128),
 ADD COLUMN IF NOT EXISTS cause_analysis varchar(1000), ADD COLUMN IF NOT EXISTS disposal_measure varchar(1000),
 ADD COLUMN IF NOT EXISTS expected_completion_date date, ADD COLUMN IF NOT EXISTS disposition_time timestamp,
 ADD COLUMN IF NOT EXISTS close_user_id int8, ADD COLUMN IF NOT EXISTS close_user_name varchar(128),
 ADD COLUMN IF NOT EXISTS close_time timestamp, ADD COLUMN IF NOT EXISTS return_reason varchar(500);

UPDATE cost_warning_record SET workflow_status='LEGACY', active_marker=NULL WHERE workflow_status IS NULL;
CREATE SEQUENCE IF NOT EXISTS cost_warning_receiver_seq START WITH 1;
CREATE SEQUENCE IF NOT EXISTS cost_warning_action_log_seq START WITH 1;
CREATE TABLE IF NOT EXISTS cost_warning_receiver (
 id int8 NOT NULL DEFAULT nextval('cost_warning_receiver_seq'), warning_record_id int8 NOT NULL,
 user_id int8 NOT NULL, username varchar(64), nickname varchar(128), notify_status varchar(32) NOT NULL DEFAULT 'PENDING',
 message_id int8, notified_time timestamp, failure_reason varchar(500), creator varchar(64) DEFAULT '',
 create_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, updater varchar(64) DEFAULT '',
 update_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, deleted int2 NOT NULL DEFAULT 0,
 tenant_id int8 NOT NULL DEFAULT 0, CONSTRAINT pk_cost_warning_receiver PRIMARY KEY(id));
CREATE TABLE IF NOT EXISTS cost_warning_action_log (
 id int8 NOT NULL DEFAULT nextval('cost_warning_action_log_seq'), warning_record_id int8 NOT NULL,
 action_type varchar(32) NOT NULL, operator_user_id int8 NOT NULL, operator_user_name varchar(128),
 operator_role_code varchar(100), from_status varchar(32), to_status varchar(32), action_content varchar(1000),
 creator varchar(64) DEFAULT '', create_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updater varchar(64) DEFAULT '', update_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
 deleted int2 NOT NULL DEFAULT 0, tenant_id int8 NOT NULL DEFAULT 0,
 CONSTRAINT pk_cost_warning_action_log PRIMARY KEY(id));
CREATE UNIQUE INDEX IF NOT EXISTS uk_cost_warning_receiver_user ON cost_warning_receiver(tenant_id, warning_record_id, user_id);
CREATE INDEX IF NOT EXISTS idx_cost_warning_receiver_task ON cost_warning_receiver(tenant_id, warning_record_id, notify_status);
CREATE INDEX IF NOT EXISTS idx_cost_warning_action_task ON cost_warning_action_log(tenant_id, warning_record_id, create_time);
CREATE INDEX IF NOT EXISTS idx_cost_warning_workflow ON cost_warning_record(tenant_id, workflow_status, active_marker);
CREATE UNIQUE INDEX IF NOT EXISTS uk_cost_warning_active ON cost_warning_record(tenant_id, warning_source, project_id, responsible_unit_name, active_marker);

INSERT INTO cost_schema_migration(version, description, installed_on, installed_by)
VALUES ('20260820', '预警分析与闭环处置', CURRENT_TIMESTAMP, CURRENT_USER)
ON CONFLICT (version) DO UPDATE SET description=EXCLUDED.description, installed_on=EXCLUDED.installed_on, installed_by=EXCLUDED.installed_by;
COMMIT;
