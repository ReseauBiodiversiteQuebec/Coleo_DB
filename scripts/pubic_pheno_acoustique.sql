-------------------------------------------------------------------------------
-- VIEW api.pheno_acoustique
-- DESCRIPTION reachable endpoint for pheno_acoustique by the web portal
-------------------------------------------------------------------------------

-- CREATE VIEW TO COMPUTE ACOUSTIQUE PHENOLOGY INDICATOR
-- from: indicators.pheno_acoustique

-- DROP VIEW api.pheno_acoustique;

CREATE OR REPLACE VIEW api.pheno_acoustique
 AS
 SELECT pheno_acoustique.site_id,
    pheno_acoustique.campaign_type,
    pheno_acoustique.taxa_name,
    pheno_acoustique.year,
    pheno_acoustique.date_obs,
    pheno_acoustique.valid_name,
    pheno_acoustique.taxa_name_en,
    pheno_acoustique.site_lat
   FROM indicators.pheno_acoustique;

ALTER TABLE api.pheno_acoustique
    OWNER TO postgres;

GRANT SELECT ON TABLE api.pheno_acoustique TO coleo_test_user;
GRANT ALL ON TABLE api.pheno_acoustique TO glaroc;
GRANT ALL ON TABLE api.pheno_acoustique TO postgres;
GRANT SELECT ON TABLE api.pheno_acoustique TO read_only_all;
GRANT SELECT ON TABLE api.pheno_acoustique TO read_only_public;
GRANT SELECT ON TABLE api.pheno_acoustique TO read_write_all;