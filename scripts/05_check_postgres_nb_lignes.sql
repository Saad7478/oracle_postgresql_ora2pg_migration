DO $$
<<first_block>>
DECLARE
    table_count integer := 0;
    target_schema text := 'mnt';
    r RECORD;
BEGIN
    FOR r IN
        SELECT c.relname AS table_name
        FROM pg_class AS c
        JOIN pg_namespace AS n ON n.oid = c.relnamespace
        WHERE n.nspname = target_schema
          AND NOT EXISTS (SELECT 1 FROM pg_inherits AS i WHERE i.inhrelid = c.oid)
          AND c.relkind IN ('r', 'p')
        ORDER BY c.relname
    LOOP
        EXECUTE format('SELECT count(*) FROM %I.%I', target_schema, r.table_name)
        INTO table_count;
        RAISE NOTICE 'Table %.% = % lignes', target_schema, r.table_name, table_count;
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Erreur : %', SQLERRM;
END first_block $$;
