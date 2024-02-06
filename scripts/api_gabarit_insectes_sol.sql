-------------------------------------------------------------------------------
-- VIEW api.gabarit_insectes_sol_long
-- DESCRIPTION Representation of the data for the insectes_sol campaigns
-------------------------------------------------------------------------------

-- CREATE VIEW FOR insectes_sol CAMPAIGN
-- View: api.gabarit_insectes_sol_long

-- DROP VIEW api.gabarit_insectes_sol_long;

CREATE OR REPLACE VIEW api.gabarit_insectes_sol_long AS (
    select c.type campaigns_type,
        s.site_code as sites_site_code,
        st_y(l.geom) as landmarks_lat,
        st_x(l.geom) as landmarks_lon,
        c.opened_at as campaigns_opened_at,
        c.closed_at as campaigns_closed_at,
        array_to_string(technicians, ', ') campaigns_technicians,
        tr.trap_code as traps_trap_code,
        tr.notes as traps_notes,
        sa.sample_code as samples_sample_code,
        sa.notes as samples_notes,
        os.taxa_name as obs_species_taxa_name,
        os.parent_taxa_name as obs_species_parent_taxa_name,
        o.date_obs as observations_date_obs,
        os.variable as obs_species_variable,
        os.value as obs_species_value,
        o.notes as observations_notes,
        extra.*
    from campaigns c
    left join sites s on s.id = c.site_id
    left join traps tr on tr.campaign_id = c.id
    left join samples sa on sa.trap_id = tr.id
    left join observations o on o.campaign_id = c.id
    left join obs_species os on os.observation_id = o.id
    left join observations_landmarks_lookup oll on oll.observation_id = o.id
    left join landmarks l ON l.id = oll.landmark_id
    -- Lateral join to get the extra columns as they connot be accessed when the table is empty
    left join lateral (
        select
            -- extra_variable_1
            CASE WHEN (extra #>> '{}')::jsonb -> 'taxonomist' IS NOT NULL THEN 'taxonomist' ELSE NULL END as observations_extra_variable_1,
            regexp_replace((extra #>> '{}')::jsonb -> 'taxonomist' ->> 'value', '["\[\]]', '', 'g') as observations_extra_value_1,
            (extra #>> '{}')::jsonb -> 'taxonomist' ->> 'type' as observations_extra_type_1,
            (extra #>> '{}')::jsonb -> 'taxonomist' ->> 'description' as observations_extra_description_1
        from observations
        where id = o.id
    ) as extra on true
    where c.type = 'insectes_sol'
    order by (c.opened_at, s.site_code, c.technicians, c.notes)
);

GRANT SELECT ON TABLE api.gabarit_insectes_sol_long TO coleo_test_user;
GRANT ALL ON TABLE api.gabarit_insectes_sol_long TO glaroc;
GRANT ALL ON TABLE api.gabarit_insectes_sol_long TO postgres;
GRANT SELECT ON TABLE api.gabarit_insectes_sol_long TO read_only_all;
GRANT SELECT ON TABLE api.gabarit_insectes_sol_long TO read_only_public;
GRANT SELECT ON TABLE api.gabarit_insectes_sol_long TO read_write_all;


-------------------------------------------------------------------------------
-- VIEW api.gabarit_insectes_sol_short
-- DESCRIPTION Short representation of the data for the insectes_sol campaign
-------------------------------------------------------------------------------

-- CREATE VIEW FOR insectes_sol CAMPAIGN
-- View: api.gabarit_insectes_sol_short

-- DROP VIEW api.gabarit_insectes_sol_short;

CREATE OR REPLACE VIEW api.gabarit_insectes_sol_short AS (
    select COALESCE(cl.name, '') || CASE WHEN s.site_name IS NOT NULL THEN ' - ' || s.site_name ELSE '' END as "Nom du site",
        s.type as "Type de site",
        s.site_code as "Code du site",
        c.opened_at as "Date de pose du piège",
        c.closed_at as "Date de collecte du piège",
        tr.trap_code as "Identifiant du piège",
        sa.sample_code as "Identifiant d'échantillon",
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
    left join traps tr on tr.campaign_id = c.id
    left join samples sa on sa.trap_id = tr.id
    left join observations o on o.campaign_id = c.id
    left join obs_species os on os.observation_id = o.id
    left join api.taxa t on t.id_taxa_obs= os.id_taxa_obs
    where c.type = 'insectes_sol'
    order by 
        c.opened_at ASC,
        s.site_code,
        tr.trap_code,
        sa.sample_code
);

GRANT SELECT ON TABLE api.gabarit_insectes_sol_short TO coleo_test_user;
GRANT ALL ON TABLE api.gabarit_insectes_sol_short TO glaroc;
GRANT ALL ON TABLE api.gabarit_insectes_sol_short TO postgres;
GRANT SELECT ON TABLE api.gabarit_insectes_sol_short TO read_only_all;
GRANT SELECT ON TABLE api.gabarit_insectes_sol_short TO read_only_public;
GRANT SELECT ON TABLE api.gabarit_insectes_sol_short TO read_write_all;
