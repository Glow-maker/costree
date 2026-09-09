-- PostgreSQL 9.2+ / GaussDB(DWS). SQL only; not MySQL or DM.
-- CHANGE public below to the schema actually used by cost-server, not the database name.
-- Execute as a whole with stop-on-error; stop cost writes first and keep your backup.
SET search_path TO "public";
DO $schema_guard$ BEGIN
 IF current_schema() IS NULL THEN RAISE EXCEPTION 'Target schema does not exist or is inaccessible'; END IF;
END $schema_guard$;
SELECT current_database(), current_user, current_schema(), version();
SELECT required.table_name, c.table_name IS NOT NULL AS exists_now FROM (VALUES
 ('cost_model_node'),
 ('cost_project'),
 ('cost_project_basic'),
 ('cost_work_order'),
 ('cost_work_order_ledger_detail'),
 ('cost_unit_dict'),
 ('cost_subsystem_dict'),
 ('cost_unit_cost_detail'),
 ('cost_user_project_scope'),
 ('cost_user_unit_scope'),
 ('cost_user_domain_scope'),
 ('cost_import_batch'),
 ('cost_import_error'),
 ('cost_warning_record'),
 ('cost_warning_receiver'),
 ('cost_warning_action_log'),
 ('cost_schema_migration'),
 ('cost_user_role'),
 ('cost_user_role_action'),
 ('cost_auth_user_lock')) required(table_name) LEFT JOIN information_schema.tables c ON c.table_schema=current_schema() AND c.table_name=required.table_name;
SELECT table_name,column_name,data_type,column_default,is_nullable FROM information_schema.columns WHERE table_schema=current_schema() AND ((table_name='cost_auth_user_lock' AND column_name='revision') OR (table_name IN ('cost_user_project_scope','cost_user_unit_scope','cost_user_domain_scope') AND column_name='id'));
