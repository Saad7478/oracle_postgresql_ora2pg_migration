SELECT
    (SELECT COUNT(*)
     FROM all_tables
     WHERE owner = 'GEDMNT') AS nb_tables,

    (SELECT COUNT(*)
     FROM all_constraints
     WHERE owner = 'GEDMNT') AS nb_contraintes,

    (SELECT COUNT(*)
     FROM all_indexes
     WHERE owner = 'GEDMNT') AS nb_index
FROM dual;
