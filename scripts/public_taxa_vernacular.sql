-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- % TABLE taxa_vernacular
-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

DROP TABLE IF EXISTS public.taxa_vernacular CASCADE;
CREATE TABLE public.taxa_vernacular (
    id SERIAL PRIMARY KEY,
    source_name text NOT NULL,
    source_record_id text NOT NULL,
    name text NOT NULL,
    language text NOT NULL,
    gbif_taxon_key text,
    created_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modified_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modified_by text NOT NULL DEFAULT CURRENT_USER,
    UNIQUE (source_name, source_record_id, language)
);

-- DROP TRIGGER IF EXISTS update_modified_at ON public.taxa_vernacular;
-- CREATE TRIGGER update_modified_at
--   BEFORE UPDATE ON public.taxa_vernacular FOR EACH ROW
--   EXECUTE PROCEDURE trigger_set_timestamp();

-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- % TABLE taxa_vernacular_ref_lookup
-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

DROP TABLE IF EXISTS public.taxa_obs_vernacular_lookup CASCADE;
CREATE TABLE IF NOT EXISTS public.taxa_obs_vernacular_lookup (
    id_taxa_obs integer NOT NULL,
    id_taxa_vernacular integer NOT NULL,
    match_type text,
    UNIQUE (id_taxa_obs, id_taxa_vernacular)
);

CREATE INDEX IF NOT EXISTS id_taxa_obs_idx
  ON public.taxa_obs_vernacular_lookup (id_taxa_obs);

CREATE INDEX IF NOT EXISTS id_taxa_vernacular_idx
  ON public.taxa_obs_vernacular_lookup (id_taxa_vernacular);

-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- % FUNCTION taxa_vernacular_from_sources
-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

DROP FUNCTION IF EXISTS public.taxa_vernacular_from_sources(text);
CREATE FUNCTION public.taxa_vernacular_from_sources(
    scientific_name text)
RETURNS TABLE (
    source text,
    source_taxon_key text,
    name text,
    language text
)
LANGUAGE plpython3u
AS $function$
from bdqc_taxa.vernacular import Vernacular
out = Vernacular.from_gbif_match(scientific_name)
return out
$function$;

-- TEST
-- explain analyze select * from public.taxa_vernacular_from_sources('Picoides villosus');

DROP FUNCTION IF EXISTS public.taxa_vernacular_from_gbif(text);
CREATE FUNCTION public.taxa_vernacular_from_gbif(
    gbif_taxon_key text)
RETURNS TABLE (
    source text,
    source_taxon_key text,
    name text,
    language text
)
LANGUAGE plpython3u
AS $function$
from bdqc_taxa.vernacular import Vernacular
out = Vernacular.from_gbif(int(gbif_taxon_key))
return out
$function$;

-- explain analyze select * from public.taxa_vernacular_from_gbif('9192501');


-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- % FUNCTION insert_taxa_vernacular_from_obs
-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

DROP FUNCTION IF EXISTS insert_taxa_vernacular_from_obs(integer) CASCADE;
CREATE OR REPLACE FUNCTION insert_taxa_vernacular_from_obs(
    ins_taxa_obs_id integer
)
RETURNS void AS
$BODY$
BEGIN
    WITH gbif_ref as (
        select
            distinct on (gbif_ref.id)
            gbif_lookup.id_taxa_obs,
            gbif_ref.source_record_id,
            gbif_lookup.match_type,
            gbif_ref.scientific_name
        from taxa_obs_ref_lookup gbif_lookup
        left join taxa_ref gbif_ref on gbif_lookup.id_taxa_ref = gbif_ref.id
        where gbif_lookup.id_taxa_obs = ins_taxa_obs_id
            and gbif_ref.source_name = 'GBIF Backbone Taxonomy'
    ), temp_vernacular as (
        select
            match.*,
            gbif_ref.match_type,
            taxa_vernacular.id as id_taxa_vernacular,
            gbif_ref.source_record_id as gbif_taxon_key
        from 
            gbif_ref,
            public.taxa_vernacular_from_gbif(gbif_ref.source_record_id) match
        left join taxa_vernacular
            on match.source = taxa_vernacular.source_name
            and match.source_taxon_key = taxa_vernacular.source_record_id
            and match.language = taxa_vernacular.language
        where match.source is not null -- where a match is found
    ), new_vernacular as (
        INSERT INTO public.taxa_vernacular (
            source_name,
            source_record_id,
            name,
            language,
            gbif_taxon_key)
        SELECT
            source,
            source_taxon_key,
            name,
            language,
            gbif_taxon_key
        FROM temp_vernacular
        ON CONFLICT DO NOTHING
        RETURNING
            id as id_taxa_vernacular, source_name, source_record_id, language
    ), temp_lookup as (
        (
            SELECT
                new_vernacular.id_taxa_vernacular,
                temp_vernacular.match_type
            from new_vernacular
            left join temp_vernacular
                on new_vernacular.source_name = temp_vernacular.source
                and new_vernacular.source_record_id = temp_vernacular.source_taxon_key
                and new_vernacular.language = temp_vernacular.language
        ) UNION (
            SELECT id_taxa_vernacular, match_type from temp_vernacular
            where id_taxa_vernacular is not null
        )
    )
    INSERT INTO public.taxa_obs_vernacular_lookup
    SELECT
        ins_taxa_obs_id as id_taxa_obs, id_taxa_vernacular, match_type
    FROM temp_lookup
    ON CONFLICT DO NOTHING;
END;
$BODY$
LANGUAGE 'plpgsql';

-- select insert_taxa_vernacular_from_obs(2072);