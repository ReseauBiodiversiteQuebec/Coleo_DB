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