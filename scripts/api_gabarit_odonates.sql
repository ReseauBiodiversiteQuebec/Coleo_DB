-------------------------------------------------------------------------------
-- VIEW api.gabarit_odonates_long
-- DESCRIPTION Representation of the data for the odonates campaigns
-------------------------------------------------------------------------------

-- CREATE VIEW FOR ODONATES CAMPAIGN
-- View: api.gabarit_odonates_long

-- DROP VIEW api.gabarit_odonates_long;

CREATE OR REPLACE VIEW api.gabarit_odonates_long AS (
    select c.type campaigns_type,
        s.site_code as sites_site_code,
        st_y(l.geom) as landmarks_lat,
        st_x(l.geom) as landmarks_lon,
        c.opened_at as campaigns_opened_at,
        c.closed_at as campaigns_closed_at,
        array_to_string(technicians, ', ') campaigns_technicians,
        e.time_start as efforts_time_start,
        e.time_finish as efforts_time_finish,
        e.notes as efforts_notes,
        en.wind as environments_wind,
        en.sky as environments_sky,
        en.temp_c as environments_temp_c,
        os.taxa_name as obs_species_taxa_name,
        os.parent_taxa_name as obs_species_parent_taxa_name,
        o.date_obs as observations_date_obs,
        os.variable as obs_species_variable,
        os.value as obs_species_value,
        o.notes as observations_notes,
        extra.*
    from campaigns c
    left join sites s on s.id = c.site_id
    left join environments en on en.campaign_id = c.id
    left join observations o on o.campaign_id = c.id
    left join obs_species os on os.observation_id = o.id
    left join observations_efforts_lookup oel ON oel.observation_id=o.id
    left join efforts e on e.id = oel.effort_id
    left join observations_landmarks_lookup oll on oll.observation_id = o.id
    left join landmarks l ON l.id = oll.landmark_id
    -- Lateral join to get the extra columns as they connot be accessed when the table is empty
    left join lateral (
        select
            -- extra_variable_1
            CASE WHEN (extra #>> '{}')::jsonb -> 'Observateur' IS NOT NULL THEN 'Observateur' ELSE NULL END as observations_extra_variable_1,
            (extra #>> '{}')::jsonb -> 'Observateur' ->> 'value' as observations_extra_value_1,
            (extra #>> '{}')::jsonb -> 'Observateur' ->> 'description' as observations_extra_description_1,
            -- extra_variable_2
            CASE WHEN (extra #>> '{}')::jsonb -> 'taxonomist' IS NOT NULL THEN 'taxonomist' ELSE NULL END as observations_extra_variable_2,
            regexp_replace((extra #>> '{}')::jsonb -> 'taxonomist' ->> 'value', '["\[\]]', '', 'g') as observations_extra_value_2,
            (extra #>> '{}')::jsonb -> 'taxonomist' ->> 'description' as observations_extra_description_2,
            -- extra_variable_3
            CASE WHEN (extra #>> '{}')::jsonb -> 'Méthode_observation' IS NOT NULL THEN 'Méthode_observation' ELSE NULL END as observations_extra_variable_3,
            (extra #>> '{}')::jsonb -> 'Méthode_observation' ->> 'value' as observations_extra_value_3,
            (extra #>> '{}')::jsonb -> 'Méthode_observation' ->> 'description' as observations_extra_description_3
        from observations
        where id = o.id
    ) as extra on true
    where c.type = 'odonates'
    order by (c.opened_at, s.site_code, c.technicians, c.notes)
);

GRANT SELECT ON TABLE api.gabarit_odonates_long TO coleo_test_user;
GRANT ALL ON TABLE api.gabarit_odonates_long TO glaroc;
GRANT ALL ON TABLE api.gabarit_odonates_long TO postgres;
GRANT SELECT ON TABLE api.gabarit_odonates_long TO read_only_all;
GRANT SELECT ON TABLE api.gabarit_odonates_long TO read_only_public;
GRANT SELECT ON TABLE api.gabarit_odonates_long TO read_write_all;


-------------------------------------------------------------------------------
-- VIEW api.gabarit_odonates_short
-- DESCRIPTION Short representation of the data for the odonates campaign
-------------------------------------------------------------------------------

-- CREATE VIEW FOR PAPILIONIDÉS CAMPAIGN
-- View: api.gabarit_odonates_short

-- DROP VIEW api.gabarit_odonates_short;

CREATE OR REPLACE VIEW api.gabarit_odonates_short AS (
    select COALESCE(cl.name, '') || CASE WHEN s.site_name IS NOT NULL THEN ' - ' || s.site_name ELSE '' END as "Nom du site",
        s.type as "Type de site",
        s.site_code as "Code du site",
        c.opened_at as "Date de l'inventaire",
        e.time_start as "Début de l'inventaire",
        e.time_finish as "Fin de l'inventaire",
        en.wind as "Vent [1-4]",
        en.sky as "Couverture nuageuse [1-4]",
        en.temp_c as "Température (C°)",
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
    where c.type = 'odonates'
    order by 
        c.opened_at ASC,
        s.site_code,
        e.time_start, 
        o.date_obs, 
        o.time_obs
);

GRANT SELECT ON TABLE api.gabarit_odonates_short TO coleo_test_user;
GRANT ALL ON TABLE api.gabarit_odonates_short TO glaroc;
GRANT ALL ON TABLE api.gabarit_odonates_short TO postgres;
GRANT SELECT ON TABLE api.gabarit_odonates_short TO read_only_all;
GRANT SELECT ON TABLE api.gabarit_odonates_short TO read_only_public;
GRANT SELECT ON TABLE api.gabarit_odonates_short TO read_write_all;
