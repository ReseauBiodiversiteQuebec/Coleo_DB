------------------------------------------------------------
-- Create testing environment on coleo
------------------------------------------------------------

-- CREATE SCHEMA
-- Drop coleo_test schema if exists
DROP SCHEMA IF EXISTS coleo_test;
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
INSERT INTO coleo_test.attributes from (select * from public.attributes);

-- GRANT PRIVILEGES
-- Create coleo_test_user user for testing
CREATE USER coleo_test_user WITH PASSWORD 'b4VmDTuun8yHTK';
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
