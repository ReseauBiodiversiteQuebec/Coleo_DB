-------------------------------------------------------------------------------
-- VIEW api.gabarit_vegetation_long
-- DESCRIPTION Representation of the data for the vegetation campaigns
--
-- NOTE this view regroups the data from the vegetation and vegetation_transect
-- campaigns
-------------------------------------------------------------------------------

-- CREATE VIEW FOR VÉGÉTATION CAMPAIGNS
-- View: api.gabarit_vegetation_long

-- DROP VIEW api.gabarit_vegetation_long;

CREATE OR REPLACE VIEW api.gabarit_vegetation_long AS (
    select c.type campaigns_type,
        s.site_code as sites_site_code,
        c.opened_at as campaigns_opened_at,
        c.closed_at as campaigns_closed_at,
        array_to_string(technicians, ', ') campaigns_technicians,
        c.notes as campaigns_notes,
        e.samp_surf as efforts_samp_surf,
        e.samp_surf_unit as efforts_samp_surf_unit,
        e.notes as efforts_notes,
        l.type as landmarks_type,
        st_y(l.geom) as landmarks_lat,
        st_x(l.geom) as landmarks_lon,
        l.axis as landmarks_axis,
        l.azimut as landmarks_azimut,
        l.distance as landmarks_distance,
        l.distance_unit as landmarks_distance_unit,
        l.notes as landmarks_notes,
        o.date_obs as observations_date_obs,
        os.taxa_name as obs_species_taxa_name,
        os.parent_taxa_name as obs_species_parent_taxa_name,
        o.stratum as observations_stratum,
        extra.*,
        os.variable as obs_species_variable,
        os.value as obs_species_value,
        os.value_string as obs_species_value_string,
        o.notes as observations_notes
    from campaigns c
    left join sites s on s.id = c.site_id
    left join observations o on o.campaign_id = c.id
    left join observations_efforts_lookup oel ON oel.observation_id=o.id
    left join efforts e on e.id = oel.effort_id
    left join obs_species os on os.observation_id = o.id
    left join observations_landmarks_lookup oll on oll.observation_id = o.id
    left join landmarks l ON l.id = oll.landmark_id
    -- Lateral join to get the extra columns as they connot be accessed when the table is empty
    left join lateral (
        select
            jsonb_object_keys((extra #>> '{}')::jsonb) as extra_variable_1,
            (extra #>> '{}')::jsonb -> 'observation_supplémentaire' ->> 'value' as extra_value_1
        from observations
        where id = o.id
    ) as extra on true
    where c.type in ('végétation', 'végétation_transect')
    order by (c.opened_at, s.site_code, c.technicians, c.notes, e.samp_surf, o.stratum)
);

GRANT SELECT ON TABLE api.gabarit_vegetation_long TO coleo_test_user;
GRANT ALL ON TABLE api.gabarit_vegetation_long TO glaroc;
GRANT ALL ON TABLE api.gabarit_vegetation_long TO postgres;
GRANT SELECT ON TABLE api.gabarit_vegetation_long TO read_only_all;
GRANT SELECT ON TABLE api.gabarit_vegetation_long TO read_only_public;
GRANT SELECT ON TABLE api.gabarit_vegetation_long TO read_write_all;


-------------------------------------------------------------------------------
-- VIEW api.gabarit_vegetation_short
-- DESCRIPTION Short representation of the data for the végétation campaign
--
-- NOTE this view regroups the data from the vegetation and vegetation_transect
-- campaigns
-------------------------------------------------------------------------------

-- CREATE VIEW FOR VÉGÉTATION CAMPAIGNS
-- View: api.gabarit_vegetation_short

-- DROP VIEW api.gabarit_vegetation_short;

CREATE OR REPLACE VIEW api.gabarit_vegetation_short AS (
    select COALESCE(cl.name, '') || CASE WHEN s.site_name IS NOT NULL THEN ' - ' || s.site_name ELSE '' END as "Nom du site",
        s.type as "Type de site",
        s.site_code as "Code du site",
        c.opened_at as "Date de l'inventaire",
        e.samp_surf as "Surface échantillée (m2)",
        o.stratum as "Strate",
        -- t.observed_scientific_name as "Nom du taxon",
        CASE WHEN t.observed_scientific_name IS NULL THEN os.taxa_name ELSE t.observed_scientific_name END as "Taxon observé",
        os.variable as "Variable mesurée",
        CASE WHEN os.variable = 'catégorie_recouvrement' THEN os.value_string ELSE 'TRUE' END as "Valeur mesurée",
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
    where c.type in ('végétation', 'végétation_transect')
    order by 
        -- t.observed_scientific_name NULLS LAST,
        c.opened_at ASC,
        s.site_code,
        e.samp_surf,
        o.stratum
);

GRANT SELECT ON TABLE api.gabarit_vegetation_short TO coleo_test_user;
GRANT ALL ON TABLE api.gabarit_vegetation_short TO glaroc;
GRANT ALL ON TABLE api.gabarit_vegetation_short TO postgres;
GRANT SELECT ON TABLE api.gabarit_vegetation_short TO read_only_all;
GRANT SELECT ON TABLE api.gabarit_vegetation_short TO read_only_public;
GRANT SELECT ON TABLE api.gabarit_vegetation_short TO read_write_all;
