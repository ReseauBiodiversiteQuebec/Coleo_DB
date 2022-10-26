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
	with all_ref as (
		select
			obs_lookup.id_taxa_obs,
			taxa_ref.scientific_name valid_scientific_name,
			taxa_ref.rank,
			taxa_ref.source_name,
			source_priority,
			taxa_ref.source_record_id source_taxon_key
		from taxa_obs_ref_lookup obs_lookup
		left join taxa_ref on obs_lookup.id_taxa_ref_valid = taxa_ref.id
		JOIN api.taxa_ref_sources USING (source_id)
		WHERE obs_lookup.match_type is not null
			AND obs_lookup.match_type != 'complex'
		ORDER BY obs_lookup.id_taxa_obs, source_priority
	), agg_ref as (
		select
			id_taxa_obs,
			json_agg(json_build_object(
			   'source_name', source_name,
			   'valid_scientific_name', valid_scientific_name,
			   'rank', rank, 
			   'source_taxon_key', source_taxon_key)) as source_references
		from all_ref
		group by (id_taxa_obs)
	), best_ref as (
		select
			distinct on (id_taxa_obs)
			id_taxa_obs,
			valid_scientific_name,
			rank
		from all_ref
		-- order by id_taxa_obs, source_priority
	), obs_group as (
		select
			distinct on (group_lookup.id_taxa_obs)
			group_lookup.id_taxa_obs,
			coalesce(taxa_groups.vernacular_en, 'others') as group_en,
			coalesce(taxa_groups.vernacular_fr, 'autres') as group_fr
		from taxa_obs_group_lookup group_lookup
		left join taxa_groups on group_lookup.id_group = taxa_groups.id
		where taxa_groups.level = 1
	), vernacular_all as(
		select v_lookup.id_taxa_obs, taxa_vernacular.*, source_priority
		from taxa_obs_vernacular_lookup v_lookup
		left join taxa_vernacular on v_lookup.id_taxa_vernacular = taxa_vernacular.id
		JOIN api.taxa_vernacular_sources USING (source_name)
		where match_type is not null
		order by v_lookup.id_taxa_obs, source_priority
	), best_vernacular as (
		select
			ver_en.id_taxa_obs,
			ver_en.name as vernacular_en,
			ver_fr.name as vernacular_fr
		from (select distinct on (id_taxa_obs) id_taxa_obs, name from vernacular_all where language = 'eng' order by id_taxa_obs, source_priority NULLS LAST) as ver_en
		left join (select distinct on (id_taxa_obs) id_taxa_obs, name from vernacular_all where language = 'fra' order by id_taxa_obs, source_priority NULLS LAST) as ver_fr
			on ver_en.id_taxa_obs = ver_fr.id_taxa_obs
	), vernacular_group as (
		select 
			vernacular_all.id_taxa_obs,
			json_agg(json_build_object(
				'name', vernacular_all.name,
				'source', vernacular_all.source_name,
				'source_taxon_key', vernacular_all.source_record_id,
				'language', vernacular_all.language
			)) as vernacular
		from vernacular_all
		group by vernacular_all.id_taxa_obs
	)
	select
		best_ref.id_taxa_obs,
        taxa_obs.scientific_name observed_scientific_name,
		best_ref.valid_scientific_name,
		best_ref.rank,
		best_vernacular.vernacular_en,
		best_vernacular.vernacular_fr,
		obs_group.group_en,
		obs_group.group_fr,
		vernacular_group.vernacular,
		agg_ref.source_references
	from best_ref
	left join taxa_obs on taxa_obs.id = best_ref.id_taxa_obs
	left join vernacular_group
		on best_ref.id_taxa_obs = vernacular_group.id_taxa_obs
	left join obs_group
		on best_ref.id_taxa_obs = obs_group.id_taxa_obs
	left join best_vernacular
		on best_ref.id_taxa_obs = best_vernacular.id_taxa_obs
	left join agg_ref
		on best_ref.id_taxa_obs = agg_ref.id_taxa_obs
	ORDER BY
		best_ref.id_taxa_obs,
        best_vernacular.vernacular_en NULLS LAST
);

-- -----------------------------------------------------------------------------
-- VIEW api.taxa_surveyed
-- DESCRIPTION List observed taxa at cell, site and campain level
-- -----------------------------------------------------------------------------

DROP VIEW if exists api.taxa_surveyed CASCADE;
CREATE VIEW api.taxa_surveyed AS (
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
-- FUNCTION api.taxa_richness
-- DESCRIPTION Count observed taxa at cell, site and campain level
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.taxa_richness (
    cell_id_val integer DEFAULT NULL,
    cell_code_val text DEFAULT NULL,
    site_id_val integer DEFAULT NULL,
    site_code_val text DEFAULT NULL,
    site_type_val text DEFAULT NULL,
    campaign_id_val integer DEFAULT NULL,
    campaign_type_val text DEFAULT NULL
) RETURNS integer AS $$
	WITH sel_taxa_obs as (
		SELECT id_taxa_obs
		FROM api.taxa_surveyed
		WHERE
			coalesce(taxa_surveyed.cell_id = cell_id_val, true)
			AND coalesce(taxa_surveyed.cell_code = cell_code_val, true)
			AND coalesce(taxa_surveyed.site_id = site_id_val, true)
			AND coalesce(taxa_surveyed.site_code = site_code_val, true)
			AND coalesce(taxa_surveyed.site_type::text = site_type_val, true)
			AND coalesce(taxa_surveyed.campaign_id = campaign_id_val, true)
			AND coalesce(taxa_surveyed.campaign_type::text = campaign_type_val, true)
	), sum_valid_ref as (
		select
			id_taxa_ref_valid id_taxa_ref,
			min(lu.id_taxa_obs) id_taxa_obs,
			count(id_taxa_ref_valid) count_taxa_ref,
			min(match_type) match_type
		from sel_taxa_obs sel
		left join taxa_obs_ref_lookup lu on sel.id_taxa_obs = lu.id_taxa_obs
		where match_type != 'complex' or match_type is null
		group by id_taxa_ref_valid
	)
	select
		count(distinct(sum_valid_ref.id_taxa_obs))
	from sum_valid_ref
	where count_taxa_ref = 1 and
		match_type is not null
$$ LANGUAGE SQL;


-- with sum_valid_ref as (
-- 	select
-- 		id_taxa_ref_valid id_taxa_ref,
-- 		min(id_taxa_obs) id_taxa_obs,
-- 		count(distinct(id_taxa_obs)) count_taxa_obs,
-- 		count(id_taxa_ref_valid) count_taxa_ref,
-- 		min(match_type) match_type
-- 	from taxa_obs_ref_lookup
-- 	where match_type != 'complex' or match_type is null
-- 	group by id_taxa_ref_valid
-- )
-- select
-- 	count(distinct(id_taxa_obs))
-- from sum_valid_ref
-- where count_taxa_ref = 1 and
-- 	match_type is not null