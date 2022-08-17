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
-- CREATE public.taxa_obs to public.taxa_ref correspondance table
-------------------------------------------------------------------------------
    CREATE TABLE IF NOT EXISTS public.taxa_obs_ref_lookup (
        id_taxa_obs integer NOT NULL,
        id_taxa_ref integer NOT NULL,
        id_taxa_ref_valid integer NOT NULL,
        match_type text,
        is_parent boolean,
        UNIQUE (id_taxa_obs, id_taxa_ref)
    );

    CREATE INDEX IF NOT EXISTS id_taxa_obs_idx
    ON public.taxa_obs_ref_lookup (id_taxa_obs);

    CREATE INDEX IF NOT EXISTS id_taxa_ref_idx
    ON public.taxa_obs_ref_lookup (id_taxa_ref);

    CREATE INDEX IF NOT EXISTS id_taxa_ref_valid_idx
    ON public.taxa_obs_ref_lookup (id_taxa_ref_valid);

-------------------------------------------------------------------------------
-- CREATE FUNCTIONS AND TRIGGER to update taxa_ref on taxa_obs on insert
-------------------------------------------------------------------------------

    -- DROP FUNCTION IF EXISTS insert_taxa_ref_from_taxa_obs(integer, text, text) CASCADE;
    CREATE OR REPLACE FUNCTION insert_taxa_ref_from_taxa_obs(
        taxa_obs_id integer,
        taxa_obs_scientific_name text,
        taxa_obs_authorship text DEFAULT NULL
    )
    RETURNS void AS
    $BODY$
    BEGIN
        DROP TABLE IF EXISTS temp_src_ref;
        CREATE TEMPORARY TABLE temp_src_ref AS (
            SELECT *
            FROM public.match_taxa_sources(taxa_obs_scientific_name, taxa_obs_authorship)
        );

        INSERT INTO public.taxa_ref (
            source_name,
            source_id,
            source_record_id,
            scientific_name,
            authorship,
            rank,
            valid,
            valid_srid,
            classification_srids
        )
        SELECT
            source_name,
            source_id,
            source_record_id,
            scientific_name,
            authorship,
            rank,
            valid,
            valid_srid,
            classification_srids
        FROM temp_src_ref
        ON CONFLICT DO NOTHING;

        INSERT INTO public.taxa_obs_ref_lookup (
                id_taxa_obs, id_taxa_ref, id_taxa_ref_valid, match_type, is_parent)
            SELECT
                taxa_obs_id AS id_taxa_obs,
                taxa_ref.id AS id_taxa_ref,
                valid_taxa_ref.id AS id_taxa_ref_valid,
             temp_src_ref.match_type AS match_type, 
             temp_src_ref.is_parent AS is_parent
            FROM
             temp_src_ref,
                taxa_ref,
                taxa_ref as valid_taxa_ref
            WHERE  
             temp_src_ref.source_id = taxa_ref.source_id
                AND temp_src_ref.source_record_id = taxa_ref.source_record_id
                and temp_src_ref.source_id = valid_taxa_ref.source_id
                and temp_src_ref.valid_srid = valid_taxa_ref.source_record_id
            ON CONFLICT DO NOTHING;
    END;
    $BODY$
    LANGUAGE 'plpgsql';


    -- CREATE the trigger for taxa_ref insertion:

    CREATE OR REPLACE FUNCTION trigger_insert_taxa_ref_from_taxa_obs()
    RETURNS TRIGGER AS $$
    BEGIN
        PERFORM public.insert_taxa_ref_from_taxa_obs(
            NEW.id, NEW.scientific_name
            );
        RETURN NEW;
    END;
    $$ LANGUAGE 'plpgsql';

    DROP TRIGGER IF EXISTS insert_taxa_ref ON public.taxa_obs;
    CREATE TRIGGER insert_taxa_ref
        AFTER INSERT ON public.taxa_obs
        FOR EACH ROW
        EXECUTE PROCEDURE trigger_insert_taxa_ref_from_taxa_obs();


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