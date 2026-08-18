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
    VALUES ('cost_global_viewer'), ('cost_research_department'),
           ('cost_project_office'), ('cost_unit_user')
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

SELECT CASE WHEN count(*) = 4 AND count(DISTINCT code) = 4 THEN 'OK' ELSE 'ERROR' END AS status,
       4 AS expected_role_count,
       count(*) AS actual_role_count,
       count(DISTINCT code) AS distinct_role_count
FROM system_role
WHERE tenant_id = 124
  AND code IN ('cost_global_viewer', 'cost_research_department',
               'cost_project_office', 'cost_unit_user')
  AND data_scope = 5
  AND status = 0
  AND deleted = 0;

WITH expected(role_code, permission) AS (
    VALUES
        ('cost_global_viewer', '__PARENT__'),
        ('cost_global_viewer', 'cost:project:query'),
        ('cost_global_viewer', 'cost:project-basic:query'),
        ('cost_global_viewer', 'cost:project-basic:export'),
        ('cost_global_viewer', 'cost:work-order:query'),
        ('cost_global_viewer', 'cost:work-order:export'),
        ('cost_global_viewer', 'cost:warning:query'),
        ('cost_research_department', '__PARENT__'),
        ('cost_research_department', 'cost:project:query'),
        ('cost_research_department', 'cost:project-basic:query'),
        ('cost_research_department', 'cost:project-basic:export'),
        ('cost_research_department', 'cost:work-order:query'),
        ('cost_research_department', 'cost:work-order:export'),
        ('cost_research_department', 'cost:warning:query'),
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
       29 AS expected_mapping_count,
       count(*) AS missing_mapping_count,
       string_agg(role_code || ':' || permission, ', ' ORDER BY role_code, permission) AS missing_mappings
FROM missing;

-- 四个成本角色在受管权限目录下不得存在预期矩阵以外的映射。
WITH expected(role_code, permission) AS (
    VALUES
        ('cost_global_viewer', '__PARENT__'),
        ('cost_global_viewer', 'cost:project:query'),
        ('cost_global_viewer', 'cost:project-basic:query'),
        ('cost_global_viewer', 'cost:project-basic:export'),
        ('cost_global_viewer', 'cost:work-order:query'),
        ('cost_global_viewer', 'cost:work-order:export'),
        ('cost_global_viewer', 'cost:warning:query'),
        ('cost_research_department', '__PARENT__'),
        ('cost_research_department', 'cost:project:query'),
        ('cost_research_department', 'cost:project-basic:query'),
        ('cost_research_department', 'cost:project-basic:export'),
        ('cost_research_department', 'cost:work-order:query'),
        ('cost_research_department', 'cost:work-order:export'),
        ('cost_research_department', 'cost:warning:query'),
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
), actual AS (
    SELECT DISTINCT role.code AS role_code,
           CASE WHEN menu.path = '/cost-access-permissions'
                THEN '__PARENT__' ELSE menu.permission END AS permission
    FROM system_role role
    JOIN system_role_menu role_menu
      ON role_menu.role_id = role.id
     AND role_menu.tenant_id = 124
     AND role_menu.deleted = 0
    JOIN system_menu menu
      ON menu.id = role_menu.menu_id
     AND menu.deleted = 0
    WHERE role.tenant_id = 124
      AND role.code IN ('cost_global_viewer', 'cost_research_department',
                        'cost_project_office', 'cost_unit_user')
      AND role.deleted = 0
      AND (menu.path = '/cost-access-permissions'
           OR menu.permission IN (SELECT permission FROM expected WHERE permission <> '__PARENT__'))
), unexpected AS (
    SELECT actual.role_code, actual.permission
    FROM actual
    WHERE NOT EXISTS (
        SELECT 1 FROM expected
        WHERE expected.role_code = actual.role_code
          AND expected.permission = actual.permission
    )
)
SELECT CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ERROR' END AS status,
       count(*) AS unexpected_mapping_count,
       string_agg(role_code || ':' || permission, ', ' ORDER BY role_code, permission) AS unexpected_mappings
FROM unexpected;

-- 同一用户只能拥有一个普通成本角色，科研部也参与互斥检查。
WITH conflicts AS (
    SELECT user_role.user_id
    FROM system_user_role user_role
    JOIN system_role role
      ON role.id = user_role.role_id
     AND role.tenant_id = 124
     AND role.deleted = 0
    WHERE user_role.tenant_id = 124
      AND user_role.deleted = 0
      AND role.code IN ('cost_global_viewer', 'cost_research_department',
                        'cost_project_office', 'cost_unit_user')
    GROUP BY user_role.user_id
    HAVING count(DISTINCT role.code) > 1
)
SELECT CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ERROR' END AS status,
       count(*) AS conflict_user_count
FROM conflicts;
