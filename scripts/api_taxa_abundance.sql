-- CREATE FUNCTION api.taxa_top_obs
-- DESCRIPTION: 'Top taxa observed for a cell_id, cell_code, site_id, site_code, site_type
-- Returns api.taxa columns with `abundance` and `observed_percent` columns

DROP FUNCTION IF EXISTS api.taxa_abundance (text);

-- CREATE FUNCTION api.taxa_abundance that takes with NULL default argument
CREATE OR REPLACE FUNCTION api.taxa_abundance (
    filter_column text DEFAULT ''
)
RETURNS TABLE (
    filter_value text,
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
-- Build the query to select the `filter_column` and count the number of observations
DECLARE
    abundance_query text;
BEGIN
    -- Return an error if the filter_column is not one of the allowed values
    IF filter_column NOT IN ('cell_id', 'cell_code', 'site_id', 'site_code', 'site_type', 'campaign_id', 'campaign_type') THEN
        RAISE EXCEPTION 'filter_column must be one of cell_id, cell_code, site_id, site_code, site_type, campaign_id, campaign_type';
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
        ), group_total_abundances AS (
            SELECT ' || quote_ident(filter_column) || '::text AS filter_value,
                sum(joined_obs.value) total_abundance
            FROM joined_obs
            GROUP BY ' || quote_ident(filter_column) || '
        ), group_abundance AS (
            SELECT ' || quote_ident(filter_column) || '::text AS filter_value,
                joined_obs.id_taxa_obs,
                sum(joined_obs.value) AS abundance
            FROM joined_obs
            WHERE ' || quote_ident(filter_column) || ' IS NOT NULL
            GROUP BY joined_obs.id_taxa_obs, ' || quote_ident(filter_column) || '
            ORDER BY abundance DESC
        ), filter_obs_species AS (
            SELECT
                group_abundance.filter_value,
                group_abundance.id_taxa_obs,
                group_abundance.abundance,
                group_abundance.abundance / group_total_abundances.total_abundance as relative_abundance
            FROM group_abundance
            JOIN group_total_abundances USING (filter_value)
        )
        SELECT
            filter_obs_species.filter_value,
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
        ORDER BY filter_obs_species.filter_value, filter_obs_species.abundance DESC;
        ';

    -- Execute the query
    RETURN QUERY EXECUTE abundance_query;
END;
$$
LANGUAGE plpgsql stable;

-- -- ALTER FUNCTION OWNER TO postgres;
-- ALTER FUNCTION api.taxa_abundance(text) OWNER TO postgres;

-- Test the function
EXPLAIN ANALYZE SELECT * FROM api.taxa_abundance('site_code');

-- Test the function
EXPLAIN ANALYZE SELECT * FROM api.taxa_abundance('site_type');

-- Test the function
EXPLAIN ANALYZE SELECT * FROM api.taxa_abundance('cell_code');

-- Test the function
EXPLAIN ANALYZE SELECT * FROM api.taxa_abundance('cell_id');