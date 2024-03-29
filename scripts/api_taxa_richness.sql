-- CREATE FUNCTION taxa_branch_tips that takes a list of id_taxa_obs values and
-- returns the number of unique taxa observed based on the tip-of-the-branch method

-- This function is used by the api.taxa_richness function to compute the number of
-- unique taxa observed based on the tip-of-the-branch method

CREATE OR REPLACE FUNCTION api.taxa_branch_tips (
    taxa_obs_ids integer[]
) RETURNS table (id_taxa_obs integer) AS $$
    WITH ref_tips AS (
		select
			id_taxa_ref_valid,
			bool_and( coalesce(match_type = 'complex_closest_parent' or is_parent is false, false)) is_tip,
			array_agg(distinct(id_taxa_obs)) id_taxa_obs,
			count(id_taxa_ref_valid) count_taxa_ref
		from taxa_obs_ref_lookup obs_lookup
		WHERE obs_lookup.id_taxa_obs = any(taxa_obs_ids)
			and (match_type != 'complex' or match_type is null)
		group by id_taxa_ref_valid)
		select distinct(unnest(id_taxa_obs)) id
		from ref_tips
		where is_tip is true

$$ LANGUAGE sql;

SELECT api.taxa_branch_tips(ARRAY[6065, 6007, 6636, 6619]);

-- This function is used by the api.taxa_richness function to compute the number of
-- unique taxa observed for edna surveys
CREATE OR REPLACE VIEW obs_edna_likely as
SELECT obs_edna.*
FROM campaigns, observations, obs_edna
WHERE campaigns.type = 'ADNe'
	AND observations.campaign_id = campaigns.id
	AND obs_edna.observation_id = observations.id
	AND trim(replace(extra::text, '\"', '"'), '"')::jsonb -> 'échelle_spatiale' ->> 'value' = 'lac'
    AND obs_edna.type_edna IN ('confirmé');

-- CREATE FUNCTION api.taxa_richness that returns a table with the number of unique taxa observed
-- based on the tip-of-the-branch method

DROP FUNCTION IF EXISTS api.taxa_richness (
    text,
    integer,
    text,
    integer,
    text,
    text,
    integer,
    text
);

CREATE OR REPLACE FUNCTION api.taxa_richness(
	group_by_column text DEFAULT NULL::text,
	cell_id_filter integer DEFAULT NULL::integer,
	cell_code_filter text DEFAULT NULL::text,
	site_id_filter integer DEFAULT NULL::integer,
	site_code_filter text DEFAULT NULL::text,
	site_type_filter text DEFAULT NULL::text,
	campaign_id_filter integer DEFAULT NULL::integer,
	campaign_type_filter text DEFAULT NULL::text)
    RETURNS TABLE(grouped_by_value text, richness integer, taxa_list json) 
    LANGUAGE 'plpgsql'
    COST 100
    STABLE PARALLEL UNSAFE
    ROWS 1000

AS $BODY$

-- Build the query to select the `group_by_column` and count the number of observations
DECLARE
    richness_query text;
BEGIN
    -- RAISE AN EXCEPTION IF group_by_column IS NOT NULL AND IS NOT IN THE ALLOWED VALUES
    IF group_by_column IS NOT NULL AND group_by_column NOT IN ('cell_id', 'cell_code', 'site_id', 'site_code', 'site_type', 'campaign_id', 'campaign_type') THEN
        RAISE EXCEPTION 'group_by_column must be NULL or one of the following values: cell_id, cell_code, site_id, site_code, site_type, campaign_id, campaign_type';
    END IF;

    richness_query := '
        with obs_taxa as (
            SELECT id_taxa_obs, value, observation_id
                FROM obs_species
                WHERE id_taxa_obs IS NOT NULL
            UNION
            SELECT id_taxa_obs, sequence_count as value, observation_id
                FROM obs_edna_likely
                WHERE id_taxa_obs IS NOT NULL
        ), joined_obs AS (
            SELECT
                obs_taxa.id_taxa_obs,
                obs_taxa.value,
                observations.campaign_id,
                campaigns.site_id,
                campaigns.type as campaign_type,
                sites.cell_id,
                cells.cell_code,
                sites.site_code,
                sites.type as site_type
            FROM obs_taxa
            JOIN observations ON obs_taxa.observation_id = observations.id
            JOIN campaigns ON observations.campaign_id = campaigns.id
            JOIN sites ON campaigns.site_id = sites.id
            JOIN cells ON sites.cell_id = cells.id
            WHERE
                coalesce(cells.id = $2, true)
                AND coalesce(cells.cell_code = $3, true)
                AND coalesce(sites.id = $4, true)
                AND coalesce(sites.site_code = $5, true)
                AND coalesce(sites.type::text = $6, true)
                AND coalesce(campaigns.id = $7, true)
                AND coalesce(campaigns.type::text = $8, true)
        )';

    IF group_by_column IN ('cell_id', 'cell_code', 'site_id', 'site_code', 'site_type', 'campaign_id', 'campaign_type') THEN
        richness_query := richness_query || '
            , taxa_tips as (
                SELECT ' || quote_ident(group_by_column) || '::text AS grouped_by_value,
                    api.taxa_branch_tips(array_agg(joined_obs.id_taxa_obs)) AS id_taxa_obs
                FROM joined_obs
                WHERE ' || quote_ident(group_by_column) || ' IS NOT NULL
                GROUP BY ' || quote_ident(group_by_column) || '
                )
            SELECT
                grouped_by_value::text,
                count(taxa_tips.id_taxa_obs)::integer AS richness,
                json_agg(row_to_json(taxa))::json AS taxa_list
            FROM taxa_tips, (
                SELECT
                    id_taxa_obs,
                    valid_scientific_name,
                    vernacular_en,
                    vernacular_fr,
                    group_fr,
                    group_en,
					kingdom,
            		phylum,
					class,
            		"order",
            		family,
            		genus,
            		species
                FROM api.taxa) taxa
            WHERE taxa.id_taxa_obs = taxa_tips.id_taxa_obs
            GROUP BY grouped_by_value
        ';
    ELSE 
        richness_query := richness_query || '
            , taxa_tips as (
                SELECT ''all'' AS grouped_by_value,
                    api.taxa_branch_tips(array_agg(joined_obs.id_taxa_obs)) AS id_taxa_obs
                FROM joined_obs
                GROUP BY TRUE)
            SELECT
                grouped_by_value::text,
                count(taxa_tips.id_taxa_obs)::integer AS richness,
                json_agg(row_to_json(taxa))::json AS taxa_list
            FROM taxa_tips, (
                SELECT
                    id_taxa_obs,
                    valid_scientific_name,
                    vernacular_en,
                    vernacular_fr,
                    group_fr,
                    group_en,
					kingdom,
            		phylum,
					class,
            		"order",
            		family,
            		genus,
            		species
                FROM api.taxa) taxa
            WHERE taxa.id_taxa_obs = taxa_tips.id_taxa_obs
            GROUP BY grouped_by_value
        ';
    END IF;

    -- Execute the query
    RETURN QUERY EXECUTE richness_query
    USING 
        group_by_column,
        cell_id_filter,
        cell_code_filter,
        site_id_filter,
        site_code_filter,
        site_type_filter,
        campaign_id_filter,
        campaign_type_filter;
END;
$BODY$;
LANGUAGE plpgsql stable;

-- ALTER FUNCTION OWNER TO postgres;
ALTER FUNCTION api.taxa_richness(text, integer, text, integer, text, text, integer, text) OWNER TO postgres;

-- Test the function
EXPLAIN ANALYZE SELECT * FROM api.taxa_richness('site_code', NULL, NULL, NULL, NULL, NULL, NULL, NULL);

-- Test the function
EXPLAIN ANALYZE SELECT * FROM api.taxa_richness('site_type', NULL, NULL, NULL, NULL, NULL, NULL, NULL);

-- Test the function
EXPLAIN ANALYZE SELECT * FROM api.taxa_richness('cell_code', NULL, NULL, NULL, NULL, NULL, NULL, NULL);

-- Test the function group by campaign_type and filter by site_id = 7
-- taxa_richness( group_by_column text, cell_id_filter integer, cell_code_filter text, site_id_filter integer, site_code_filter text, site_type_filter text, campaign_id_filter integer, campaign_type_filter text)
EXPLAIN ANALYZE SELECT * FROM api.taxa_richness('campaign_type', NULL, NULL, 7, NULL, NULL, NULL, NULL);

-- Test the function when group_by is NULL

EXPLAIN ANALYZE SELECT * FROM api.taxa_richness(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);

EXPLAIN ANALYZE SELECT * FROM api.taxa_richness(NULL, NULL, NULL, 7, NULL, NULL, NULL, NULL);
