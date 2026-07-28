-- 在若依平台库执行，不是在独立成本业务库执行。
WITH required(permission) AS (
    VALUES
        ('cost:project:query'),
        ('cost:project-basic:create'), ('cost:project-basic:update'),
        ('cost:project-basic:delete'), ('cost:project-basic:query'),
        ('cost:project-basic:export'), ('cost:project-basic:import'),
        ('cost:work-order:create'), ('cost:work-order:update'),
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
