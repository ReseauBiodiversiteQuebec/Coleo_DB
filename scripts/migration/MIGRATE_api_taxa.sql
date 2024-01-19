--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- This script migrates the api.taxa VIEW to a MATERIALIZED VIEW
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

------------------------------------------------------------------------
-- 1. DROP the old view and objects that depend on it
--
-- match_taxa() function
-- api.match_taxa() function
-- api.taxa_surveyed view
-- indicators.pheno_acoustique view
-- api.pheno_acoustique view
------------------------------------------------------------------------

DROP VIEW IF EXISTS api.taxa CASCADE;


------------------------------------------------------------------------
-- 2. Create the new materialized view
------------------------------------------------------------------------

/*
This selection creates a materialized view named "api.taxa" that combines data from multiple tables to generate a taxonomy view. 

The selection uses common table expressions (CTEs) to perform various data transformations and aggregations. 

The CTEs used in this selection are as follows:
- all_ref: Retrieves taxonomic information from the taxa_obs_ref_lookup and taxa_ref tables, filtering out complex matches and ordering the results by source priority.
- agg_ref: Aggregates the taxonomic references for each taxa_obs_id into a JSON array.
- best_ref: Selects the best taxonomic reference for each taxa_obs_id based on source priority.
- obs_group: Retrieves the taxonomic group information for each taxa_obs_id, replacing null values with default values.
- vernacular_all: Retrieves vernacular names for each taxa_obs_id from the taxa_obs_vernacular_lookup and taxa_vernacular tables, ordering the results by match type and source priority.
- best_vernacular: Selects the best vernacular names (in English and French) for each taxa_obs_id.
- vernacular_group: Aggregates the vernacular names for each taxa_obs_id into a JSON array.
- ref_rank: Retrieves taxonomic references for each taxa_obs_id, filtering out duplicates based on rank and source priority.
- full_taxonomy: Combines the taxonomic information from the ref_rank CTE to generate the full taxonomy view.

The resulting materialized view "api.taxa" will contain the following columns:
- id_taxa_obs: The unique identifier for each taxonomic observation.
- valid_scientific_name: The valid scientific name for the taxon.
- rank: The taxonomic rank of the taxon.
- source_name: The name of the data source for the taxon.
- source_priority: The priority of the data source for the taxon.
- source_taxon_key: The unique identifier for the taxon in the data source.
- source_references: A JSON array containing the taxonomic references for the taxon.
- group_en: The English name of the taxonomic group for the taxon.
- group_fr: The French name of the taxonomic group for the taxon.
- vernacular: A JSON array containing the vernacular names for the taxon.
- kingdom: The scientific name of the kingdom for the taxon.
- phylum: The scientific name of the phylum for the taxon.
- class: The scientific name of the class for the taxon.
- order: The scientific name of the order for the taxon.
- family: The scientific name of the family for the taxon.
- genus: The scientific name of the genus for the taxon.
- species: The scientific name of the species for the taxon.
*/
CREATE MATERIALIZED VIEW api.taxa AS
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
            all_ref.rank,
			api.taxa_ref_sources.source_priority,
			taxa_rank_order.order as rank_order
           FROM all_ref
             JOIN api.taxa_ref_sources USING (source_name)
			 JOIN taxa_rank_order on all_ref.rank = taxa_rank_order.rank_name
          ORDER BY all_ref.id_taxa_obs, api.taxa_ref_sources.source_priority
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
            COALESCE(taxa_vernacular_sources.source_priority, 9999) AS "coalesce",
            v_lookup.match_type,
            COALESCE(v_lookup.rank_order, 9999) AS rank_order
           FROM taxa_obs_vernacular_lookup v_lookup
             LEFT JOIN taxa_vernacular ON v_lookup.id_taxa_vernacular = taxa_vernacular.id
             LEFT JOIN taxa_vernacular_sources USING (source_name)
          WHERE v_lookup.match_type IS NOT NULL AND v_lookup.match_type <> 'complex'::text
        ORDER BY v_lookup.id_taxa_obs, v_lookup.match_type, (COALESCE(v_lookup.rank_order, 9999)) DESC, taxa_vernacular_sources.source_priority
    ), best_vernacular AS (
        SELECT ver_en.id_taxa_obs,
            ver_en.name AS vernacular_en,
            ver_fr.name AS vernacular_fr
        FROM ( SELECT DISTINCT ON (vernacular_all.id_taxa_obs) vernacular_all.id_taxa_obs,
            vernacular_all.name
            FROM vernacular_all
            WHERE vernacular_all.language = 'eng'::text) ver_en
        LEFT JOIN ( SELECT DISTINCT ON (vernacular_all.id_taxa_obs) vernacular_all.id_taxa_obs,
            vernacular_all.name
            FROM vernacular_all
            WHERE vernacular_all.language = 'fra'::text) ver_fr ON ver_en.id_taxa_obs = ver_fr.id_taxa_obs
    ), vernacular_group AS (
        SELECT vernacular_all.id_taxa_obs,
            json_agg(json_build_object('name', vernacular_all.name, 'source', vernacular_all.source_name, 'source_taxon_key', vernacular_all.source_record_id, 'language', vernacular_all.language)) AS vernacular
        FROM vernacular_all
        GROUP BY vernacular_all.id_taxa_obs
    ), ref_all_rank AS (
        SELECT DISTINCT ON (lu.id_taxa_obs, taxa_ref.rank) lu.id_taxa_obs,
            taxa_ref.scientific_name,
            taxa_ref.rank,
			taxa_rank_order.order,
			taxa_ref_sources.source_priority
        FROM taxa_obs taxa_obs_1,
            taxa_ref,
            taxa_obs_ref_lookup lu,
            taxa_ref_sources,
			best_ref,
			taxa_rank_order
        WHERE lu.id_taxa_obs = taxa_obs_1.id AND taxa_ref.id = lu.id_taxa_ref_valid AND taxa_ref.source_name = taxa_ref_sources.source_name AND lu.id_taxa_obs = best_ref.id_taxa_obs AND taxa_ref.rank = taxa_rank_order.rank_name
        ORDER BY lu.id_taxa_obs, taxa_ref.rank, taxa_ref_sources.source_priority
    ), ref_rank AS (
		select ref_all_rank.id_taxa_obs,
			ref_all_rank.scientific_name,
			ref_all_rank.rank,
			ref_all_rank.order,
			best_ref.source_priority,
			best_ref.rank_order best_ref_rank
		from ref_all_rank
		left join best_ref on best_ref.id_taxa_obs = ref_all_rank.id_taxa_obs
		where ref_all_rank.order <= best_ref.rank_order
	), full_taxonomy AS (
        SELECT kingdom.id_taxa_obs,
            kingdom.scientific_name AS kingdom,
            phylum.scientific_name AS phylum,
            class.scientific_name AS class,
            "order".scientific_name AS "order",
            family.scientific_name AS family,
            genus.scientific_name AS genus,
            species.scientific_name AS species
           FROM ( SELECT ref_rank.id_taxa_obs,
                    ref_rank.scientific_name
                   FROM ref_rank
                  WHERE ref_rank.rank = 'kingdom'::text) kingdom
             LEFT JOIN ( SELECT ref_rank.id_taxa_obs,
                    ref_rank.scientific_name
                   FROM ref_rank
                  WHERE ref_rank.rank = 'species'::text) species USING (id_taxa_obs)
             LEFT JOIN ( SELECT ref_rank.id_taxa_obs,
                    ref_rank.scientific_name
                   FROM ref_rank
                  WHERE ref_rank.rank = 'genus'::text) genus USING (id_taxa_obs)
             LEFT JOIN ( SELECT ref_rank.id_taxa_obs,
                    ref_rank.scientific_name
                   FROM ref_rank
                  WHERE ref_rank.rank = 'family'::text) family USING (id_taxa_obs)
             LEFT JOIN ( SELECT ref_rank.id_taxa_obs,
                    ref_rank.scientific_name
                   FROM ref_rank
                  WHERE ref_rank.rank = 'order'::text) "order" USING (id_taxa_obs)
             LEFT JOIN ( SELECT ref_rank.id_taxa_obs,
                    ref_rank.scientific_name
                   FROM ref_rank
                  WHERE ref_rank.rank = 'class'::text) class USING (id_taxa_obs)
             LEFT JOIN ( SELECT ref_rank.id_taxa_obs,
                    ref_rank.scientific_name
                   FROM ref_rank
                  WHERE ref_rank.rank = 'phylum'::text) phylum USING (id_taxa_obs)
    )					
 SELECT best_ref.id_taxa_obs,
    taxa_obs.scientific_name AS observed_scientific_name,
    best_ref.valid_scientific_name,
    best_ref.rank,
    best_vernacular.vernacular_en,
    best_vernacular.vernacular_fr,
    obs_group.group_en,
    obs_group.group_fr,
    vernacular_group.vernacular,
    agg_ref.source_references,
    full_taxonomy.kingdom,
    full_taxonomy.phylum,
    full_taxonomy.class,
    full_taxonomy."order",
    full_taxonomy.family,
    full_taxonomy.genus,
    full_taxonomy.species
   FROM best_ref
     LEFT JOIN taxa_obs ON taxa_obs.id = best_ref.id_taxa_obs
     LEFT JOIN vernacular_group ON best_ref.id_taxa_obs = vernacular_group.id_taxa_obs
     LEFT JOIN obs_group ON best_ref.id_taxa_obs = obs_group.id_taxa_obs
     LEFT JOIN best_vernacular ON best_ref.id_taxa_obs = best_vernacular.id_taxa_obs
     LEFT JOIN agg_ref ON best_ref.id_taxa_obs = agg_ref.id_taxa_obs
     LEFT JOIN full_taxonomy ON best_ref.id_taxa_obs = full_taxonomy.id_taxa_obs
  ORDER BY best_ref.id_taxa_obs, best_vernacular.vernacular_en;


-- ALTER permissions
ALTER TABLE api.taxa OWNER TO postgres;

REVOKE ALL ON TABLE api.taxa FROM coleo_test_user;
REVOKE ALL ON TABLE api.taxa FROM read_only_all;
REVOKE ALL ON TABLE api.taxa FROM read_only_public;
REVOKE ALL ON TABLE api.taxa FROM read_write_all;

GRANT SELECT ON TABLE api.taxa TO coleo_test_user;
GRANT ALL ON TABLE api.taxa TO postgres;
GRANT SELECT ON TABLE api.taxa TO read_only_all;
GRANT SELECT ON TABLE api.taxa TO read_only_public;
GRANT INSERT, TRUNCATE, REFERENCES, TRIGGER, UPDATE, SELECT ON TABLE api.taxa TO read_write_all;


------------------------------------------------------------------------
-- 3. Add indexes
------------------------------------------------------------------------

CREATE INDEX taxa_obs_id_taxa_obs_idx ON api.taxa (id_taxa_obs);
CREATE INDEX taxa_obs_valid_scientific_name_idx ON api.taxa (valid_scientific_name);


-- Test
-- SELECT * FROM api.taxa WHERE id_taxa_obs in (select id from taxa_obs limit 10);

------------------------------------------------------------------------
-- 4. Re-create the objects that depend on the new materialized view
--
-- match_taxa() function
-- api.match_taxa() function
-- api.taxa_surveyed view
-- indicators.pheno_acoustique view
-- api.pheno_acoustique view
------------------------------------------------------------------------

-- match_taxa() function
CREATE FUNCTION public.match_taxa(
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

ALTER FUNCTION public.match_taxa(text)
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.match_taxa(text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.match_taxa(text) TO coleo_test_user;
GRANT EXECUTE ON FUNCTION public.match_taxa(text) TO read_write_all;
GRANT EXECUTE ON FUNCTION public.match_taxa(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.match_taxa(text) TO vbeaure;
GRANT EXECUTE ON FUNCTION public.match_taxa(text) TO glaroc;

-- api.match_taxa() function
CREATE FUNCTION api.match_taxa(
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

ALTER FUNCTION api.match_taxa(text)
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION api.match_taxa(text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION api.match_taxa(text) TO coleo_test_user;
GRANT EXECUTE ON FUNCTION api.match_taxa(text) TO read_write_all;
GRANT EXECUTE ON FUNCTION api.match_taxa(text) TO postgres;
GRANT EXECUTE ON FUNCTION api.match_taxa(text) TO vbeaure;
GRANT EXECUTE ON FUNCTION api.match_taxa(text) TO glaroc;

-- api.taxa_surveyed view
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

ALTER TABLE api.taxa_surveyed OWNER TO postgres;

GRANT SELECT ON TABLE api.taxa_surveyed TO coleo_test_user;
GRANT SELECT ON TABLE api.taxa_surveyed TO read_write_all;
GRANT SELECT ON TABLE api.taxa_surveyed TO read_only_all;
GRANT ALL ON TABLE api.taxa_surveyed TO postgres;
GRANT ALL ON TABLE api.taxa_surveyed TO glaroc;
GRANT ALL ON TABLE api.taxa_surveyed TO vbeaure;

-- indicators.pheno_acoustique view
-- DROP VIEW indicators.pheno_acoustique;
CREATE VIEW indicators.pheno_acoustique AS
 WITH results AS (
         SELECT s.id AS site_id,
            c.type AS campaign_type,
            taxa.valid_scientific_name AS valid_name,
            taxa.vernacular_fr AS taxa_name,
            taxa.vernacular_en AS taxa_name_en,
            date_part('year'::text, o.date_obs) AS year,
            o.date_obs,
            os.id_taxa_obs,
            public.st_y(s.geom) AS site_lat
           FROM ((((public.observations o
             LEFT JOIN public.obs_species os ON ((o.id = os.observation_id)))
             LEFT JOIN public.campaigns c ON ((o.campaign_id = c.id)))
             LEFT JOIN public.sites s ON ((c.site_id = s.id)))
             LEFT JOIN api.taxa ON ((os.id_taxa_obs = taxa.id_taxa_obs)))
          WHERE ((os.taxa_name IS NOT NULL) AND (c.type = ANY (ARRAY['acoustique_chiroptères'::public.enum_campaigns_type, 'acoustique_orthoptères'::public.enum_campaigns_type, 'acoustique_oiseaux'::public.enum_campaigns_type, 'acoustique_anoures'::public.enum_campaigns_type])))
          ORDER BY s.id, taxa.valid_scientific_name
        ), sites AS (
         SELECT results_1.site_id,
            array_agg(results_1.id_taxa_obs) AS id_taxa_obs
           FROM results results_1
          GROUP BY results_1.site_id
        ), tips AS (
         SELECT sites.site_id,
            api.taxa_branch_tips(sites.id_taxa_obs) AS id_taxa_obs
           FROM sites
        )
 SELECT tips.site_id,
    results.campaign_type,
    results.taxa_name,
    results.year,
    results.date_obs,
    results.valid_name,
    results.taxa_name_en,
    results.site_lat
   FROM results,
    tips
  WHERE ((results.id_taxa_obs = tips.id_taxa_obs) AND (results.site_id = tips.site_id))
  ORDER BY tips.site_id, results.year, results.taxa_name;

ALTER TABLE indicators.pheno_acoustique OWNER TO postgres;

-- api.pheno_acoustique view
CREATE OR REPLACE VIEW api.pheno_acoustique
 AS
 SELECT pheno_acoustique.site_id,
    pheno_acoustique.campaign_type,
    pheno_acoustique.taxa_name,
    pheno_acoustique.year,
    pheno_acoustique.date_obs,
    pheno_acoustique.valid_name,
    pheno_acoustique.taxa_name_en,
    pheno_acoustique.site_lat
   FROM indicators.pheno_acoustique;

ALTER TABLE api.pheno_acoustique
    OWNER TO postgres;

GRANT SELECT ON TABLE api.pheno_acoustique TO coleo_test_user;
GRANT ALL ON TABLE api.pheno_acoustique TO glaroc;
GRANT ALL ON TABLE api.pheno_acoustique TO postgres;
GRANT SELECT ON TABLE api.pheno_acoustique TO read_only_all;
GRANT SELECT ON TABLE api.pheno_acoustique TO read_only_public;
GRANT SELECT ON TABLE api.pheno_acoustique TO read_write_all;


------------------------------------------------------------------------
-- 5. Add cronjobs to REFRESH the new materialized view
--
-- NOTE: The adopted strategy is to refresh the materialized view
--       every day. A complete refresh is done as the materialized
--       view is not that big.
-- Note: The cronjob is added to the postgres user's crontab
------------------------------------------------------------------------

REFRESH MATERIALIZED VIEW api.taxa;
