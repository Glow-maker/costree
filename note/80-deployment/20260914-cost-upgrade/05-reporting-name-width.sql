-- PostgreSQL 9.2+ / DWS: change public to the actual COST schema.
-- Only for sites that have already completed the prior full upgrade.
BEGIN;
SET LOCAL search_path TO "public";
-- 20260914: derived project names must fit both reporting fields (255 characters).
DO $reporting_width$
DECLARE col text; kind text; maxlen integer;
BEGIN
 IF current_schema() IS NULL THEN RAISE EXCEPTION 'Target schema is unavailable'; END IF;
 FOREACH col IN ARRAY ARRAY['batch_category','platform_series'] LOOP
  SELECT data_type, character_maximum_length INTO kind, maxlen
    FROM information_schema.columns WHERE table_schema=current_schema()
      AND table_name='cost_project_basic' AND column_name=col;
  IF NOT FOUND THEN RAISE EXCEPTION 'Missing cost_project_basic.%: run full upgrade first', col; END IF;
  IF kind NOT IN ('character varying','text') THEN
   RAISE EXCEPTION 'Unexpected type for cost_project_basic.%: %', col, kind;
  END IF;
  IF maxlen IS NOT NULL AND maxlen < 255 THEN
   EXECUTE 'ALTER TABLE ' || quote_ident(current_schema()) || '.cost_project_basic ALTER COLUMN '
     || quote_ident(col) || ' TYPE varchar(255)';
  END IF;
 END LOOP;
END $reporting_width$;
COMMIT;
