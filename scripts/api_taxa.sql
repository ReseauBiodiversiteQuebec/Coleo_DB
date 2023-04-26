CREATE SCHEMA IF NOT EXISTS api;

-- -----------------------------------------------------
-- Table `api.taxa_ref_sources
-- DESCRIPTION: This table contains the list of sources for taxa data with priority
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS api.taxa_ref_sources (
  source_id INTEGER PRIMARY KEY,
  source_name VARCHAR(255) NOT NULL,
  source_priority INTEGER NOT NULL
);

DELETE FROM api.taxa_ref_sources;

INSERT INTO api.taxa_ref_sources
VALUES (1002, 'CDPNQ', 1),
	(1001, 'Bryoquel', 2),
	(147, 'VASCAN', 3),
	(3, 'ITIS', 4),
	(11, 'GBIF Backbone Taxonomy', 5),
	(1, 'Catalogue of Life', 6);

CREATE TABLE IF NOT EXISTS api.taxa_vernacular_sources(
	source_name VARCHAR(255) PRIMARY KEY,
	source_priority INTEGER NOT NULL
);

DELETE FROM api.taxa_vernacular_sources;

INSERT INTO api.taxa_vernacular_sources
VALUES ('CDPNQ', 1),
	('Bryoquel', 2),
	('Database of Vascular Plants of Canada (VASCAN)', 3),
	('Integrated Taxonomic Information System (ITIS)', 4);


-- -----------------------------------------------------------------------------
-- VIEW api.taxa
-- DESCRIPTION List all observed taxons with their matched attributes from ref
--   ref sources and vernacular sources
-- -----------------------------------------------------------------------------

-- DROP VIEW if exists api.taxa CASCADE;
CREATE OR REPLACE VIEW api.taxa AS (
	WITH all_ref AS (
         SELECT obs_lookup.id_taxa_obs,
            taxa_ref.scientific_name AS valid_scientific_name,
            taxa_ref.rank,
            taxa_ref.source_name,
            taxa_ref_sources.source_priority,
            taxa_ref.source_record_id AS source_taxon_key
           FROM taxa_obs_ref_lookup obs_lookup
             LEFT JOIN taxa_ref ON obs_lookup.id_taxa_ref_valid = taxa_ref.id
             JOIN taxa_ref_sources USING (source_id)
          WHERE obs_lookup.match_type IS NOT NULL AND obs_lookup.match_type <> 'complex'::text
          ORDER BY obs_lookup.id_taxa_obs, taxa_ref_sources.source_priority
        ), agg_ref AS (
         SELECT all_ref.id_taxa_obs,
            json_agg(json_build_object('source_name', all_ref.source_name, 'valid_scientific_name', all_ref.valid_scientific_name, 'rank', all_ref.rank, 'source_taxon_key', all_ref.source_taxon_key)) AS source_references
           FROM all_ref
          GROUP BY all_ref.id_taxa_obs
        ), best_ref AS (
         SELECT DISTINCT ON (all_ref.id_taxa_obs) all_ref.id_taxa_obs,
            all_ref.valid_scientific_name,
            all_ref.rank
           FROM all_ref
          ORDER BY all_ref.id_taxa_obs, all_ref.source_priority
        ), obs_group AS (
         SELECT DISTINCT ON (group_lookup.id_taxa_obs) group_lookup.id_taxa_obs,
            COALESCE(taxa_groups.vernacular_en, 'others'::text) AS group_en,
            COALESCE(taxa_groups.vernacular_fr, 'autres'::text) AS group_fr
           FROM taxa_obs_group_lookup group_lookup
             LEFT JOIN taxa_groups ON group_lookup.id_group = taxa_groups.id
          WHERE taxa_groups.level = 1
        ), vernacular_all AS (
         SELECT v_lookup.id_taxa_obs,
            taxa_vernacular.id,
            taxa_vernacular.source_name,
            taxa_vernacular.source_record_id,
            taxa_vernacular.name,
            taxa_vernacular.language,
            taxa_vernacular.gbif_taxon_key,
            taxa_vernacular.created_at,
            taxa_vernacular.modified_at,
            taxa_vernacular.modified_by,
            taxa_vernacular_sources.source_priority,
			v_lookup.match_type
           FROM taxa_obs_vernacular_lookup v_lookup
             LEFT JOIN taxa_vernacular ON v_lookup.id_taxa_vernacular = taxa_vernacular.id
             JOIN taxa_vernacular_sources USING (source_name)
          WHERE v_lookup.match_type IS NOT NULL
          ORDER BY v_lookup.id_taxa_obs, taxa_vernacular_sources.source_priority, v_lookup.match_type
        ), best_vernacular AS (
         SELECT ver_en.id_taxa_obs,
            ver_en.name AS vernacular_en,
            ver_fr.name AS vernacular_fr
           FROM ( SELECT DISTINCT ON (vernacular_all.id_taxa_obs) vernacular_all.id_taxa_obs,
                    vernacular_all.name
                   FROM vernacular_all
                  WHERE vernacular_all.language = 'eng'::text
                  ORDER BY vernacular_all.id_taxa_obs, vernacular_all.source_priority, vernacular_all.match_type) ver_en
             LEFT JOIN ( SELECT DISTINCT ON (vernacular_all.id_taxa_obs) vernacular_all.id_taxa_obs,
                    vernacular_all.name
                   FROM vernacular_all
                  WHERE vernacular_all.language = 'fra'::text
                  ORDER BY vernacular_all.id_taxa_obs, vernacular_all.source_priority, vernacular_all.match_type) ver_fr ON ver_en.id_taxa_obs = ver_fr.id_taxa_obs
        ), vernacular_group AS (
         SELECT vernacular_all.id_taxa_obs,
            json_agg(json_build_object('name', vernacular_all.name, 'source', vernacular_all.source_name, 'source_taxon_key', vernacular_all.source_record_id, 'language', vernacular_all.language)) AS vernacular
           FROM vernacular_all
          GROUP BY vernacular_all.id_taxa_obs
        ), taxa as(
 SELECT best_ref.id_taxa_obs,
    taxa_obs.scientific_name AS observed_scientific_name,
    best_ref.valid_scientific_name,
    best_ref.rank,
    best_vernacular.vernacular_en,
    best_vernacular.vernacular_fr,
    obs_group.group_en,
    obs_group.group_fr,
    vernacular_group.vernacular,
    agg_ref.source_references
   FROM best_ref
     LEFT JOIN taxa_obs ON taxa_obs.id = best_ref.id_taxa_obs
     LEFT JOIN vernacular_group ON best_ref.id_taxa_obs = vernacular_group.id_taxa_obs
     LEFT JOIN obs_group ON best_ref.id_taxa_obs = obs_group.id_taxa_obs
     LEFT JOIN best_vernacular ON best_ref.id_taxa_obs = best_vernacular.id_taxa_obs
     LEFT JOIN agg_ref ON best_ref.id_taxa_obs = agg_ref.id_taxa_obs
  ORDER BY best_ref.id_taxa_obs, best_vernacular.vernacular_en);

-- -----------------------------------------------------------------------------
-- VIEW api.taxa_surveyed
-- DESCRIPTION List observed taxa at cell, site and campain level
-- -----------------------------------------------------------------------------

-- DROP VIEW if exists api.taxa_surveyed CASCADE;
CREATE OR REPLACE VIEW api.taxa_surveyed AS (
    WITH survey_lookup AS (
        SELECT DISTINCT
            obs_species.id_taxa_obs,
            obs.campaign_id,
			campaigns.type campaign_type,
            campaigns.site_id,
            sites.site_code,
            sites.type site_type,
            sites.cell_id,
            cells.cell_code
        FROM obs_species 
        JOIN observations obs on obs.id = obs_species.observation_id
        JOIN campaigns on campaigns.id = obs.campaign_id
        JOIN sites on sites.id = campaigns.site_id
        JOIN cells on cells.id = sites.cell_id
    )
    SELECT
        taxa.*,
        campaign_id,
		campaign_type,
        site_id,
        site_code,
        site_type,
        cell_id,
        cell_code
    FROM api.taxa, survey_lookup
    WHERE survey_lookup.id_taxa_obs = taxa.id_taxa_obs
);


-- -----------------------------------------------------------------------------
-- FUNCTION api.match_taxa
-- DESCRIPTION Match taxa to a reference name and returns all children
-- -----------------------------------------------------------------------------

DROP FUNCTION IF EXISTS api.match_taxa(text);
CREATE FUNCTION match_taxa(
	taxa_name text	
)
RETURNS SETOF api.taxa AS $$
    with match_taxa_obs as (
        (
            select ref_lookup.id_taxa_obs id
            from taxa_ref
            left join taxa_obs_ref_lookup ref_lookup
                on taxa_ref.id = ref_lookup.id_taxa_ref
            where LOWER(taxa_ref.scientific_name) = LOWER(taxa_name)
        ) UNION (
            select vernacular_lookup.id_taxa_obs
            from taxa_vernacular
            left join taxa_obs_vernacular_lookup vernacular_lookup
                on taxa_vernacular.id = vernacular_lookup.id_taxa_vernacular
            where LOWER(taxa_vernacular.name) = LOWER(taxa_name)
        )
    ), synonym_taxa_obs as (
		select distinct taxa_obs.*
		from match_taxa_obs
		left join taxa_obs_ref_lookup search_lookup
			on match_taxa_obs.id = search_lookup.id_taxa_obs
		left join taxa_obs_ref_lookup synonym_lookup
			on search_lookup.id_taxa_ref_valid = synonym_lookup.id_taxa_ref_valid
		left join taxa_obs
			on synonym_lookup.id_taxa_obs = taxa_obs.id
		where search_lookup.match_type is not null)
	SELECT taxa.* from api.taxa, synonym_taxa_obs
	WHERE synonym_taxa_obs.id = api.taxa.id_taxa_obs
$$ LANGUAGE sql;

