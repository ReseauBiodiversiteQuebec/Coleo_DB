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

CREATE INDEX IF NOT EXISTS taxa_vernacular_source_name_idx
  ON public.taxa_vernacular (source_name);

CREATE INDEX IF NOT EXISTS taxa_vernacular_source_record_id_idx
    ON public.taxa_vernacular (source_record_id);

CREATE INDEX IF NOT EXISTS taxa_vernacular_language_idx
    ON public.taxa_vernacular (language);


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
    rank_order integer not null default 0,
    UNIQUE (id_taxa_obs, id_taxa_vernacular)
);

CREATE INDEX IF NOT EXISTS id_taxa_obs_idx
  ON public.taxa_obs_vernacular_lookup (id_taxa_obs);

CREATE INDEX IF NOT EXISTS id_taxa_vernacular_idx
  ON public.taxa_obs_vernacular_lookup (id_taxa_vernacular);

-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- % FUNCTION taxa_vernacular_from_names
-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

DROP FUNCTION IF EXISTS public.taxa_vernacular_from_match(text);
CREATE OR REPLACE FUNCTION public.taxa_vernacular_from_match(
    observed_scientific_name text)
RETURNS TABLE (
    source text,
    source_taxon_key text,
    name text,
    language text
)
LANGUAGE plpython3u
AS $function$
from bdqc_taxa.vernacular import Vernacular
out = Vernacular.from_match(observed_scientific_name)
return out
$function$;

-- TEST
-- explain analyze select * from public.taxa_vernacular_from_match('Picoides villosus');

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

-- DROP FUNCTION IF EXISTS insert_taxa_vernacular_from_obs(integer) CASCADE;
CREATE OR REPLACE FUNCTION insert_taxa_vernacular_from_obs(
    ins_taxa_obs_id integer
)
RETURNS void AS
$BODY$
BEGIN
    WITH gbif_ref as (
        select
            taxa_obs.scientific_name as observed_scientific_name,
            gbif_ref.scientific_name,
            gbif_ref.source_record_id as gbif_taxon_key,
            array_length(gbif_ref.classification_srids, 1) as rank_order,
            ref_lu.match_type,
            ref_lu.is_parent
        from taxa_obs,
            taxa_obs_ref_lookup ref_lu,
            taxa_ref gbif_ref
        where taxa_obs.id = ins_taxa_obs_id
            and ref_lu.id_taxa_obs = taxa_obs.id
            and ref_lu.id_taxa_ref = gbif_ref.id
            and gbif_ref.source_name = 'GBIF Backbone Taxonomy'
    ), vernacular_sources as (
        -- UNION FROM GBIF PARENTS AND MATCHES
        select
            match.source,
            match.source_taxon_key,
            match.name,
            match.language,
            coalesce(gbif_ref.match_type, 'parent') as match_type,
            gbif_ref.rank_order
        from
            gbif_ref,
            public.taxa_vernacular_from_gbif(gbif_ref.gbif_taxon_key) match
        where gbif_ref.is_parent = true
        UNION
        select
            match.source,
            match.source_taxon_key,
            match.name,
            match.language,
            gbif_ref.match_type as match_type,
            gbif_ref.rank_order
        from
            gbif_ref,
            public.taxa_vernacular_from_match(gbif_ref.observed_scientific_name) match
        where gbif_ref.is_parent = false
    ), temp_vernacular as (
        select
            vernacular_sources.*,
            taxa_vernacular.id as id_taxa_vernacular
        from 
            vernacular_sources
        left join taxa_vernacular
            on vernacular_sources.source = taxa_vernacular.source_name
            and vernacular_sources.source_taxon_key = taxa_vernacular.source_record_id
            and vernacular_sources.language = taxa_vernacular.language
        where vernacular_sources.source is not null -- where a match is found
    ), new_vernacular as (
        INSERT INTO public.taxa_vernacular (
            source_name,
            source_record_id,
            name,
            language
        )
        SELECT
            source,
            source_taxon_key,
            name,
            language
        FROM temp_vernacular
        ON CONFLICT DO NOTHING
        RETURNING
            id as id_taxa_vernacular, source_name, source_record_id, language
    ), temp_lookup as (
        (
            SELECT
                new_vernacular.id_taxa_vernacular,
                temp_vernacular.match_type,
                temp_vernacular.rank_order
            from new_vernacular
            left join temp_vernacular
                on new_vernacular.source_name = temp_vernacular.source
                and new_vernacular.source_record_id = temp_vernacular.source_taxon_key
                and new_vernacular.language = temp_vernacular.language
        ) UNION (
            SELECT id_taxa_vernacular, match_type, rank_order from temp_vernacular
            where id_taxa_vernacular is not null
        )
    )
    INSERT INTO public.taxa_obs_vernacular_lookup (
        id_taxa_obs,
        id_taxa_vernacular,
        match_type,
        rank_order
    )
    SELECT
        ins_taxa_obs_id as id_taxa_obs, id_taxa_vernacular, match_type, rank_order
    FROM temp_lookup
    ON CONFLICT DO NOTHING;
END;
$BODY$
LANGUAGE 'plpgsql';

select insert_taxa_ref_from_taxa_obs(2372, 'Myotis lucifugus|Myotis septentrionalis|Myotis leibii');

select insert_taxa_vernacular_from_obs(2372);

------------------------------------------------------------------------
-- FUNCTION refresh_taxa_vernacular
------------------------------------------------------------------------

create function taxa_vernacular_fix_caribou ()
returns void as
$$
delete from taxa_obs_vernacular_lookup vlu
using taxa_ref, taxa_obs_ref_lookup, taxa_vernacular, taxa_obs
where taxa_ref.scientific_name <> 'Rangifer tarandus'
	and taxa_obs.scientific_name <> 'Rangifer tarandus'
	and taxa_ref.id = taxa_obs_ref_lookup.id_taxa_ref
	and taxa_obs.id = taxa_obs_ref_lookup.id_taxa_obs
	and taxa_vernacular.name = 'caribou'
	and taxa_vernacular.id = vlu.id_taxa_vernacular
	and vlu.id_taxa_obs = taxa_obs.id;
$$ language sql;


-- DROP FUNCTION IF EXISTS refresh_taxa_vernacular() CASCADE;
CREATE OR REPLACE FUNCTION refresh_taxa_vernacular()
RETURNS void AS
$$
BEGIN
    DELETE FROM taxa_obs_vernacular_lookup;
    DELETE FROM taxa_vernacular;
    PERFORM insert_taxa_vernacular_from_obs(id) FROM taxa_obs;
    PERFORM taxa_vernacular_fix_caribou();
END;
$$ LANGUAGE plpgsql;