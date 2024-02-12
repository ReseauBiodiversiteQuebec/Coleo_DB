-------------------------------------------------------------------------------
-- VIEW api.gabarit_benthos_long
-- DESCRIPTION Representation of the data for the benthos campaigns
-------------------------------------------------------------------------------

-- CREATE VIEW FOR BENTHOS CAMPAIGN
-- View: api.gabarit_benthos_long

-- DROP VIEW api.gabarit_benthos_long;

CREATE OR REPLACE VIEW api.gabarit_benthos_long AS (
    select c.type campaigns_type,
        s.site_code as sites_site_code,
        c.opened_at as campaigns_opened_at,
        c.closed_at as campaigns_closed_at,
        array_to_string(technicians, ', ') campaigns_technicians,
        c.notes as campaigns_notes,
        e.time_start as efforts_time_start,
        e.time_finish as efforts_time_finish,
        e.fraction_benthos as efforts_fraction_benthos,
        e.notes as efforts_notes,
        os.taxa_name as obs_species_taxa_name,
        os.parent_taxa_name as obs_species_parent_taxa_name,
        o.date_obs as observations_date_obs,
        o.time_obs as observations_time_obs,
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
    -- Lateral join to get the extra columns as they connot be accessed when the table is empty
    left join lateral (
        select
            -- extra_variable_1
            CASE WHEN (extra #>> '{}')::jsonb -> 'largeur_riviere' IS NOT NULL THEN 'largeur_riviere' ELSE NULL END as environments_extra_variable_1,
            (extra #>> '{}')::jsonb -> 'largeur_riviere' ->> 'value' as environnements_extra_value_1,
            (extra #>> '{}')::jsonb -> 'largeur_riviere' ->> 'units' as environnements_extra_units_1,
            (extra #>> '{}')::jsonb -> 'largeur_riviere' ->> 'type' as environnements_extra_type_1,
            (extra #>> '{}')::jsonb -> 'largeur_riviere' ->> 'description' as environnements_extra_description_1,
            -- extra_variable_2
            CASE WHEN (extra #>> '{}')::jsonb -> 'profondeur_riviere' IS NOT NULL THEN 'profondeur_riviere' ELSE NULL END as environnements_extra_variable_2,
            (extra #>> '{}')::jsonb -> 'profondeur_riviere' ->> 'value' as environnements_extra_value_2,
            (extra #>> '{}')::jsonb -> 'profondeur_riviere' ->> 'units' as environnements_extra_units_2,
            (extra #>> '{}')::jsonb -> 'profondeur_riviere' ->> 'type' as environnements_extra_type_2,
            (extra #>> '{}')::jsonb -> 'profondeur_riviere' ->> 'description' as environnements_extra_description_2,
            -- extra_variable_3
            CASE WHEN (extra #>> '{}')::jsonb -> 'vitesse_courant' IS NOT NULL THEN 'vitesse_courant' ELSE NULL END as environnements_extra_variable_3,
            (extra #>> '{}')::jsonb -> 'vitesse_courant' ->> 'value' as environnements_extra_value_3,
            (extra #>> '{}')::jsonb -> 'vitesse_courant' ->> 'units' as environnements_extra_units_3,
            (extra #>> '{}')::jsonb -> 'vitesse_courant' ->> 'type' as environnements_extra_type_3,
            (extra #>> '{}')::jsonb -> 'vitesse_courant' ->> 'description' as environnements_extra_description_3,
            -- extra_variable_4
            CASE WHEN (extra #>> '{}')::jsonb -> 'transparence_eau' IS NOT NULL THEN 'transparence_eau' ELSE NULL END as environnements_extra_variable_4,
            (extra #>> '{}')::jsonb -> 'transparence_eau' ->> 'value' as environnements_extra_value_4,
            (extra #>> '{}')::jsonb -> 'transparence_eau' ->> 'units' as environnements_extra_units_4,
            (extra #>> '{}')::jsonb -> 'transparence_eau' ->> 'type' as environnements_extra_type_4,
            (extra #>> '{}')::jsonb -> 'transparence_eau' ->> 'description' as environnements_extra_description_4,
            -- extra_variable_5
            CASE WHEN (extra #>> '{}')::jsonb -> 'temperature_eau' IS NOT NULL THEN 'temperature_eau' ELSE NULL END as environnements_extra_variable_5,
            (extra #>> '{}')::jsonb -> 'temperature_eau' ->> 'value' as environnements_extra_value_5,
            (extra #>> '{}')::jsonb -> 'temperature_eau' ->> 'units' as environnements_extra_units_5,
            (extra #>> '{}')::jsonb -> 'temperature_eau' ->> 'type' as environnements_extra_type_5,
            (extra #>> '{}')::jsonb -> 'temperature_eau' ->> 'description' as environnements_extra_description_5
        from environments
        where environments.campaign_id = c.id
    ) as extra on true
    where c.type = 'benthos'
    order by (c.opened_at, s.site_code, c.technicians, c.notes)
);

GRANT SELECT ON TABLE api.gabarit_benthos_long TO coleo_test_user;
GRANT ALL ON TABLE api.gabarit_benthos_long TO glaroc;
GRANT ALL ON TABLE api.gabarit_benthos_long TO postgres;
GRANT SELECT ON TABLE api.gabarit_benthos_long TO read_only_all;
GRANT SELECT ON TABLE api.gabarit_benthos_long TO read_only_public;
GRANT SELECT ON TABLE api.gabarit_benthos_long TO read_write_all;


-------------------------------------------------------------------------------
-- VIEW api.gabarit_benthos_short
-- DESCRIPTION Short representation of the data for the benthos campaign
-------------------------------------------------------------------------------

-- CREATE VIEW FOR BENTHOS CAMPAIGN
-- View: api.gabarit_benthos_short

-- DROP VIEW api.gabarit_benthos_short;

CREATE OR REPLACE VIEW api.gabarit_benthos_short AS (
    select COALESCE(cl.name, '') || CASE WHEN s.site_name IS NOT NULL THEN ' - ' || s.site_name ELSE '' END as "Nom du site",
        s.type as "Type de site",
        s.site_code as "Code du site",
        c.opened_at as "Date de l'inventaire",
        o.time_obs as "Heure d'observation",
        e.fraction_benthos as "Fraction sous-échantillonnée",
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
    where c.type = 'benthos'
    order by 
        c.opened_at ASC,
        s.site_code,
        e.time_start, 
        o.date_obs, 
        o.time_obs
);

GRANT SELECT ON TABLE api.gabarit_benthos_short TO coleo_test_user;
GRANT ALL ON TABLE api.gabarit_benthos_short TO glaroc;
GRANT ALL ON TABLE api.gabarit_benthos_short TO postgres;
GRANT SELECT ON TABLE api.gabarit_benthos_short TO read_only_all;
GRANT SELECT ON TABLE api.gabarit_benthos_short TO read_only_public;
GRANT SELECT ON TABLE api.gabarit_benthos_short TO read_write_all;
