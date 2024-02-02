-------------------------------------------------------------------------------
-- VIEW api.gabarit_acoustique_oiseaux_long
-- DESCRIPTION Representation of the data for the acoustique_oiseaux campaigns
-------------------------------------------------------------------------------

-- CREATE VIEW FOR ACOUSTIQUE CHIROPTERES CAMPAIGN
-- View: api.gabarit_acoustique_oiseaux_long

-- DROP VIEW api.gabarit_acoustique_oiseaux_long;

CREATE OR REPLACE VIEW api.gabarit_acoustique_oiseaux_long AS (
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
        extra.*
    from campaigns c
    left join sites s on s.id = c.site_id
    left join observations o on o.campaign_id = c.id
    left join obs_species os on os.observation_id = o.id
    left join observations_efforts_lookup oel ON oel.observation_id=o.id
    left join efforts e on e.id = oel.effort_id
    left join devices d on d.campaign_id = c.id
    left join observations_landmarks_lookup oll on oll.observation_id = o.id
    left join landmarks l ON l.id = oll.landmark_id
    left join lateral (
        select
            -- extra_variable_1
            CASE WHEN (extra #>> '{}')::jsonb -> 'taxonomist' IS NOT NULL THEN 'taxonomist' ELSE NULL END as observations_extra_variable_1,
            regexp_replace((extra #>> '{}')::jsonb -> 'taxonomist' ->> 'value', '["\[\]]', '', 'g') as observations_extra_value_1,
            (extra #>> '{}')::jsonb -> 'taxonomist' ->> 'description' as observations_extra_description_1
        from observations
        where id = o.id
    ) as extra on true
    where c.type = 'acoustique_oiseaux'
    order by (c.opened_at, s.site_code, c.technicians, c.notes)
);

GRANT SELECT ON TABLE api.gabarit_acoustique_oiseaux_long TO coleo_test_user;
GRANT ALL ON TABLE api.gabarit_acoustique_oiseaux_long TO glaroc;
GRANT ALL ON TABLE api.gabarit_acoustique_oiseaux_long TO postgres;
GRANT SELECT ON TABLE api.gabarit_acoustique_oiseaux_long TO read_only_all;
GRANT SELECT ON TABLE api.gabarit_acoustique_oiseaux_long TO read_only_public;
GRANT SELECT ON TABLE api.gabarit_acoustique_oiseaux_long TO read_write_all;


-------------------------------------------------------------------------------
-- VIEW api.gabarit_acoustique_oiseaux_short
-- DESCRIPTION Short representation of the data for the acoustique_oiseaux campaign
-------------------------------------------------------------------------------

-- CREATE VIEW FOR ACOUSTIQUE CHIROPTERES CAMPAIGN
-- View: api.gabarit_acoustique_oiseaux_short

-- DROP VIEW api.gabarit_acoustique_oiseaux_short;

CREATE OR REPLACE VIEW api.gabarit_acoustique_oiseaux_short AS (
    select COALESCE(cl.name, '') || CASE WHEN s.site_name IS NOT NULL THEN ' - ' || s.site_name ELSE '' END as "Nom du site",
        s.type as "Type de site",
        s.site_code as "Code du site",
        c.opened_at as "Date de l'inventaire",
        e.time_start as "Début de l'inventaire",
        e.time_finish as "Fin de l'inventaire",
        -- o.date_obs as "Date d'observation",
        o.time_obs as "Heure d'observation",
        -- t.observed_scientific_name as "Nom du taxon",
        CASE WHEN t.observed_scientific_name IS NULL THEN os.taxa_name ELSE t.observed_scientific_name END as "Taxon observé",
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
    left join observations o on o.campaign_id = c.id
    left join obs_species os on os.observation_id = o.id
    left join api.taxa t on t.id_taxa_obs= os.id_taxa_obs
    left JOIN efforts e ON c.id = e.campaign_id
    where c.type = 'acoustique_oiseaux'
    order by 
        -- t.observed_scientific_name NULLS LAST,
        c.opened_at ASC,
        s.site_code,
        e.time_start, 
        o.date_obs, 
        o.time_obs
);

GRANT SELECT ON TABLE api.gabarit_acoustique_oiseaux_short TO coleo_test_user;
GRANT ALL ON TABLE api.gabarit_acoustique_oiseaux_short TO glaroc;
GRANT ALL ON TABLE api.gabarit_acoustique_oiseaux_short TO postgres;
GRANT SELECT ON TABLE api.gabarit_acoustique_oiseaux_short TO read_only_all;
GRANT SELECT ON TABLE api.gabarit_acoustique_oiseaux_short TO read_only_public;
GRANT SELECT ON TABLE api.gabarit_acoustique_oiseaux_short TO read_write_all;