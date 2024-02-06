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
    -- st_y(geom) as landmarks_lat,
    -- st_x(geom) as landmarks_lon,
    -- l.tree_code as landmarks_tree_code,
    -- l.taxa_name as landmarks_taxa_name,
    -- l.dbh as landmarks_dbh,
    -- l.azimuth as landmarks_azimuth,
    -- l.notes as landmarks_notes,
    lu.installed_at as lures_installed_at,
    lu.lure as lures_lure,
    -- st_y(geom) as landmarks_lat,
    -- st_x(geom) as landmarks_lon,
    -- l.tree_code as landmarks_tree_code,
    -- l.taxa_name as landmarks_taxa_name,
    -- l.dbh as landmarks_dbh,
    -- l.azimuth as landmarks_azimuth,
    -- l.distance as landmarks_distance,
    -- l.distance_unit as landmarks_distance_unit,
    -- l.notes as landmarks_notes,
    o.date_obs as observations_date_obs,
    o.time_obs as observations_time_obs,
    o.notes as observations_notes,
    -- extra,
    jsonb_object_keys((extra #>> '{}')::jsonb) as observations_extra_variable_1,
    (o.extra #>> '{}')::jsonb -> 'taxonomist' ->> 'value' as observations_extra_value_1,
    (o.extra #>> '{}')::jsonb -> 'taxonomist' ->> 'description' as observations_extra_description_1
    --
    os.taxa_name as obs_species_taxa_name,
    os.parent_taxa_name as obs_species_parent_taxa_name,
    os.variable as obs_species_variable,
    os.value as obs_species_value,
    m.name as media_name
from campaigns c
left join sites s on s.id = c.site_id
left join observations o on o.campaign_id = c.id
left join obs_species os on os.observation_id = o.id
left join observations_efforts_lookup oel ON oel.observation_id=o.id
left join efforts e on e.id = oel.effort_id
left join devices d on d.campaign_id = c.id
left join taxa_obs t on t.id = os.id_taxa_obs
left join observations_landmarks_lookup oll on oll.observation_id = o.id
left join landmarks l ON l.id = oll.landmark_id
left join lures lu on lu.campaign_id = c.id
left join obs_media om ON om.obs_id=o.id
left join media m on m.id = om.media_id
where c.type = 'mammifères'
    and site_code = '135_104_F01';


-- select * from media limit 5;

-- GRANT SELECT ON TABLE api.gabarit_acoustique_orthopteres_short TO coleo_test_user;
-- GRANT ALL ON TABLE api.gabarit_acoustique_orthopteres_short TO glaroc;
-- GRANT ALL ON TABLE api.gabarit_acoustique_orthopteres_short TO postgres;
-- GRANT SELECT ON TABLE api.gabarit_acoustique_orthopteres_short TO read_only_all;
-- GRANT SELECT ON TABLE api.gabarit_acoustique_orthopteres_short TO read_only_public;
-- GRANT SELECT ON TABLE api.gabarit_acoustique_orthopteres_short TO read_write_all;