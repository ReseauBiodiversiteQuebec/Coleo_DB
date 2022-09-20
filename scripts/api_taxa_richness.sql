-- CREATE FUNCTION taxa_branch_tips that takes a list of id_taxa_obs values and
-- returns the number of unique taxa observed based on the tip-of-the-branch method

-- This function is used by the api.taxa_richness function to compute the number of
-- unique taxa observed based on the tip-of-the-branch method

CREATE OR REPLACE FUNCTION api.taxa_branch_tips (
    taxa_obs_ids integer[]
) RETURNS table (id_taxa_obs integer) AS $$
    WITH sum_filterid_ref AS (
        select
            min(id_taxa_obs) id_taxa_obs,
            id_taxa_ref_filterid id_taxa_ref,
            count(id_taxa_ref_filterid) count_taxa_ref,
            min(match_type) match_type
        from taxa_obs_ref_lookup obs_lookup
        WHERE (match_type != 'complex' or match_type is null)
            AND obs_lookup.id_taxa_obs = any(taxa_obs_ids)
        group by id_taxa_ref_filterid
    )
    select
        distinct(sum_filterid_ref.id_taxa_obs) id_taxa_obs
    from sum_filterid_ref
    where count_taxa_ref = 1
        and match_type is not null
$$ LANGUAGE sql;

SELECT api.taxa_branch_tips(ARRAY[6489, 5888, 6514]);

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

CREATE OR REPLACE FUNCTION api.taxa_richness (
    group_by_column text DEFAULT NULL,
    cell_id_filter integer DEFAULT NULL,
    cell_code_filter text DEFAULT NULL,
    site_id_filter integer DEFAULT NULL,
    site_code_filter text DEFAULT NULL,
    site_type_filter text DEFAULT NULL,
    campaign_id_filter integer DEFAULT NULL,
    campaign_type_filter text DEFAULT NULL
)
RETURNS TABLE (
    grouped_by_value text,
    richness integer
) AS
$$

-- Build the query to select the `group_by_column` and count the number of observations
DECLARE
    richness_query text;
BEGIN
    richness_query := '
        with joined_obs AS (
            SELECT
                obs_species.id,
                obs_species.id_taxa_obs,
                obs_species.value,
                observations.campaign_id,
                campaigns.site_id,
                campaigns.type as campaign_type,
                sites.cell_id,
                cells.cell_code,
                sites.site_code,
                sites.type as site_type
            FROM obs_species
            JOIN observations ON obs_species.observation_id = observations.id
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
                    api.taxa_branch_tips(array_agg(joined_obs.id_taxa_obs)) AS richness
                FROM joined_obs
                WHERE ' || quote_ident(group_by_column) || ' IS NOT NULL
                GROUP BY ' || quote_ident(group_by_column) || '
                ORDER BY richness DESC)
            SELECT grouped_by_value, count(*)::int AS richness
            FROM taxa_tips
            GROUP BY grouped_by_value;
        ';
    ELSE 
        richness_query := richness_query || '
            , taxa_tips as (
                SELECT ''all'' AS grouped_by_value,
                    api.taxa_branch_tips(array_agg(joined_obs.id_taxa_obs)) AS richness
                FROM joined_obs
                GROUP BY TRUE
                ORDER BY richness DESC)
            SELECT grouped_by_value, count(*)::int AS richness
            FROM taxa_tips
            GROUP BY grouped_by_value;
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
$$
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