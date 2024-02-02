-------------------------------------------------------------------------------
-- VIEW api.gabarit_physicochimie_long
-- DESCRIPTION Representation of the data for the physicochimie campaigns
--
-- NOTE this view regroups the data from the physicochimie_terraiin and physicochimie_labo
-- campaigns
-------------------------------------------------------------------------------

-- CREATE VIEW FOR VÉGÉTATION CAMPAIGNS
-- View: api.gabarit_physicochimie_long

-- DROP VIEW api.gabarit_physicochimie_long;

CREATE OR REPLACE VIEW api.gabarit_physicochimie_long AS (
    select c.type campaigns_type,
        s.site_code as sites_site_code,
        c.opened_at as campaigns_opened_at,
        c.closed_at as campaigns_closed_at,
        array_to_string(technicians, ', ') campaigns_technicians,
        c.notes as campaigns_notes,
        st_y(l.geom) as landmarks_lat,
        st_x(l.geom) as landmarks_lon,
        en.wind as environments_wind,
        en.sky as environments_sky,
        en.temp_c as environments_temp_c,
        en.notes as environments_notes, 
        o.date_obs as observations_date_obs,
        o.time_obs as observations_time_obs,
        o.depth as observations_depth,
        extra.*,
        o.notes as observations_notes,
        ol.water_transparency as obs_lake_water_transparency,
        ol.water_temp as obs_lake_water_temp,
        ol.oxygen_concentration as obs_lake_oxygen_concentration,
        ol.ph as obs_lake_ph,
        ol.conductivity as obs_lake_conductivity,
        ol.turbidity as obs_lake_turbidity,
        ol.dissolved_organic_carbon as obs_lake_dissolved_organic_carbon,
        ol.ammonia_nitrogen as obs_lake_ammonia_nitrogen,
        ol.nitrates_and_nitrites as obs_lake_nitrates_and_nitrites,
        ol.total_nitrogen as obs_lake_total_nitrogen,
        ol.total_phosphorus as obs_lake_total_phosphorus,
        ol.chlorophyl_a as obs_lake_chlorophyl_a,
        ol.pheophytin_a as obs_lake_pheophytin_a,
        ol.notes as obs_lake_notes
    from campaigns c
    left join sites s on s.id = c.site_id
    left join observations o on o.campaign_id = c.id
    left join environments en on en.campaign_id = c.id
    left join obs_lake ol on ol.observation_id = o.id
    left join observations_landmarks_lookup oll on oll.observation_id = o.id
    left join landmarks l ON l.id = oll.landmark_id
    -- Lateral join to get the extra columns as they connot be accessed when the table is empty
    left join lateral (
        select
            CASE WHEN (extra #>> '{}')::jsonb -> 'numéro_échantillon' IS NOT NULL THEN 'numéro_échantillon' ELSE NULL END as observations_extra_variable_1,
            (extra #>> '{}')::jsonb -> 'numéro_échantillon' ->> 'value' as extra_value_1
        from observations
        where id = o.id
    ) as extra on true
    where c.type in ('physicochimie_terrain', 'physicochimie_labo')
    order by (c.opened_at, s.site_code, c.technicians, c.notes)
);

GRANT SELECT ON TABLE api.gabarit_physicochimie_long TO coleo_test_user;
GRANT ALL ON TABLE api.gabarit_physicochimie_long TO glaroc;
GRANT ALL ON TABLE api.gabarit_physicochimie_long TO postgres;
GRANT SELECT ON TABLE api.gabarit_physicochimie_long TO read_only_all;
GRANT SELECT ON TABLE api.gabarit_physicochimie_long TO read_only_public;
GRANT SELECT ON TABLE api.gabarit_physicochimie_long TO read_write_all;


-------------------------------------------------------------------------------
-- VIEW api.gabarit_physicochimie_short
-- DESCRIPTION Short representation of the data for the physicochimie campaign
--
-- NOTE this view regroups the data from the physicochimie_terrain and physicochimie_labo
-- campaigns
-------------------------------------------------------------------------------

-- CREATE VIEW FOR VÉGÉTATION CAMPAIGNS
-- View: api.gabarit_physicochimie_short

-- DROP VIEW api.gabarit_physicochimie_short;

CREATE OR REPLACE VIEW api.gabarit_physicochimie_short AS (
    select CASE WHEN c.type = 'physicochimie_labo' THEN 'laboratoire' ELSE 'terrain' END as "Type d'inventaire",
        COALESCE(cl.name, '') || CASE WHEN s.site_name IS NOT NULL THEN ' - ' || s.site_name ELSE '' END as "Nom du site",
        s.type as "Type de site",
        s.site_code as "Code du site",
        c.opened_at as "Date de l'inventaire",
        en.wind as "Vent [1-4]",
        en.sky as "Couverture nuageuse [1-4]",
        en.temp_c as "Température (C°)",
        o.time_obs as "Heure de l'observation",
        o.depth as "Profondeur de l'observation (cm)",
        extra.*,
        ol.water_transparency as "Transparence de l'eau",
        ol.water_temp as "Température de l'eau",
        ol.oxygen_concentration as "Concentration en oxygène",
        ol.ph as "pH",
        ol.conductivity as "Conductivité",
        ol.turbidity as "Turbidité",
        ol.dissolved_organic_carbon as "Carbone organique dissous",
        ol.ammonia_nitrogen as "Azote ammoniacal",
        ol.nitrates_and_nitrites as "Nitrates et nitrites",
        ol.total_nitrogen as "Azote total",
        ol.total_phosphorus as "Phosphore total",
        ol.chlorophyl_a as "Chlorophylle a",
        ol.pheophytin_a as "Pheophytine a"
    from campaigns c
    left join sites s on s.id = c.site_id
    left join cells cl on cl.id = s.cell_id
    left join observations o on o.campaign_id = c.id
    left join obs_lake ol on ol.observation_id = o.id
    left JOIN environments en ON c.id = en.campaign_id
    left join lateral (
        select
            (extra #>> '{}')::jsonb -> 'numéro_échantillon' ->> 'value' as "Numéro d'échantillon"
        from observations
        where id = o.id
    ) as extra on true
    where c.type in ('physicochimie_terrain', 'physicochimie_labo')
    order by 
        -- t.observed_scientific_name NULLS LAST,
        c.opened_at ASC,
        s.site_code,
        o.depth
);

GRANT SELECT ON TABLE api.gabarit_physicochimie_short TO coleo_test_user;
GRANT ALL ON TABLE api.gabarit_physicochimie_short TO glaroc;
GRANT ALL ON TABLE api.gabarit_physicochimie_short TO postgres;
GRANT SELECT ON TABLE api.gabarit_physicochimie_short TO read_only_all;
GRANT SELECT ON TABLE api.gabarit_physicochimie_short TO read_only_public;
GRANT SELECT ON TABLE api.gabarit_physicochimie_short TO read_write_all;
