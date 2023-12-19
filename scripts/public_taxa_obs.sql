-------------------------------------------------------------------------------
-- DESCRIPTION
-- Create table to contain observed taxa names and related attributes
-- from raw observed files
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- CREATE public.taxa_obs resource
-------------------------------------------------------------------------------
    CREATE TABLE public.taxa_obs (
        id serial PRIMARY KEY,
        scientific_name text NOT NULL,
        created_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
        parent_taxa_name text,
        UNIQUE (scientific_name)
    );

    CREATE INDEX IF NOT EXISTS taxa_obs_scientific_name_idx
    ON public.taxa_obs (scientific_name);


-- access
ALTER TABLE IF EXISTS public.taxa_obs
    OWNER to postgres;

REVOKE ALL ON TABLE public.taxa_obs FROM coleo_test_user;
REVOKE ALL ON TABLE public.taxa_obs FROM read_only_all;
REVOKE ALL ON TABLE public.taxa_obs FROM read_only_public;
REVOKE ALL ON TABLE public.taxa_obs FROM read_write_all;

GRANT SELECT ON TABLE public.taxa_obs TO coleo_test_user;

GRANT ALL ON TABLE public.taxa_obs TO glaroc;

GRANT ALL ON TABLE public.taxa_obs TO postgres;

GRANT SELECT ON TABLE public.taxa_obs TO read_only_all;

GRANT SELECT ON TABLE public.taxa_obs TO read_only_public;

GRANT INSERT, TRUNCATE, REFERENCES, TRIGGER, UPDATE, SELECT ON TABLE public.taxa_obs TO read_write_all;


-------------------------------------------------------------------------------
-- ALTER public.obs_species ADD COLUMN id_taxa_obs
-- Description : will relate to taxa_obs table with many-to one relations
-- Other scripts:
-- * Create index
-------------------------------------------------------------------------------

    ALTER TABLE obs_species ADD COLUMN id_taxa_obs integer;

    ALTER TABLE obs_species
        ADD CONSTRAINT obs_species_id_taxa_obs_fkey
        FOREIGN KEY (id_taxa_obs)
        REFERENCES taxa_obs (id)
        ON UPDATE CASCADE;

    CREATE INDEX IF NOT EXISTS obs_species_id_taxa_obs_idx
        ON public.obs_species (id_taxa_obs);

    -- ADD FOREIGN KEY CONSTRAINT
    ALTER TABLE public.obs_species
        DROP CONSTRAINT IF EXISTS obs_species_id_taxa_obs_fkey;

    ALTER TABLE public.obs_species
        ADD CONSTRAINT obs_species_id_taxa_obs_fkey
        FOREIGN KEY (id_taxa_obs)
        REFERENCES public.taxa_obs (id)
        ON UPDATE CASCADE
        ON DELETE NO ACTION;

-------------------------------------------------------------------------------
-- * Migrate `taxa_name` values to `taxa_obs`
-------------------------------------------------------------------------------
INSERT INTO taxa_obs (scientific_name, parent_taxa_name)
    SELECT distinct (taxa_name, parent_taxa_name)
    FROM obs_species
    ON CONFLICT DO NOTHING;

UPDATE obs_species
    SET id_taxa_obs = taxa_obs.id
    FROM taxa_obs
    WHERE obs_species.taxa_name = taxa_obs.scientific_name;

-- TODO: TRIGGER ON INJECT (obs_species)

-------------------------------------------------------------------------------
-- CREATE FUNCTIONS AND TRIGGER to update taxa_obs on obs_species insert
-------------------------------------------------------------------------------
-- CREATE the trigger for taxa_ref insertion:
CREATE OR REPLACE FUNCTION trigger_insert_taxa_obs_from_obs_species()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO taxa_obs (scientific_name, parent_taxa_name)
        VALUES (NEW.taxa_name, NEW.parent_taxa_name)
        ON CONFLICT DO NOTHING;
    NEW.id_taxa_obs := (
        SELECT id
        FROM taxa_obs
        WHERE scientific_name = NEW.taxa_name
            and parent_taxa_name = NEW.parent_taxa_name
        );
    RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

DROP TRIGGER IF EXISTS insert_taxa_obs ON obs_species;
CREATE TRIGGER insert_taxa_obs
    BEFORE INSERT ON public.obs_species
    FOR EACH ROW
    EXECUTE PROCEDURE trigger_insert_taxa_obs_from_obs_species();

-- TEST and ROLLBACK
BEGIN;
INSERT INTO obs_species (taxa_name, variable, value, observation_id, parent_taxa_name)
VALUES ('Victor Cameron', 'abondance', 1, 206212, 'Vincent Beauregard');
SELECT * FROM taxa_obs WHERE scientific_name = 'Victor Cameron';
SELECT * FROM obs_species WHERE taxa_name = 'Victor Cameron';
ROLLBACK;

-- TEST for existing taxa
BEGIN;
INSERT INTO obs_species (taxa_name, variable, value, observation_id, parent_taxa_name)
VALUES ('Acer saccharum', 'recouvrement', 0, 206212, 'Plantae');
SELECT * FROM taxa_obs WHERE scientific_name = 'Acer saccharum';
SELECT * FROM obs_species WHERE taxa_name = 'Acer saccharum';
ROLLBACK;

-------------------------------------------------------------------------------
-- ALTER public.obs_edna ADD COLUMN id_taxa_obs
-- Description : will relate to taxa_obs table with many-to one relations
-- Other scripts:
-- * Create index
-------------------------------------------------------------------------------

    ALTER TABLE obs_edna ADD COLUMN id_taxa_obs integer;

    ALTER TABLE obs_edna
        ADD CONSTRAINT obs_species_id_taxa_obs_fkey
        FOREIGN KEY (id_taxa_obs)
        REFERENCES taxa_obs (id)
        ON UPDATE CASCADE;

    CREATE INDEX IF NOT EXISTS obs_edna_id_taxa_obs_idx
        ON public.obs_edna (id_taxa_obs);

    -- ADD FOREIGN KEY CONSTRAINT
    ALTER TABLE public.obs_edna
        DROP CONSTRAINT IF EXISTS obs_edna_id_taxa_obs_fkey;

    ALTER TABLE public.obs_edna
        ADD CONSTRAINT obs_edna_id_taxa_obs_fkey
        FOREIGN KEY (id_taxa_obs)
        REFERENCES public.taxa_obs (id)
        ON UPDATE CASCADE
        ON DELETE NO ACTION;


-------------------------------------------------------------------------------
-- TEST CASE : Taxa_obs delete if only referenced by obs_edna
-------------------------------------------------------------------------------

BEGIN;
    -- INSERT INTO taxa_obs (scientific_name)
    --     VALUES ('Vincent Beauregard');

    WITH taxa_obs AS (
        SELECT id
        FROM taxa_obs
        WHERE scientific_name = 'Vincent Beauregard'
        )
    INSERT INTO obs_edna (taxa_name, observation_id, sequence_count, type_edna, notes, sequence_count_corrected, id_taxa_obs)
        VALUES ('Vincent Beauregard', 162045, 11429, 'improbable', '', 11429, (SELECT id FROM taxa_obs));

    -- Print number of taxa_obs
    SELECT 'Number of taxa_obs: ', count(*) FROM taxa_obs
    WHERE scientific_name = 'Vincent Beauregard';

    DELETE FROM obs_edna WHERE taxa_name = 'Vincent Beauregard';

    -- Print number of obs_edna
    SELECT 'Number of obs_edna: ', count(*) FROM obs_edna
    WHERE taxa_name = 'Vincent Beauregard';

    -- Print number of taxa_obs
    SELECT 'Number of taxa_obs: ', count(*) FROM taxa_obs
    WHERE scientific_name = 'Vincent Beauregard';
ROLLBACK;

-- Assert

-------------------------------------------------------------------------------
-- CREATE FUNCTIONS AND TRIGGER to update taxa_obs on insert on obs_edna
-------------------------------------------------------------------------------
    -- Add default value to created_at and updated_at
    ALTER TABLE public.obs_edna ALTER COLUMN created_at SET DEFAULT CURRENT_TIMESTAMP;
    ALTER TABLE public.obs_edna ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP;

    -- CREATE the trigger for taxa_obs insertion:
    CREATE OR REPLACE FUNCTION trigger_insert_taxa_obs_from_obs_edna()
    RETURNS TRIGGER AS $$
    BEGIN
        INSERT INTO taxa_obs (scientific_name, parent_taxa_name)
            VALUES (NEW.taxa_name, NEW.parent_taxa_name)
            ON CONFLICT DO NOTHING;
        NEW.id_taxa_obs := (
            SELECT id
            FROM taxa_obs
            WHERE scientific_name = NEW.taxa_name
                and parent_taxa_name = NEW.parent_taxa_name
            );
        RETURN NEW;
    END;
    $$ LANGUAGE 'plpgsql';

    DROP TRIGGER IF EXISTS insert_taxa_obs ON obs_edna;
    CREATE TRIGGER insert_taxa_obs
        BEFORE INSERT ON public.obs_edna
        FOR EACH ROW
        EXECUTE PROCEDURE trigger_insert_taxa_obs_from_obs_edna();

    -- TEST and ROLLBACK
    BEGIN;
    INSERT INTO obs_edna (observation_id, taxa_name, sequence_count, type_edna, notes, parent_taxa_name)
    VALUES (160085, 'Victor Cameron', 1, 'improbable', NULL, 'Vincent Beauregard');
    SELECT * FROM taxa_obs WHERE scientific_name = 'Victor Cameron';
    SELECT * FROM obs_edna WHERE taxa_name = 'Victor Cameron';
    ROLLBACK;

    -- TEST for existing taxa
    BEGIN;
    INSERT INTO obs_edna (observation_id, landmark_id, taxa_name, sequence_count, type_edna, notes)
    VALUES (160085, 14790, 'Sander vitreus', 1, 'improbable', NULL);
    SELECT * FROM taxa_obs WHERE scientific_name = 'Sander vitreus';
    SELECT * FROM obs_edna WHERE taxa_name = 'Sander vitreus'
        order by id desc limit 10;
    SELECT * FROM taxa_obs_ref_lookup lu, taxa_obs
    WHERE lu.id_taxa_obs = taxa_obs.id
    AND scientific_name = 'Sander vitreus';
    ROLLBACK;