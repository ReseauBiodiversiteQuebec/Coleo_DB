-------------------------------------------------------------------------------
-- VIEW api.gabarit_mammiferes_long
-- DESCRIPTION Representation of the data for the mammiferes campaigns
-------------------------------------------------------------------------------

-- CREATE VIEW FOR MAMMIFERES CAMPAIGN
-- View: api.gabarit_mammiferes_long

-- DROP VIEW api.gabarit_mammiferes_long;

CREATE OR REPLACE VIEW api.gabarit_mammiferes_long AS (
    select c.type campaigns_type,
        s.site_code as sites_site_code,
        c.opened_at as campaigns_opened_at,
        c.closed_at as campaigns_closed_at,
        c.technicians as campaigns_technicians,
        c.notes as campaigns_notes,
        e.recording_minutes as efforts_recording_minutes,
        e.photo_count as efforts_photo_count,
        e.time_start as efforts_time_start,
        e.time_finish as efforts_time_finish,
        e.notes as efforts_notes,
        d.sd_card_codes as devices_sd_card_codes,
        d.cam_code as devices_cam_code,
        d.cam_h_cm as devices_cam_h_cm,
        -- Camera landmark
        st_y(camera.geom) as landmarks_lat_camera,
        st_x(camera.geom) as landmarks_lon_camera,
        camera.tree_code as landmarks_tree_code_camera,
        camera.taxa_name as landmarks_taxa_name_camera,
        camera.dbh as landmarks_dbh_camera,
        camera.azimut as landmarks_azimuth_camera,
        camera.notes as landmarks_notes_camera,
        lu.installed_at as lures_installed_at,
        lu.lure as lures_lure,
        -- Lure landmark
        st_y(lure.geom) as landmarks_lat_appat,
        st_x(lure.geom) as landmarks_lon_appat,
        lure.tree_code as landmarks_tree_code_appat,
        lure.taxa_name as landmarks_taxa_name_appat,
        lure.dbh as landmarks_dbh_appat,
        lure.azimut as landmarks_azimuth_appat,
        lure.distance as landmarks_distance_appat,
        lure.distance_unit as landmarks_distance_unit_appat,
        lure.notes as landmarks_notes_appat,
        -- observation
        o.date_obs as observations_date_obs,
        o.time_obs as observations_time_obs,
        o.notes as observations_notes,
        jsonb_object_keys((extra #>> '{}')::jsonb) as observations_extra_variable_1,
        (o.extra #>> '{}')::jsonb -> 'taxonomist' ->> 'value' as observations_extra_value_1,
        (o.extra #>> '{}')::jsonb -> 'taxonomist' ->> 'description' as observations_extra_description_1,
        os.taxa_name as obs_species_taxa_name,
        os.parent_taxa_name as obs_species_parent_taxa_name,
        os.variable as obs_species_variable,
        os.value as obs_species_value,
        concat(m.name, m.og_extention) as media_name
    from campaigns c
    left join sites s on s.id = c.site_id
    left join observations o on o.campaign_id = c.id
    left join obs_species os on os.observation_id = o.id
    left join observations_efforts_lookup oel ON oel.observation_id=o.id
    left join efforts e on e.id = oel.effort_id
    left join devices d on d.campaign_id = c.id
    left join taxa_obs t on t.id = os.id_taxa_obs
    left join lures lu on lu.campaign_id = c.id
    left join landmarks camera ON d.id = camera.device_id
    left join landmarks lure ON lure.lure_id = lu.id
    left join obs_media om ON om.obs_id=o.id
    left join media m on m.id = om.media_id
    where c.type = 'mammifères'
    ORDER BY c.opened_at ASC, s.site_code, c.closed_at, e.id, e.notes, lu.installed_at
);

GRANT SELECT ON TABLE api.gabarit_mammiferes_long TO coleo_test_user;
GRANT ALL ON TABLE api.gabarit_mammiferes_long TO glaroc;
GRANT ALL ON TABLE api.gabarit_mammiferes_long TO postgres;
GRANT SELECT ON TABLE api.gabarit_mammiferes_long TO read_only_all;
GRANT SELECT ON TABLE api.gabarit_mammiferes_long TO read_only_public;
GRANT SELECT ON TABLE api.gabarit_mammiferes_long TO read_write_all;

-------------------------------------------------------------------------------
-- VIEW api.gabarit_mammiferes_short
-- DESCRIPTION Short representation of the data for the mammifères campaign
-------------------------------------------------------------------------------

-- CREATE VIEW FOR MAMMIFÈRES CAMPAIGN
-- View: api.gabarit_mammiferes_short

-- DROP VIEW api.gabarit_mammiferes_short;
CREATE OR REPLACE VIEW api.gabarit_mammiferes_short AS (
    select COALESCE(cl.name, '') || CASE WHEN s.site_name IS NOT NULL THEN ' - ' || s.site_name ELSE '' END as "Nom du site",
        s.type as "Type de site",
        s.site_code as "Code du site",
        o.date_obs as "Date d'observation",
        o.time_obs as "Heure d'observation",
        e.notes as "Type de capture par caméra",
        e.recording_minutes as "Effort (minutes d'enregistrement)",
        e.photo_count as "Effort (nombre de photos)",
        CASE WHEN t.observed_scientific_name IS NULL THEN os.taxa_name ELSE t.observed_scientific_name END as "Taxon observé",
        os.value as "Abondance",
        t.valid_scientific_name as "Nom scientifique valide",
        t.vernacular_fr as "Nom vernaculaire",
        t.kingdom as "Règne",
        t.phylum as "Embranchement",
        t.class as "Classe",
        t.order as "Ordre",
        t.family as "Famille",
        t.genus as "Genre",
        t.species as "Espèce"
    from campaigns c
    left join sites s on s.id = c.site_id
    left join cells cl on cl.id = s.cell_id
    left join environments en on en.campaign_id = c.id
    left join observations o on o.campaign_id = c.id
    left join obs_species os on os.observation_id = o.id
    left join api.taxa t on t.id_taxa_obs= os.id_taxa_obs
    left JOIN efforts e ON c.id = e.campaign_id
    where c.type = 'mammifères'
    order by 
        c.opened_at ASC,
        s.site_code,
        e.id,
        o.date_obs, 
        o.time_obs
);

GRANT SELECT ON TABLE api.gabarit_mammiferes_short TO coleo_test_user;
GRANT ALL ON TABLE api.gabarit_mammiferes_short TO glaroc;
GRANT ALL ON TABLE api.gabarit_mammiferes_short TO postgres;
GRANT SELECT ON TABLE api.gabarit_mammiferes_short TO read_only_all;
GRANT SELECT ON TABLE api.gabarit_mammiferes_short TO read_only_public;
GRANT SELECT ON TABLE api.gabarit_mammiferes_short TO read_write_all;
