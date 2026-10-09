SELECT version(), current_database(), current_user, current_schema();
SHOW search_path;
SELECT table_schema, table_name FROM information_schema.tables WHERE table_name IN ('cost_project','cost_schema_migration','cost_user_role','cost_user_role_action','cost_auth_user_lock') ORDER BY table_schema,table_name;
