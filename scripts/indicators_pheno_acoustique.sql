CREATE SCHEMA IF NOT EXISTS indicators;

-------------------------------------------------------------------------------
-- VIEW indicators.pheno_acoustique
-- DESCRIPTION List of arrival and departure dates for each taxa in each site per year
-------------------------------------------------------------------------------

-- CREATE VIEW TO COMPUTE ACOUSTIQUE PHENOLOGY INDICATOR
CREATE OR REPLACE VIEW indicators.pheno_acoustique AS (
	with results as (
        SELECT s.id as site_id, c.type as campaign_type, valid_scientific_name as taxa_name, 
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
        GROUP BY s.id, c.type, valid_scientific_name, EXTRACT(year FROM date_obs), os.id_taxa_obs
        ORDER BY s.id, valid_scientific_name
    ), sites as (
		SELECT site_id, array_agg(id_taxa_obs) id_taxa_obs
		FROM results
		GROUP BY site_id
	),	tips as (
        SELECT site_id, api.taxa_branch_tips(id_taxa_obs) id_taxa_obs
			FROM sites
    )
	SELECT tips.site_id, campaign_type, taxa_name, year, min_date, max_date
    FROM results, tips
    WHERE results.id_taxa_obs = tips.id_taxa_obs
		AND results.site_id = tips.site_id
    ORDER BY site_id, year, taxa_name
);
