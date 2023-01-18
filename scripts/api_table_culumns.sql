-- FUNCTION: api.table_columns(text)

-- DROP FUNCTION IF EXISTS api.table_columns(text);

CREATE OR REPLACE FUNCTION api.table_columns(
    table_name text DEFAULT NULL::text)
    RETURNS TABLE(column_name text, data_type text, udt_name text, is_nullable text)
    AS $$
        SELECT column_name, data_type, udt_name, is_nullable 
        FROM information_schema.columns 
        WHERE table_name=$1
            and table_schema='public';
    $$ LANGUAGE 'sql' STABLE;
