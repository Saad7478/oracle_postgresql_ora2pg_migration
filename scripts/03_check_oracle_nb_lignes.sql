SET SERVEROUTPUT ON SIZE UNLIMITED;
DECLARE
    v_table_count INTEGER := 0;
    v_owner       VARCHAR2(30) := 'GEDMNT';
BEGIN
    FOR r IN (
        SELECT table_name 
        FROM all_tables
        WHERE owner = v_owner
          AND nested = 'NO' 
          AND secondary = 'N'
          AND (iot_type IS NULL OR iot_type != 'IOT_OVERFLOW')
        ORDER BY table_name
    ) 
    LOOP
        EXECUTE IMMEDIATE 'SELECT count(*) FROM ' || DBMS_ASSERT.ENQUOTE_NAME(v_owner) 
                          || '.' || DBMS_ASSERT.ENQUOTE_NAME(r.table_name)
        INTO v_table_count;
        
        DBMS_OUTPUT.PUT_LINE('Table ' || v_owner || '.' || r.table_name || ' = ' || v_table_count || ' lignes');
        
    END LOOP;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erreur rencontrée : ' || SQLERRM);
END;
/
