SELECT
    (SELECT COUNT(*)
     FROM information_schema.tables
     WHERE table_schema = 'mnt'
       AND table_type = 'BASE TABLE') AS nb_tables,

    (SELECT COUNT(*)
     FROM pg_constraint con
     JOIN pg_namespace n
       ON n.oid = con.connamespace
     WHERE n.nspname = 'mnt') AS nb_contraintes,

    (SELECT COUNT(*)
     FROM pg_indexes
     WHERE schemaname = 'mnt') AS nb_index;
