-- CREATE FUNCTION api.taxa_top_obs
-- DESCRIPTION: 'Top taxa observed for a cell_id, cell_code, site_id, site_code, site_type
-- Returns api.taxa columns with `abundance` and `observed_percent` columns

DROP FUNCTION IF EXISTS api.taxa_abundance (
    text,
    integer,
    text,
    integer,
    text,
    text,
    integer,
    text
);

-- CREATE FUNCTION api.taxa_abundance that takes with NULL default argument
CREATE OR REPLACE FUNCTION api.taxa_abundance (
    group_by_column text DEFAULT '',
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
    abundance numeric,
    relative_abundance numeric,
    id_taxa_obs integer,
    observed_scientific_name text,
    valid_scientific_name text,
    rank text,
    vernacular_en text,
    vernacular_fr text,
    group_en text,
    group_fr text
) AS
$$
-- Build the query to select the `group_by_column` and count the number of observations
DECLARE
    abundance_query text;
BEGIN
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
        abundance_query := abundance_query || '
        , group_total_abundances AS (
            SELECT ' || quote_ident(group_by_column) || '::text AS grouped_by_value,
                sum(joined_obs.value) total_abundance
            FROM joined_obs
            GROUP BY ' || quote_ident(group_by_column) || '
        ), group_abundance AS (
            SELECT ' || quote_ident(group_by_column) || '::text AS grouped_by_value,
                joined_obs.id_taxa_obs,
                sum(joined_obs.value) AS abundance
            FROM joined_obs
            WHERE ' || quote_ident(group_by_column) || ' IS NOT NULL
            GROUP BY joined_obs.id_taxa_obs, ' || quote_ident(group_by_column) || '
            ORDER BY abundance DESC)';
    ELSE
        abundance_query := abundance_query || '
        , group_total_abundances AS (
            SELECT ''all'' AS grouped_by_value,
                sum(joined_obs.value) total_abundance
            FROM joined_obs
            GROUP BY TRUE
        ), group_abundance AS (
            SELECT ''all''  AS grouped_by_value,
                joined_obs.id_taxa_obs,
                sum(joined_obs.value) AS abundance
            FROM joined_obs
            GROUP BY joined_obs.id_taxa_obs
            ORDER BY abundance DESC)';
    END IF;

    abundance_query := abundance_query || '
        , filter_obs_species AS (
            SELECT
                group_abundance.grouped_by_value,
                group_abundance.id_taxa_obs,
                group_abundance.abundance,
                group_abundance.abundance / group_total_abundances.total_abundance as relative_abundance
            FROM group_abundance
            JOIN group_total_abundances USING (grouped_by_value)
        )
        SELECT
            filter_obs_species.grouped_by_value,
            filter_obs_species.abundance::numeric,
            filter_obs_species.relative_abundance::numeric,
            filter_obs_species.id_taxa_obs,
            taxa.observed_scientific_name,
            taxa.valid_scientific_name,
            taxa.rank,
            taxa.vernacular_en,
            taxa.vernacular_fr,
            taxa.group_en,
            taxa.group_fr
        FROM filter_obs_species
        JOIN api.taxa USING (id_taxa_obs)
        ORDER BY filter_obs_species.grouped_by_value, filter_obs_species.abundance DESC;
        ';

    -- Execute the query
    RETURN QUERY EXECUTE abundance_query
        USING group_by_column,
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
ALTER FUNCTION api.taxa_abundance(text) OWNER TO postgres;

-- Test the function
EXPLAIN ANALYZE SELECT * FROM api.taxa_abundance('site_code', NULL , NULL , NULL , NULL , NULL , NULL , NULL );

-- Test the function
EXPLAIN ANALYZE SELECT * FROM api.taxa_abundance('site_type', NULL , NULL , NULL , NULL , NULL , NULL , NULL );

-- Test the function
EXPLAIN ANALYZE SELECT * FROM api.taxa_abundance('campaign_type', NULL , NULL , 7 , NULL , NULL , NULL , NULL );

-- Test the function when when no group_by column is specified
EXPLAIN ANALYZE SELECT * FROM api.taxa_abundance(NULL, NULL , NULL , NULL , NULL , NULL , NULL , NULL );

-- Test the function when when no group_by column is specified
EXPLAIN ANALYZE SELECT * FROM api.taxa_abundance(NULL, NULL , NULL , 7 , NULL , NULL , NULL , NULL );