-------------------------------------------------------------------------------
-- VIEW api.gabarit_thermographe_long
-- DESCRIPTION Representation of the data for the thermographe campaigns
-------------------------------------------------------------------------------

-- CREATE VIEW FOR thermographe CAMPAIGN
-- View: api.gabarit_thermographe_long

-- DROP VIEW api.gabarit_thermographe_long;

-- CREATE OR REPLACE VIEW api.gabarit_thermographe_long AS (
--     select c.type campaigns_type,
--         s.site_code as sites_site_code,
--         l.type as landmarks_type,
--         st_y(l.geom) as landmarks_lat,
--         st_x(l.geom) as landmarks_lon,
--         c.opened_at as campaigns_opened_at,
--         c.closed_at as campaigns_closed_at,
--         c.notes as campaigns_notes,
--         t.thermograph_no as thermographs_thermograph_no,
--         t.depth as thermographs_depth,
--         t.height as thermographs_height,
--         t.is_on_bag as thermographs_is_on_bag,
--         t.shading as thermographs_shading,
--         t.notes as thermographs_notes,
--         ot.date_obs as obs_thermograph_date_obs,
--         ot.time_obs as obs_thermograph_time_obs,
--         ot.temperature as obs_thermograph_temperature,
--         ot.pressure as obs_thermograph_pressure
--     from campaigns c, sites s, obs_thermograph ot, landmarks l, thermographs t
--     where c.type = 'thermographe'
--         and s.id=c.site_id
--         and ot.campaign_id = c.id
-- 		and l.campaign_id=c.id
-- 		and t.landmark_id=l.id
--     order by (c.opened_at, s.site_code, c.technicians, c.notes)
-- );

-- GRANT SELECT ON TABLE api.gabarit_thermographe_long TO coleo_test_user;
-- GRANT ALL ON TABLE api.gabarit_thermographe_long TO glaroc;
-- GRANT ALL ON TABLE api.gabarit_thermographe_long TO postgres;
-- GRANT SELECT ON TABLE api.gabarit_thermographe_long TO read_only_all;
-- GRANT SELECT ON TABLE api.gabarit_thermographe_long TO read_only_public;
-- GRANT SELECT ON TABLE api.gabarit_thermographe_long TO read_write_all;


-------------------------------------------------------------------------------
-- VIEW api.gabarit_thermographe_short
-- DESCRIPTION Short representation of the data for the thermographe campaign
-------------------------------------------------------------------------------

-- CREATE VIEW FOR PAPILIONIDÉS CAMPAIGN
-- View: api.gabarit_thermographe_short

-- DROP VIEW api.gabarit_thermographe_short;

-- CREATE OR REPLACE VIEW api.gabarit_thermographe_short AS (
--     select COALESCE(cl.name, '') || CASE WHEN s.site_name IS NOT NULL THEN ' - ' || s.site_name ELSE '' END as "Nom du site",
--         s.type as "Type de site",
--         s.site_code as "Code du site",
--         c.opened_at as "Date de l'inventaire",
        
--     from campaigns c
--     left join sites s on s.id = c.site_id
--     left join cells cl on cl.id = s.cell_id
--     left join observations o on o.campaign_id = c.id
--     where c.type = 'thermographe'
--     order by 
--         c.opened_at ASC,
--         s.site_code,
--         os.bag_no
-- );

-- GRANT SELECT ON TABLE api.gabarit_thermographe_short TO coleo_test_user;
-- GRANT ALL ON TABLE api.gabarit_thermographe_short TO glaroc;
-- GRANT ALL ON TABLE api.gabarit_thermographe_short TO postgres;
-- GRANT SELECT ON TABLE api.gabarit_thermographe_short TO read_only_all;
-- GRANT SELECT ON TABLE api.gabarit_thermographe_short TO read_only_public;
-- GRANT SELECT ON TABLE api.gabarit_thermographe_short TO read_write_all;
