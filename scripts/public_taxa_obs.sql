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
        UNIQUE (scientific_name)
    );

    CREATE INDEX IF NOT EXISTS taxa_obs_scientific_name_idx
    ON public.taxa_obs (scientific_name);


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

-------------------------------------------------------------------------------
-- * Migrate `taxa_name` values to `taxa_obs`
-------------------------------------------------------------------------------
INSERT INTO taxa_obs (scientific_name)
    SELECT distinct taxa_name
    FROM obs_species
    ON CONFLICT DO NOTHING;

UPDATE obs_species
    SET id_taxa_obs = taxa_obs.id
    FROM taxa_obs
    WHERE obs_species.taxa_name = taxa_obs.scientific_name;

-- TODO: TRIGGER ON INJECT (obs_species)

-------------------------------------------------------------------------------
-- CREATE FUNCTIONS AND TRIGGER to update taxa_ref on taxa_obs on insert
-------------------------------------------------------------------------------
    -- DROP the ref_species fk on obs_species
    -- ALTER TABLE public.obs_species DROP CONSTRAINT obs_species_taxa_name_fkey;

    -- CREATE the trigger for taxa_ref insertion:
    CREATE OR REPLACE FUNCTION trigger_insert_taxa_obs_from_obs_species()
    RETURNS TRIGGER AS $$
    BEGIN
        INSERT INTO taxa_obs (scientific_name)
        VALUES (NEW.taxa_name);
        RETURN NEW;
    END;
    $$ LANGUAGE 'plpgsql';

    DROP TRIGGER IF EXISTS insert_taxa_obs ON obs_species;
    CREATE TRIGGER insert_taxa_obs
        AFTER INSERT ON public.obs_species
        FOR EACH ROW
        EXECUTE PROCEDURE trigger_insert_taxa_obs_from_obs_species();

    -- TEST and ROLLBACK
    BEGIN;
    INSERT INTO obs_species (taxa_name, variable, value, observation_id)
    VALUES ('Vincent Beauregard', 'abondance', 1, 44);
    SELECT * FROM taxa_obs WHERE scientific_name = 'Vincent Beauregard';
    ROLLBACK;