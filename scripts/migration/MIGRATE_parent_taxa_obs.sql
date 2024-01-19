------------------------------------------------------------------------------
-- ADD COLUMN parent_taxa_name
-- Description : will contain the name of the parent taxa to disentangle the taxonomy
-------------------------------------------------------------------------------

ALTER TABLE obs_species ADD COLUMN parent_taxa_name text;

ALTER TABLE taxa_obs ADD COLUMN parent_taxa_name text;


-------------------------------------------------------------------------------
-- Add parent_taxa_name to FUNCTIONS AND TRIGGER to update taxa_obs on obs_species insert
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
-- ALTER public.obs_edna ADD COLUMN parent_taxa_name
-------------------------------------------------------------------------------

ALTER TABLE obs_edna ADD COLUMN parent_taxa_name text;

-- REPLACE the trigger for taxa_obs insertion:
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


-------------------------------------------------------------------------------
-- Add parent_taxa_name to FUNCTION public.taxa_match_sources
-------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.match_taxa_sources(text, text);

CREATE OR REPLACE FUNCTION public.match_taxa_sources(
    name text,
    name_authorship text DEFAULT NULL,
    parent_taxa_name text DEFAULT NULL)
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
import plpy
try:
  return TaxaRef.from_all_sources(name, name_authorship, parent_taxa_name)
except Exception as e:
  plpy.notice(f'Failed to match_taxa_sources: {name} {name_authorship}')
  raise Exception(e)
out = TaxaRef.from_all_sources(name, name_authorship)
return out
$function$;

-- TEST match_taxa_sources
-- SELECT * FROM public.match_taxa_sources('Cyanocitta cristata', NULL, 'Animalia');
-- SELECT * FROM public.match_taxa_sources('Antigone canadensis');


------------------------------------------------------------------------------
-- Add parent_taxa_obs to FUNCTIONS AND TRIGGER to update taxa_ref on taxa_obs on insert
-------------------------------------------------------------------------------
-- DROP FUNCTION IF EXISTS insert_taxa_ref_from_taxa_obs(integer, text, text) CASCADE;
CREATE OR REPLACE FUNCTION insert_taxa_ref_from_taxa_obs(
    taxa_obs_id integer,
    taxa_obs_scientific_name text,
    taxa_obs_parent_taxa_name text DEFAULT NULL
)
RETURNS void AS
$BODY$
BEGIN
    DROP TABLE IF EXISTS temp_src_ref;
    CREATE TEMPORARY TABLE temp_src_ref AS (
        SELECT *
        FROM public.match_taxa_sources(taxa_obs_scientific_name, NULL, taxa_obs_parent_taxa_name)
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
-- Add parent_taxa_name to REFRESH taxa_ref and taxa_obs_ref_lookup
-------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION refresh_taxa_ref()
RETURNS void AS
$$
BEGIN
    DELETE FROM public.taxa_ref;
    DELETE FROM public.taxa_obs_ref_lookup;
    PERFORM public.insert_taxa_ref_from_taxa_obs(
        id, scientific_name, parent_taxa_name)
    FROM public.taxa_obs;
END;
$$ LANGUAGE 'plpgsql';



--------------------------------------------------------------------------------
-- CREATE FUNCTION public.fix_taxa_obs_parent_taxa_name
-- DESCRIPTION When conflicting parent_taxa_name are found in taxa_obs,
--  this function will update taxa_obs and taxa_obs_ref_lookup to match
--  the parent_taxa_name of the taxa_obs record
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fix_taxa_obs_parent_taxa_name(id_taxa_obs integer, parent_taxa_name text)
RETURNS void AS
$$
DECLARE
  taxa_obs_record RECORD;
  scientific_name_rec record;
BEGIN
    -- Update taxa_ref
    UPDATE public.taxa_obs SET parent_taxa_name = $2 WHERE taxa_obs.id = $1;

    FOR taxa_obs_record IN SELECT * FROM public.taxa_obs WHERE taxa_obs.id = $1
    LOOP
        DELETE FROM public.taxa_obs_ref_lookup WHERE public.taxa_obs_ref_lookup.id_taxa_obs = taxa_obs_record.id;

        PERFORM public.insert_taxa_ref_from_taxa_obs(
            taxa_obs_record.id, taxa_obs_record.scientific_name, taxa_obs_record.parent_taxa_name
        );
    END LOOP;
    -- Update taxa_vernacular
    FOR scientific_name_rec IN
        SELECT
            distinct on (taxa_ref.scientific_name, taxa_ref.rank)
            taxa_ref.id,
            taxa_ref.scientific_name,
            LOWER(taxa_ref.rank),
            taxa_obs_vernacular_lookup.id_taxa_vernacular
        FROM taxa_ref, taxa_obs_ref_lookup, taxa_obs_vernacular_lookup, taxa_obs
        where taxa_ref.id = taxa_obs_ref_lookup.id_taxa_ref
            and taxa_obs_ref_lookup.id_taxa_obs = taxa_obs.id
            and taxa_obs_vernacular_lookup.id_taxa_obs = taxa_obs.id
            and taxa_obs.id = $1
    LOOP
        BEGIN
            DELETE from taxa_obs_vernacular_lookup where taxa_obs_vernacular_lookup.id_taxa_vernacular = scientific_name_rec.id_taxa_vernacular;

            PERFORM insert_taxa_vernacular_using_ref(scientific_name_rec.id);
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'insert_taxa_vernacular_using_ref(%s) failed for taxa (%s): %', scientific_name_rec.id, scientific_name_rec.scientific_name, SQLERRM;
        END;
    END LOOP;
END;
$$ LANGUAGE 'plpgsql';


-- Test
select * from taxa_obs where scientific_name = 'Salix';
select * from taxa_obs where id = 2672;
select fix_taxa_obs_parent_taxa_name(2672, 'Plantae');

select * from taxa_obs where id = 2672;

SELECT taxa_ref.*
FROM taxa_obs, taxa_ref, taxa_obs_ref_lookup
WHERE taxa_obs.id = taxa_obs_ref_lookup.id_taxa_obs
    AND taxa_ref.id = taxa_obs_ref_lookup.id_taxa_ref
    AND taxa_obs.id = 2418;

SELECT taxa_vernacular.*
FROM taxa_obs, taxa_vernacular, taxa_obs_vernacular_lookup
WHERE taxa_obs.id = taxa_obs_vernacular_lookup.id_taxa_obs
    AND taxa_vernacular.id = taxa_obs_vernacular_lookup.id_taxa_vernacular
    AND taxa_obs.id = 2418;


--------------------------------------------------------------------------------
-- Fix problematic taxa names
--------------------------------------------------------------------------------
SELECT
    o.scientific_name,
    COUNT(DISTINCT r.scientific_name) AS counts,
    ARRAY_AGG(DISTINCT r.scientific_name),
    ARRAY_AGG(DISTINCT o.id) as id_taxa_obs,
    ARRAY_AGG(DISTINCT c.type) as campaign_type
FROM taxa_ref r
JOIN taxa_obs_ref_lookup lu ON r.id = lu.id_taxa_ref
JOIN taxa_obs o ON o.id = lu.id_taxa_obs
JOIN obs_species os ON os.id_taxa_obs = o.id
JOIN observations obs ON obs.id = os.observation_id
JOIN campaigns c ON c.id = obs.campaign_id
WHERE r.rank = 'phylum'
GROUP BY o.scientific_name
HAVING COUNT(DISTINCT r.scientific_name) > 1
ORDER BY counts DESC;

-- Fix issues
select fix_taxa_obs_parent_taxa_name(23531, 'Plantae');
select fix_taxa_obs_parent_taxa_name(2418, 'Plantae');
select fix_taxa_obs_parent_taxa_name(2418, 'Plantae');
select fix_taxa_obs_parent_taxa_name(6172, 'Mollusca');
select fix_taxa_obs_parent_taxa_name(6586, 'Arthropoda');
select fix_taxa_obs_parent_taxa_name(95727, 'Rotifera');
select fix_taxa_obs_parent_taxa_name(2565, 'Rotifera');
select fix_taxa_obs_parent_taxa_name(5815, 'Arthropoda');
select fix_taxa_obs_parent_taxa_name(6491, 'Annelida');
select fix_taxa_obs_parent_taxa_name(116517, 'Arthropoda');
select fix_taxa_obs_parent_taxa_name(6237, 'Arthropoda');
select fix_taxa_obs_parent_taxa_name(5898, 'Arthropoda');
select fix_taxa_obs_parent_taxa_name(2433, 'Rotifera');




select * from taxa_obs where id = 2418;