-------------------------------------------------------------------------------
-- VIEW api.gabarit_acoustique_chiropteres_long
-- DESCRIPTION Representation of the data for the acoustique_chiroptères campaign
-------------------------------------------------------------------------------

-- CREATE VIEW FOR ACOUSTIQUE CHIROPTERES CAMPAIGN
-- View: api.gabarit_acoustique_chiropteres_long

-- DROP VIEW api.gabarit_acoustique_chiropteres_long;

CREATE OR REPLACE VIEW api.gabarit_acoustique_chiropteres_long AS (
    select c.type campaigns_type,
        s.site_code as sites_site_code,
        st_y(l.geom) as landmarks_lat,
        st_x(l.geom) as landmarks_lon,
        c.opened_at as campaigns_opened_at,
        c.closed_at as campaigns_closed_at,
        array_to_string(technicians, ', ') campaigns_technicians,
        c.notes as campaigns_notes,
        d.mic_ultra_code as devices_mic_ultra_code,
        d.mic_acc_code as devices_mic_acc_code,
        e.time_start as efforts_time_start,
        e.time_finish as efforts_time_finish,
        e.notes as efforts_notes,
        os.taxa_name as obs_species_taxa_name,
        os.parent_taxa_name as obs_species_parent_taxa_name,
        os.variable as obs_species_variable,
        o.date_obs as observations_date_obs,
        o.time_obs as observations_time_obs,
        o.notes as observations_notes,
        --extra column
        jsonb_object_keys((extra #>> '{}')::jsonb) as observations_extra_variable_1,
        (o.extra #>> '{}')::jsonb -> 'taxonomist' ->> 'value' as observations_extra_value_1,
        (o.extra #>> '{}')::jsonb -> 'taxonomist' ->> 'description' as observations_extra_description_1
    from campaigns c
    left join sites s on s.id = c.site_id
    left join observations o on o.campaign_id = c.id
    left join obs_species os on os.observation_id = o.id
    left join observations_efforts_lookup oel ON oel.observation_id=o.id
    left join efforts e on e.id = oel.effort_id
    left join devices d on d.campaign_id = c.id
    left join observations_landmarks_lookup oll on oll.observation_id = o.id
    left join landmarks l ON l.id = oll.landmark_id
    where c.type = 'acoustique_chiroptères'
    order by (s.site_code, c.opened_at, c.technicians, c.notes)
);