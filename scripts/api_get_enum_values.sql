---------------------------------------------------
-- FUNCTION api.get_enum_values
-- DESCRIPTION returns enum options for a column
---------------------------------------------------

-- FUNCTION: api.get_enum_values(text)

-- DROP FUNCTION IF EXISTS api.get_enum_values(text);

CREATE OR REPLACE FUNCTION api.get_enum_values(
    enum_type text
) RETURNS table(enum_values text) AS $$
    SELECT enumlabel::text
    FROM pg_enum
    WHERE enumtypid = (
        SELECT oid
        FROM pg_type
        WHERE typname = enum_type
    );
$$ LANGUAGE sql stable;

-- Usage
--SELECT * from api.get_enum_values('enum_campaigns_type');
