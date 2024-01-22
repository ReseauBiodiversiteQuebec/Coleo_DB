CREATE OR REPLACE FUNCTION api.taxa_richness_year(group_by_column text DEFAULT NULL::text, cell_id_filter integer DEFAULT NULL::integer, cell_code_filter text DEFAULT NULL::text, site_id_filter integer DEFAULT NULL::integer, site_code_filter text DEFAULT NULL::text, site_type_filter text DEFAULT NULL::text, campaign_id_filter integer DEFAULT NULL::integer, campaign_type_filter text DEFAULT NULL::text)
 RETURNS TABLE(grouped_by_value text, campaign_year integer, richness integer, taxa_list json)
 LANGUAGE plpgsql
 STABLE
AS $function$

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
				EXTRACT(YEAR FROM campaigns.opened_at)::int as campaign_year,
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
                    api.taxa_branch_tips(array_agg(joined_obs.id_taxa_obs)) AS id_taxa_obs,
				campaign_year
                FROM joined_obs
                WHERE ' || quote_ident(group_by_column) || ' IS NOT NULL
                GROUP BY ' || quote_ident(group_by_column) || ', campaign_year
                )
            SELECT
                grouped_by_value::text,
				taxa_tips.campaign_year,
                count(taxa_tips.id_taxa_obs)::integer AS richness,
                json_agg(row_to_json(taxa))::json AS taxa_list
            FROM taxa_tips, (
                SELECT
                    id_taxa_obs,
                    valid_scientific_name,
                    vernacular_en,
                    vernacular_fr,
                    group_fr,
                    group_en
                FROM api.taxa) taxa
            WHERE taxa.id_taxa_obs = taxa_tips.id_taxa_obs
            GROUP BY grouped_by_value, campaign_year
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
				taxa_tips.campaign_year,
                count(taxa_tips.id_taxa_obs)::integer AS richness,
                json_agg(row_to_json(taxa))::json AS taxa_list
            FROM taxa_tips, (
                SELECT
                    id_taxa_obs,
                    valid_scientific_name,
                    vernacular_en,
                    vernacular_fr,
                    group_fr,
                    group_en
                FROM api.taxa) taxa
            WHERE taxa.id_taxa_obs = taxa_tips.id_taxa_obs
            GROUP BY grouped_by_value, taxa_tips.campaign_year
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
$function$
;
