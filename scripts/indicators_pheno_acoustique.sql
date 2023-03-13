CREATE SCHEMA IF NOT EXISTS indicators;

-------------------------------------------------------------------------------
-- VIEW indicators.pheno_acoustique
-- DESCRIPTION List of arrival and departure dates for each taxa in each site per year
-------------------------------------------------------------------------------

-- CREATE VIEW TO COMPUTE ACOUSTIQUE PHENOLOGY INDICATOR
CREATE OR REPLACE VIEW indicators.pheno_acoustique AS (
    with results as (
        SELECT site_code, c.type as campaign_type, valid_scientific_name as taxa_name, 
            EXTRACT(year FROM date_obs) as year, MIN(date_obs) as min_date, 
            MAX(date_obs) as max_date,
            os.id_taxa_obs
        FROM observations o
            LEFT JOIN obs_species os ON(o.id=os.observation_id) 
            LEFT JOIN campaigns c ON (o.campaign_id=c.id) 
            LEFT JOIN sites s ON (c.site_id=s.id) 
            LEFT JOIN api.taxa ON os.id_taxa_obs=api.taxa.id_taxa_obs
        WHERE taxa_name IS NOT NULL 
            AND c.type IN ('acoustique_chiroptères', 'acoustique_orthoptères', 'acoustique_oiseaux', 'acoustique_anoures')
        GROUP BY s.site_code, c.type, valid_scientific_name, EXTRACT(year FROM date_obs), os.id_taxa_obs
        ORDER BY site_code, valid_scientific_name
    ), tips as (
        select api.taxa_branch_tips(array_agg(id_taxa_obs)) id_taxa_obs
        from results
    )
    select site_code, campaign_type, taxa_name, year, min_date, max_date
    from results, tips
    where results.id_taxa_obs = tips.id_taxa_obs
    ORDER BY site_code, taxa_name
);
