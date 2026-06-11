-- 成本库 MVP 测试数据租户迁移 SQL
-- 目的：将外网测试库从 tenant_id=1 迁移到内网真实租户 tenant_id=124。
-- 注意：执行前确认目标租户 124 下没有同编号成本库测试数据，避免唯一索引冲突。

USE `costree_mvp`;

SET @old_tenant_id := 1;
SET @new_tenant_id := 124;

START TRANSACTION;

UPDATE `cost_model_node`
SET `tenant_id` = @new_tenant_id
WHERE `tenant_id` = @old_tenant_id;

UPDATE `cost_project`
SET `tenant_id` = @new_tenant_id
WHERE `tenant_id` = @old_tenant_id;

UPDATE `cost_project_basic`
SET `tenant_id` = @new_tenant_id
WHERE `tenant_id` = @old_tenant_id;

UPDATE `cost_work_order`
SET `tenant_id` = @new_tenant_id
WHERE `tenant_id` = @old_tenant_id;

UPDATE `cost_import_batch`
SET `tenant_id` = @new_tenant_id
WHERE `tenant_id` = @old_tenant_id;

UPDATE `cost_import_error`
SET `tenant_id` = @new_tenant_id
WHERE `tenant_id` = @old_tenant_id;

UPDATE `cost_warning_record`
SET `tenant_id` = @new_tenant_id
WHERE `tenant_id` = @old_tenant_id;

COMMIT;

SELECT 'cost_model_node' AS table_name, `tenant_id`, COUNT(*) AS total FROM `cost_model_node` GROUP BY `tenant_id`
UNION ALL
SELECT 'cost_project', `tenant_id`, COUNT(*) FROM `cost_project` GROUP BY `tenant_id`
UNION ALL
SELECT 'cost_project_basic', `tenant_id`, COUNT(*) FROM `cost_project_basic` GROUP BY `tenant_id`
UNION ALL
SELECT 'cost_work_order', `tenant_id`, COUNT(*) FROM `cost_work_order` GROUP BY `tenant_id`
UNION ALL
SELECT 'cost_import_batch', `tenant_id`, COUNT(*) FROM `cost_import_batch` GROUP BY `tenant_id`
UNION ALL
SELECT 'cost_import_error', `tenant_id`, COUNT(*) FROM `cost_import_error` GROUP BY `tenant_id`
UNION ALL
SELECT 'cost_warning_record', `tenant_id`, COUNT(*) FROM `cost_warning_record` GROUP BY `tenant_id`;
