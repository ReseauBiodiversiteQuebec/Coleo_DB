--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- This script migrates the api.taxa VIEW to a MATERIALIZED VIEW
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

------------------------------------------------------------------------
-- 1. DROP the old view
------------------------------------------------------------------------

DROP VIEW IF EXISTS api.taxa;


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
            all_ref.rank
        FROM all_ref
            JOIN taxa_source_priority USING (source_name)
        ORDER BY all_ref.id_taxa_obs, taxa_source_priority.priority
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
    ), ref_rank AS (
        SELECT DISTINCT ON (lu.id_taxa_obs, taxa_ref.rank) lu.id_taxa_obs,
            taxa_ref.scientific_name,
            taxa_ref.rank
        FROM taxa_obs taxa_obs_1,
            taxa_ref,
            taxa_obs_ref_lookup lu,
            taxa_ref_sources
        WHERE lu.id_taxa_obs = taxa_obs_1.id AND taxa_ref.id = lu.id_taxa_ref_valid AND taxa_ref.source_id = taxa_ref_sources.source_id::numeric
        ORDER BY lu.id_taxa_obs, taxa_ref.rank, taxa_ref_sources.source_priority
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
-- 3. Add cronjobs to REFRESH the new materialized view
--
-- NOTE: The adopted strategy is to refresh the materialized view
--       every day. A complete refresh is done as the materialized
--       view is not that big.
-- Note: The cronjob is added to the postgres user's crontab
------------------------------------------------------------------------

REFRESH MATERIALIZED VIEW api.taxa;