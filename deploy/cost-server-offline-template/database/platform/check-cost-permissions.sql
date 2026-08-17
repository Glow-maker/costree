-- PostgreSQL 平台库检查脚本；在若依平台库执行，不是在独立成本业务库执行。
-- 达梦 MQB 请执行 check-cost-permissions-dm8.sql。
-- 执行前将下方租户编号 124 改为内网实际租户编号。
WITH required(permission) AS (
    VALUES
        ('cost:project:query'),
        ('cost:project-basic:create'), ('cost:project-basic:update'),
        ('cost:project-basic:approve'),
        ('cost:project-basic:delete'), ('cost:project-basic:query'),
        ('cost:project-basic:export'), ('cost:project-basic:import'),
        ('cost:work-order:create'), ('cost:work-order:update'),
        ('cost:work-order:approve'),
        ('cost:work-order:delete'), ('cost:work-order:query'),
        ('cost:work-order:export'), ('cost:work-order:import'),
        ('cost:warning:query'), ('cost:warning:push'), ('cost:warning:update')
), missing AS (
    SELECT r.permission
    FROM required r
    WHERE NOT EXISTS (
        SELECT 1 FROM system_menu m
        WHERE m.permission = r.permission AND m.deleted = 0
    )
)
SELECT CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ERROR' END AS status,
       count(*) AS missing_count,
       string_agg(permission, ', ' ORDER BY permission) AS missing_permissions
FROM missing;

WITH required(role_code) AS (
    VALUES ('cost_global_viewer'), ('cost_project_office'), ('cost_unit_user')
), missing AS (
    SELECT required.role_code
    FROM required
    WHERE NOT EXISTS (
        SELECT 1
        FROM system_role role
        WHERE role.tenant_id = 124
          AND role.code = required.role_code
          AND role.data_scope = 5
          AND role.status = 0
          AND role.deleted = 0
    )
)
SELECT CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ERROR' END AS status,
       count(*) AS missing_or_unsafe_role_count,
       string_agg(role_code, ', ' ORDER BY role_code) AS missing_or_unsafe_roles
FROM missing;

WITH expected(role_code, permission) AS (
    VALUES
        ('cost_global_viewer', '__PARENT__'),
        ('cost_global_viewer', 'cost:project:query'),
        ('cost_global_viewer', 'cost:project-basic:query'),
        ('cost_global_viewer', 'cost:project-basic:export'),
        ('cost_global_viewer', 'cost:work-order:query'),
        ('cost_global_viewer', 'cost:work-order:export'),
        ('cost_global_viewer', 'cost:warning:query'),
        ('cost_project_office', '__PARENT__'),
        ('cost_project_office', 'cost:project:query'),
        ('cost_project_office', 'cost:project-basic:query'),
        ('cost_project_office', 'cost:project-basic:create'),
        ('cost_project_office', 'cost:project-basic:update'),
        ('cost_project_office', 'cost:project-basic:export'),
        ('cost_project_office', 'cost:work-order:query'),
        ('cost_project_office', 'cost:work-order:export'),
        ('cost_unit_user', '__PARENT__'),
        ('cost_unit_user', 'cost:project:query'),
        ('cost_unit_user', 'cost:project-basic:query'),
        ('cost_unit_user', 'cost:work-order:query'),
        ('cost_unit_user', 'cost:work-order:create'),
        ('cost_unit_user', 'cost:work-order:update'),
        ('cost_unit_user', 'cost:work-order:export')
), missing AS (
    SELECT expected.role_code, expected.permission
    FROM expected
    WHERE NOT EXISTS (
        SELECT 1
        FROM system_role role
        JOIN system_role_menu role_menu
          ON role_menu.role_id = role.id
         AND role_menu.tenant_id = 124
         AND role_menu.deleted = 0
        JOIN system_menu menu
          ON menu.id = role_menu.menu_id
         AND menu.deleted = 0
        WHERE role.tenant_id = 124
          AND role.code = expected.role_code
          AND role.deleted = 0
          AND ((expected.permission = '__PARENT__' AND menu.path = '/cost-access-permissions')
               OR menu.permission = expected.permission)
    )
)
SELECT CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ERROR' END AS status,
       count(*) AS missing_mapping_count,
       string_agg(role_code || ':' || permission, ', ' ORDER BY role_code, permission) AS missing_mappings
FROM missing;
