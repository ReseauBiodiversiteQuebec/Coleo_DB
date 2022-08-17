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
  
