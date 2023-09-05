-------------------------------------------------------------------------------
-- DESCRIPTION
-- Create table to contain taxa entities from sources and related ressources
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CREATE FUNCTION public.taxa_match_sources
-- DESCRIPTION Uses python `bdqc_taxa` package to generate `taxa_ref` records
--  from taxonomic sources (ITIS, COL, etc) matched to input taxa name
-------------------------------------------------------------------------------
-- INSTALL python PL EXTENSION TO SUPPORT API CALL
CREATE EXTENSION IF NOT EXISTS plpython3u;

-- CREATE FUNCTION TO ACCESS REFERENCE TAXA FROM GLOBAL NAMES
CREATE OR REPLACE FUNCTION public.match_taxa_sources(
    name text,
    name_authorship text DEFAULT NULL)
RETURNS TABLE (
    source_name text,
    source_id numeric,
    source_record_id text,
    scientific_name text,
    authorship text,
    rank text,
    rank_order integer,
    valid boolean,
    valid_srid text,
    classification_srids text[],
    match_type text,
    is_parent boolean
)
LANGUAGE plpython3u
AS $function$
from bdqc_taxa.taxa_ref import TaxaRef
out = TaxaRef.from_all_sources(name, name_authorship)
return out
$function$;

-- TEST match_taxa_sources
-- SELECT * FROM public.match_taxa_sources('Cyanocitta cristata');
-- SELECT * FROM public.match_taxa_sources('Antigone canadensis');


-------------------------------------------------------------------------------
-- CREATE TABLE public.taxa_ref
-- DESCRIPTION Stores taxa attributes from reference sources
-------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.taxa_ref (
    id SERIAL PRIMARY KEY,
    source_name text NOT NULL,
    source_id numeric,
    source_record_id text NOT NULL,
    scientific_name text NOT NULL,
    authorship text,
    rank text NOT NULL,
    valid boolean NOT NULL,
    valid_srid text NOT NULL,
    classification_srids text[],
    created_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (source_name, source_record_id)
);
CREATE INDEX IF NOT EXISTS source_id_srid_idx
  ON public.taxa_ref (source_id, valid_srid);

CREATE INDEX IF NOT EXISTS scientific_name_idx
  ON public.taxa_ref (scientific_name);
  

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

    -- Foreign key constraints

    -- ALTER TABLE public.taxa_obs_ref_lookup
    --     DROP CONSTRAINT IF EXISTS taxa_obs_ref_lookup_id_taxa_obs_fkey;

    ALTER TABLE public.taxa_obs_ref_lookup
        ADD CONSTRAINT taxa_obs_ref_lookup_id_taxa_obs_fkey
        FOREIGN KEY (id_taxa_obs)
        REFERENCES public.taxa_obs (id)
        ON DELETE CASCADE
        ON UPDATE CASCADE;

    -- ALTER TABLE public.taxa_obs_ref_lookup
    --     DROP CONSTRAINT IF EXISTS taxa_obs_ref_lookup_id_taxa_ref_fkey;

    ALTER TABLE public.taxa_obs_ref_lookup
        ADD CONSTRAINT taxa_obs_ref_lookup_id_taxa_ref_fkey
        FOREIGN KEY (id_taxa_ref)
        REFERENCES public.taxa_ref (id)
        ON DELETE CASCADE
        ON UPDATE CASCADE;

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

-------------------------------------------------------------------------------
-- REFRESH taxa_ref and taxa_obs_ref_lookup
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION refresh_taxa_ref()
RETURNS void AS
$$
BEGIN
    DELETE FROM public.taxa_ref;
    DELETE FROM public.taxa_obs_ref_lookup;
    PERFORM public.insert_taxa_ref_from_taxa_obs(
        id, scientific_name)
    FROM public.taxa_obs;
END;
$$ LANGUAGE 'plpgsql';