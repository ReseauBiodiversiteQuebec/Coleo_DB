-------------------------------------------------------------------------------
-- VIEW api.gabarit_decomposition_sol_long
-- DESCRIPTION Representation of the data for the décomposition_sol campaigns
-------------------------------------------------------------------------------

-- CREATE VIEW FOR décomposition_sol CAMPAIGN
-- View: api.gabarit_decomposition_sol_long

-- DROP VIEW api.gabarit_decomposition_sol_long;

CREATE OR REPLACE VIEW api.gabarit_decomposition_sol_long AS (
    select c.type campaigns_type,
        s.site_code as sites_site_code,
        st_y(l.geom) as landmarks_lat,
        st_x(l.geom) as landmarks_lon,
        c.opened_at as campaigns_opened_at,
        c.closed_at as campaigns_closed_at,
        array_to_string(technicians, ', ') campaigns_technicians,
        c.notes as campaigns_notes,
        o.date_obs as observations_date_obs,
        o.notes as observations_notes,
        os.bag_no as obs_soil_decomposition_bag_no,
        os.type as obs_soil_decomposition_type,
        os.date_end as obs_soil_decomposition_date_end,
        os.start_weight as obs_soil_decomposition_start_weight,
        os.end_weight_with_bag as obs_soil_decomposition_end_weight_with_bag,
        os.end_weight_tea as obs_soil_decomposition_end_weight_tea,
        os.shading as obs_soil_decomposition_shading,
        os.human_impact as obs_soil_decomposition_human_impact
    from campaigns c
    left join sites s on s.id = c.site_id
    left join observations o on o.campaign_id = c.id
    left join obs_soil_decomposition os on os.observation_id = o.id
    left join observations_landmarks_lookup oll on oll.observation_id = o.id
    left join landmarks l ON l.id = oll.landmark_id
    where c.type = 'décomposition_sol'
    order by (c.opened_at, s.site_code, c.technicians, c.notes)
);

GRANT SELECT ON TABLE api.gabarit_decomposition_sol_long TO coleo_test_user;
GRANT ALL ON TABLE api.gabarit_decomposition_sol_long TO glaroc;
GRANT ALL ON TABLE api.gabarit_decomposition_sol_long TO postgres;
GRANT SELECT ON TABLE api.gabarit_decomposition_sol_long TO read_only_all;
GRANT SELECT ON TABLE api.gabarit_decomposition_sol_long TO read_only_public;
GRANT SELECT ON TABLE api.gabarit_decomposition_sol_long TO read_write_all;


-------------------------------------------------------------------------------
-- VIEW api.gabarit_decomposition_sol_short
-- DESCRIPTION Short representation of the data for the decomposition_sol campaign
-------------------------------------------------------------------------------

-- CREATE VIEW FOR PAPILIONIDÉS CAMPAIGN
-- View: api.gabarit_decomposition_sol_short

-- DROP VIEW api.gabarit_decomposition_sol_short;

CREATE OR REPLACE VIEW api.gabarit_decomposition_sol_short AS (
    select COALESCE(cl.name, '') || CASE WHEN s.site_name IS NOT NULL THEN ' - ' || s.site_name ELSE '' END as "Nom du site",
        s.type as "Type de site",
        s.site_code as "Code du site",
        sd.start "Date de pose du sac",
        sd.end "Date de récupération du sac",
        sd.t "Jours en sol",
        sd.s as "Vitesse de décomposition",
        sd.k as "Facteur de stabilisation",
        sd.avg_tv_start_weight as "Poids initial (thé vert)",
        sd.avg_tv_end_weight_with_bag as "Poids final avec sac (thé vert)",
        sd.avg_tv_end_weight_tea as "Poids final du thé (thé vert)",
        sd.avg_tr_start_weight as "Poids initial (thé rooibos)",
        sd.avg_tr_end_weight_with_bag as "Poids final avec sac (thé rooibos)",
        sd.avg_tr_end_weight_tea as "Poids final du thé (thé rooibos)"
        -- c.opened_at as "Date de pose du sac",
        -- c.closed_at as "Date de récupération du sac",
        -- os.bag_no as "Identifiant du sac",
        -- os.type as "Type de thé",
        -- sd.s as "Vitesse de décomposition",
        -- sd.k as "Facteur de stabilisation",
        -- os.start_weight as "Poids initial",
        -- os.end_weight_with_bag as "Poids final avec sac",
        -- os.end_weight_tea as "Poids final du thé",
        -- os.shading as "Ombrage",
        -- os.human_impact as "Impact humain"
    from campaigns c
    left join sites s on s.id = c.site_id
    left join cells cl on cl.id = s.cell_id
    -- left join obs_soil_decomposition os on os.observation_id = o.id
    left join indicators.soil_decomposition_tbi sd on sd.campaign_id = c.id
    where c.type = 'décomposition_sol'
    order by 
        c.opened_at ASC,
        s.site_code,
        sd.start,
        sd.end
);

GRANT SELECT ON TABLE api.gabarit_decomposition_sol_short TO coleo_test_user;
GRANT ALL ON TABLE api.gabarit_decomposition_sol_short TO glaroc;
GRANT ALL ON TABLE api.gabarit_decomposition_sol_short TO postgres;
GRANT SELECT ON TABLE api.gabarit_decomposition_sol_short TO read_only_all;
GRANT SELECT ON TABLE api.gabarit_decomposition_sol_short TO read_only_public;
GRANT SELECT ON TABLE api.gabarit_decomposition_sol_short TO read_write_all;
