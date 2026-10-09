-- OPTIONAL: only when all other current schema upgrades are already complete.
-- Set the actual COST schema; this file does not create missing tables.
-- Role changes and scope replacement share this monotonically increasing revision.
BEGIN;
SET LOCAL search_path TO "public";
DO $auth_revision$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema()
                AND table_name='cost_auth_user_lock' AND column_name='revision') THEN
  EXECUTE 'ALTER TABLE ' || quote_ident(current_schema()) || '.cost_auth_user_lock ADD COLUMN revision bigint NOT NULL DEFAULT 0';
 END IF;
END $auth_revision$;
COMMENT ON COLUMN cost_auth_user_lock.revision IS '授权快照版本；角色或范围每次成功保存递增，拒绝陈旧页面覆盖';
COMMIT;
