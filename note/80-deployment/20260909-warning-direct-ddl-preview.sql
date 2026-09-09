-- 仅定位并生成预警表缺失字段的普通 DDL，不执行生成结果。
-- schema 按现场截图为 costree_mvp；不是完整升级脚本，不写版本号。
-- 先在失败连接执行 ROLLBACK，放弃该事务尚未提交的操作。
ROLLBACK;

-- 第一组必须有且仅有一行；没有结果时停止，不能把第二组为空当成字段已齐。
SELECT n.nspname AS schema_name, c.relname AS table_name, c.relkind
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='costree_mvp' AND c.relname='cost_warning_record';

-- 第二组应返回 22 行：字段状态及待执行语句。
-- 本查询仅检查字段是否存在，不确认既有字段的类型、默认值和业务数据正确性。
SELECT e.column_name, e.expected_type,
       CASE WHEN a.attname IS NULL THEN 'MISSING' ELSE 'EXISTS' END AS column_status,
       CASE WHEN a.attname IS NULL THEN
         'ALTER TABLE "costree_mvp"."cost_warning_record" ADD COLUMN '
         || quote_ident(e.column_name) || ' ' || e.expected_type || ';'
       ELSE NULL END AS proposed_sql
FROM (VALUES
    (1, 'project_code', 'varchar(100)'),
    (2, 'project_name', 'varchar(255)'),
    (3, 'domain_code', 'varchar(100)'),
    (4, 'domain_name', 'varchar(255)'),
    (5, 'model_code', 'varchar(100)'),
    (6, 'model_name', 'varchar(255)'),
    (7, 'cycle_no', 'int4'),
    (8, 'workflow_status', 'varchar(32)'),
    (9, 'active_marker', 'int2'),
    (10, 'initiator_user_id', 'int8'),
    (11, 'initiator_user_name', 'varchar(128)'),
    (12, 'initiated_time', 'timestamp'),
    (13, 'disposition_user_id', 'int8'),
    (14, 'disposition_user_name', 'varchar(128)'),
    (15, 'cause_analysis', 'varchar(1000)'),
    (16, 'disposal_measure', 'varchar(1000)'),
    (17, 'expected_completion_date', 'date'),
    (18, 'disposition_time', 'timestamp'),
    (19, 'close_user_id', 'int8'),
    (20, 'close_user_name', 'varchar(128)'),
    (21, 'close_time', 'timestamp'),
    (22, 'return_reason', 'varchar(500)')
) AS e(sort_no, column_name, expected_type)
JOIN pg_catalog.pg_namespace n ON n.nspname='costree_mvp'
JOIN pg_catalog.pg_class c ON c.relnamespace=n.oid AND c.relname='cost_warning_record'
LEFT JOIN pg_catalog.pg_attribute a ON a.attrelid=c.oid
  AND a.attname=e.column_name AND a.attnum>0 AND NOT a.attisdropped
ORDER BY e.sort_no;
-- 将第二组结果交回核对，勿直接重新执行旧的临时函数段。
-- 生成语句若后续执行，必须独立作为顶层 SQL 执行，不能塞回原 DO/EXECUTE 包装。
-- 补列不是完整预警升级；状态处理、接收/操作表、索引及验收仍需单独核对。
