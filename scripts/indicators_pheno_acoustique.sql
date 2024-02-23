CREATE SCHEMA IF NOT EXISTS indicators;

-------------------------------------------------------------------------------
-- VIEW indicators.pheno_acoustique
-- DESCRIPTION List of arrival and departure dates for each taxa in each site per year
-------------------------------------------------------------------------------

-- CREATE VIEW TO COMPUTE ACOUSTIQUE PHENOLOGY INDICATOR
-- View: indicators.pheno_acoustique

-- DROP VIEW indicators.pheno_acoustique;

CREATE OR REPLACE VIEW indicators.pheno_acoustique AS
 WITH results AS (
         SELECT s.id AS site_id,
            c.type AS campaign_type,
            taxa.valid_scientific_name AS valid_name,
            CASE WHEN taxa.vernacular_fr IS NULL THEN taxa.valid_scientific_name ELSE taxa.vernacular_fr END as "taxa_name",
            CASE WHEN taxa.vernacular_en IS NULL THEN taxa.valid_scientific_name ELSE taxa.vernacular_en END as "taxa_name_en",
            date_part('year'::text, o.date_obs) AS year,
            o.date_obs,
            os.id_taxa_obs,
            public.st_y(s.geom) AS site_lat
           FROM ((((public.observations o
             LEFT JOIN public.obs_species os ON ((o.id = os.observation_id)))
             LEFT JOIN public.campaigns c ON ((o.campaign_id = c.id)))
             LEFT JOIN public.sites s ON ((c.site_id = s.id)))
             LEFT JOIN api.taxa ON ((os.id_taxa_obs = taxa.id_taxa_obs)))
          WHERE ((os.taxa_name IS NOT NULL) AND (c.type = ANY (ARRAY['acoustique_chiroptères'::public.enum_campaigns_type, 'acoustique_orthoptères'::public.enum_campaigns_type, 'acoustique_oiseaux'::public.enum_campaigns_type, 'acoustique_anoures'::public.enum_campaigns_type])))
          ORDER BY s.id, taxa.valid_scientific_name
        ), sites AS (
         SELECT results_1.site_id,
            array_agg(results_1.id_taxa_obs) AS id_taxa_obs
           FROM results results_1
          GROUP BY results_1.site_id
        ), tips AS (
         SELECT sites.site_id,
            api.taxa_branch_tips(sites.id_taxa_obs) AS id_taxa_obs
           FROM sites
        )
 SELECT tips.site_id,
    results.campaign_type,
    results.taxa_name,
    results.year,
    results.date_obs,
    results.valid_name,
    results.taxa_name_en,
    results.site_lat
   FROM results,
    tips
  WHERE ((results.id_taxa_obs = tips.id_taxa_obs) AND (results.site_id = tips.site_id))
  ORDER BY tips.site_id, results.year, results.taxa_name;

ALTER TABLE indicators.pheno_acoustique OWNER TO postgres;
