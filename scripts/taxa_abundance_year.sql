CREATE OR REPLACE FUNCTION api.taxa_abundance_year(group_by_column text DEFAULT ''::text, cell_id_filter integer DEFAULT NULL::integer, cell_code_filter text DEFAULT NULL::text, site_id_filter integer DEFAULT NULL::integer, site_code_filter text DEFAULT NULL::text, site_type_filter text DEFAULT NULL::text, campaign_id_filter integer DEFAULT NULL::integer, campaign_type_filter text DEFAULT NULL::text)
 RETURNS TABLE(grouped_by_value text, campaign_year int, abundance numeric, relative_abundance numeric, valid_scientific_name text, rank text, vernacular_en text, vernacular_fr text, group_en text, group_fr text)
 LANGUAGE plpgsql
 STABLE
AS $function$
-- Build the query to select the `group_by_column` and count the number of observations
DECLARE
    abundance_query text;
BEGIN
    -- RAISE AN EXCEPTION IF group_by_column IS NOT NULL AND IS NOT IN THE ALLOWED VALUES
    IF group_by_column IS NOT NULL AND group_by_column NOT IN ('cell_id', 'cell_code', 'site_id', 'site_code', 'site_type', 'campaign_id', 'campaign_type') THEN
        RAISE EXCEPTION 'group_by_column must be NULL or one of the following values: cell_id, cell_code, site_id, site_code, site_type, campaign_id, campaign_type';
    END IF;

    abundance_query := '
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
				EXTRACT(YEAR FROM campaigns.opened_at)::int as campaign_year,
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
        abundance_query := abundance_query || '
        , group_total_abundances AS (
            SELECT ' || quote_ident(group_by_column) || '::text AS grouped_by_value,
				joined_obs.campaign_year,
                sum(joined_obs.value) total_abundance 
            FROM joined_obs
            GROUP BY ' || quote_ident(group_by_column) || ', joined_obs.campaign_year
        ), group_abundance AS (
            SELECT ' || quote_ident(group_by_column) || '::text AS grouped_by_value,
				joined_obs.campaign_year,
                joined_obs.id_taxa_obs,
                sum(joined_obs.value) AS abundance,
            FROM joined_obs
            WHERE ' || quote_ident(group_by_column) || ' IS NOT NULL
            GROUP BY joined_obs.id_taxa_obs, ' || quote_ident(group_by_column) || ', 
			joined_obs.campaign_year
            ORDER BY abundance DESC)';
    ELSE
        abundance_query := abundance_query || '
        , group_total_abundances AS (
            SELECT ''all'' AS grouped_by_value,
				joined_obs.campaign_year.
                sum(joined_obs.value) total_abundance
            FROM joined_obs
            GROUP BY TRUE
        ), group_abundance AS (
            SELECT ''all''  AS grouped_by_value,
				joined_obs.campaign_year,
                joined_obs.id_taxa_obs,
                sum(joined_obs.value) AS abundance
            FROM joined_obs
            GROUP BY joined_obs.id_taxa_obs, joined_obs.campaign_year
            ORDER BY abundance DESC)';
    END IF;

    abundance_query := abundance_query || '
        , filter_obs_species AS (
            SELECT
                min(group_abundance.grouped_by_value) as grouped_by_value,
				group_abundance.campaign_year,
                taxa.valid_scientific_name,
                sum(group_abundance.abundance) as abundance,
                sum(group_abundance.abundance) / sum(group_total_abundances.total_abundance) as relative_abundance
            FROM group_abundance
            JOIN group_total_abundances USING (grouped_by_value)
            JOIN api.taxa USING (id_taxa_obs)
            GROUP BY taxa.valid_scientific_name, group_abundance.campaign_year)
        , results AS (
            SELECT
                distinct on (filter_obs_species.grouped_by_value, filter_obs_species.valid_scientific_name)
                filter_obs_species.grouped_by_value,
				filter_obs_species.campaign_year,
                filter_obs_species.abundance::numeric,
                filter_obs_species.relative_abundance::numeric,
                taxa.valid_scientific_name,
                taxa.rank,
                taxa.vernacular_en,
                taxa.vernacular_fr,
                taxa.group_en,
                taxa.group_fr
            FROM filter_obs_species
            LEFT JOIN api.taxa USING (valid_scientific_name))
        SELECT * FROM results ORDER BY grouped_by_value, campaign_year, abundance DESC;';


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
$function$
;
;
