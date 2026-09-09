-- 用途：定位 cost_warning_record 存在但升级找不到表的问题。
-- 在刚才失败的同一个连接中执行；仅回滚失败事务并读取系统目录，不修改表或数据。
-- ROLLBACK 放弃当前事务中尚未提交的操作；不会撤销此前已经提交的其他事务。
ROLLBACK;

-- 结果 1：连接到了哪个数据库、当前 schema 和查找路径。
SELECT current_database() AS database_name, current_user AS login_user,
       current_schema() AS schema_name,
       current_setting('search_path') AS search_path,
       version() AS database_version;

-- 结果 2：列出所有 schema 下名称包含 warning 的关系对象。
-- visible=false 表示该对象不能按无 schema 的表名直接找到，或被同名对象遮蔽。
SELECT n.nspname AS schema_name, c.relname AS object_name, c.relkind AS object_kind,
       pg_table_is_visible(c.oid) AS visible,
       has_schema_privilege(n.oid, 'USAGE') AS schema_usage
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE lower(c.relname) LIKE '%warning%'
ORDER BY n.nspname, c.relname;

-- 结果 3：精确核对目标表字段，包括大小写不同的同名表。
SELECT table_schema, table_name, column_name, data_type
FROM information_schema.columns
WHERE lower(table_name)='cost_warning_record'
ORDER BY table_schema, table_name, ordinal_position;

-- 结果 4：若回滚后仍存在临时函数，读取其局部设置；无结果也正常。
SELECT n.nspname AS function_schema, p.proname AS function_name,
       p.proconfig AS function_settings
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE p.proname='costree_add_warning_column';
