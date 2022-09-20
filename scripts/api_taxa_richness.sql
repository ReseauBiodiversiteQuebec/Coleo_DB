-- CREATE FUNCTION taxa_branch_tips that takes a list of id_taxa_obs values and
-- returns the number of unique taxa observed based on the tip-of-the-branch method

-- This function is used by the api.taxa_richness function to compute the number of
-- unique taxa observed based on the tip-of-the-branch method

CREATE OR REPLACE FUNCTION api.taxa_branch_tips (
    taxa_obs_ids integer[]
) RETURNS table (id_taxa_obs integer) AS $$
    WITH sum_valid_ref AS (
        select
            min(id_taxa_obs) id_taxa_obs,
            id_taxa_ref_valid id_taxa_ref,
            count(id_taxa_ref_valid) count_taxa_ref,
            min(match_type) match_type
        from taxa_obs_ref_lookup obs_lookup
        WHERE (match_type != 'complex' or match_type is null)
            AND obs_lookup.id_taxa_obs = any(taxa_obs_ids)
        group by id_taxa_ref_valid
    )
    select
        distinct(sum_valid_ref.id_taxa_obs) id_taxa_obs
    from sum_valid_ref
    where count_taxa_ref = 1
        and match_type is not null
$$ LANGUAGE sql;

SELECT api.taxa_branch_tips(ARRAY[6489, 5888, 6514]);

-- CREATE FUNCTION api.taxa_richness that returns a table with the number of unique taxa observed
-- based on the tip-of-the-branch method

DROP FUNCTION IF EXISTS api.taxa_richness (text);

CREATE OR REPLACE FUNCTION api.taxa_richness (
    group_by_column text DEFAULT ''
)
RETURNS TABLE (
    group_by_value text,
    richness integer
) AS
$$

-- Build the query to select the `group_by_column` and count the number of observations
DECLARE
    abundance_query text;
BEGIN
    -- Return an error if the group_by_column is not one of the allowed values
    IF group_by_column NOT IN ('cell_id', 'cell_code', 'site_id', 'site_code', 'site_type', 'campaign_id', 'campaign_type') THEN
        RAISE EXCEPTION 'group_by_column must be one of cell_id, cell_code, site_id, site_code, site_type, campaign_id, campaign_type';
    END IF;

    abundance_query := '
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
        ), taxa_tips as (
            SELECT ' || quote_ident(group_by_column) || '::text AS group_by_value,
                api.taxa_branch_tips(array_agg(joined_obs.id_taxa_obs)) AS richness
            FROM joined_obs
            WHERE ' || quote_ident(group_by_column) || ' IS NOT NULL
            GROUP BY ' || quote_ident(group_by_column) || '
            ORDER BY richness DESC)
        SELECT group_by_value, count(*)::int AS richness
        FROM taxa_tips
        GROUP BY group_by_value;
    ';

    -- Execute the query
    RETURN QUERY EXECUTE abundance_query;
END;
$$
LANGUAGE plpgsql stable;

-- Test the function
EXPLAIN ANALYZE SELECT * FROM api.taxa_richness('site_code');

-- Test the function
EXPLAIN ANALYZE SELECT * FROM api.taxa_richness('site_type');

-- Test the function
EXPLAIN ANALYZE SELECT * FROM api.taxa_richness('cell_code');

-- Test the function
EXPLAIN ANALYZE SELECT * FROM api.taxa_richness('cell_id');
