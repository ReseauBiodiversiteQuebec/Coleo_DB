------------------------------------------------------------
-- Create testing environment on coleo
------------------------------------------------------------

-- CREATE SCHEMA
-- Drop coleo_test schema if exists
DROP SCHEMA IF EXISTS coleo_test CASCADE;
-- Create schema for testing on coleo
CREATE SCHEMA coleo_test;
-- Copy all tables from public schema to coleo_test schema
DO $$DECLARE
    r record;
BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
        EXECUTE 'CREATE TABLE coleo_test.' || quote_ident(r.tablename) || ' (LIKE public.' || quote_ident(r.tablename) || ' INCLUDING ALL)';
    END LOOP;
END$$;
-- Copy all foreign keys from public schema to coleo_test schema
DO $$DECLARE
    r record;
BEGIN
    FOR r IN (SELECT conname, conrelid::regclass, confrelid::regclass FROM pg_constraint WHERE confrelid::regnamespace::text = 'public'::text) LOOP
        EXECUTE 'ALTER TABLE coleo_test.' || quote_ident(r.conrelid::text) || ' ADD CONSTRAINT ' || quote_ident(r.conname) || ' FOREIGN KEY (' || pg_get_constraintdef(r.oid) || ')';
    END LOOP;
END$$;

-- INSERT DATA
-- INSERT INTO required tables
INSERT INTO coleo_test.attributes select * from public.attributes;
INSERT INTO coleo_test.sites (cell_id, site_code, type, opened_at, geom) VALUES (598, '141_124_H01', 'forestier', '2024-01-01'::date, 'POINT(-68.9172 48.06593)');

-- GRANT PRIVILEGES
-- Create coleo_test_user user for testing
GRANT ALL PRIVILEGES ON SCHEMA coleo_test TO coleo_test_user;
GRANT ALL PRIVILEGES ON SCHEMA coleo_test TO read_write_all;
GRANT ALL PRIVILEGES ON SCHEMA coleo_test TO admins;
-- Grant all permissions on all tables in coleo_test schema
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA coleo_test TO coleo_test_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA coleo_test TO read_write_all;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA coleo_test TO admins;
-- Grant all permissions on all functions in coleo_test schema
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA coleo_test TO coleo_test_user;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA coleo_test TO read_write_all;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA coleo_test TO admins;
-- Grant read permissions on public schema
GRANT USAGE ON SCHEMA public TO coleo_test_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO coleo_test_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO coleo_test_user;
-- Grant read permissions on api schema
GRANT USAGE ON SCHEMA api TO coleo_test_user;
GRANT SELECT ON ALL TABLES IN SCHEMA api TO coleo_test_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA api TO coleo_test_user;


------------------------------------------------------------
-- refresh_coleo_test function
------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.refresh_coleo_test() 
RETURNS void AS 
$$
BEGIN
    -- Drop coleo_test schema if exists
    DROP SCHEMA IF EXISTS coleo_test CASCADE;
    -- Create schema for testing on coleo
    CREATE SCHEMA coleo_test;
    -- Copy all tables from public schema to coleo_test schema
    DECLARE
        r record;
        rec record;
    BEGIN
        FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
            EXECUTE 'CREATE TABLE coleo_test.' || quote_ident(r.tablename) || ' (LIKE public.' || quote_ident(r.tablename) || ' INCLUDING ALL)';
        END LOOP;
        -- Copy all foreign keys from public schema to coleo_test schema
        FOR rec IN (SELECT conname, conrelid::regclass, confrelid::regclass FROM pg_constraint WHERE confrelid::regnamespace::text = 'public'::text) LOOP
            EXECUTE 'ALTER TABLE coleo_test.' || quote_ident(rec.conrelid::text) || ' ADD CONSTRAINT ' || quote_ident(rec.conname) || ' FOREIGN KEY (' || pg_get_constraintdef(rec.oid) || ')';
        END LOOP;
    END;
    -- INSERT INTO required tables
    INSERT INTO coleo_test.attributes SELECT * FROM public.attributes;
    INSERT INTO coleo_test.sites (cell_id, site_code, type, opened_at, geom) VALUES (598, '141_124_H01', 'forestier', '2024-01-01'::date, 'POINT(-68.9172 48.06593)');
    
    -- GRANT PRIVILEGES
    -- Create coleo_test_user user for testing
    GRANT ALL PRIVILEGES ON SCHEMA coleo_test TO coleo_test_user;
    GRANT ALL PRIVILEGES ON SCHEMA coleo_test TO read_write_all;
    GRANT ALL PRIVILEGES ON SCHEMA coleo_test TO admins;
    -- Grant all permissions on all tables in coleo_test schema
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA coleo_test TO coleo_test_user;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA coleo_test TO read_write_all;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA coleo_test TO admins;
    -- Grant all permissions on all functions in coleo_test schema
    GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA coleo_test TO coleo_test_user;
    GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA coleo_test TO read_write_all;
    GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA coleo_test TO admins;
    -- Grant read permissions on public schema
    GRANT USAGE ON SCHEMA public TO coleo_test_user;
    GRANT SELECT ON ALL TABLES IN SCHEMA public TO coleo_test_user;
    GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO coleo_test_user;
    -- Grant read permissions on api schema
    GRANT USAGE ON SCHEMA api TO coleo_test_user;
    GRANT SELECT ON ALL TABLES IN SCHEMA api TO coleo_test_user;
    GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA api TO coleo_test_user;
END;
$$ 
LANGUAGE plpgsql;

-- GRANT PRIVILEGES
ALTER FUNCTION public.refresh_coleo_test() OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.refresh_coleo_test() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.refresh_coleo_test() TO coleo_test_user;
GRANT EXECUTE ON FUNCTION public.refresh_coleo_test() TO postgres;
GRANT EXECUTE ON FUNCTION public.refresh_coleo_test() TO read_write_all;
