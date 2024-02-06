-------------------------------------------------------------------------------
-- VIEW api.gabarit_adne_corrige_long
-- DESCRIPTION Representation of the data for the adne_corrigé campaigns
-------------------------------------------------------------------------------

-- CREATE VIEW FOR ADNE-CORRIGÉ CAMPAIGN
-- View: api.gabarit_adne_corrige_long

-- DROP VIEW api.gabarit_adne_corrige_long;

CREATE OR REPLACE VIEW api.gabarit_adne_corrige_long AS (
    select c.type campaigns_type,
        s.site_code as sites_site_code,
        c.opened_at as campaigns_opened_at,
        c.closed_at as campaigns_closed_at,
        array_to_string(technicians, ', ') campaigns_technicians,
        o.date_obs as observations_date_obs,
        o.notes as observations_notes,
        oe.taxa_name as obs_edna_taxa_name,
        oe.parent_taxa_name as obs_edna_parent_taxa_name,
        oe.type_edna as obs_edna_type_edna,
        oe.sequence_count as obs_edna_sequence_count,
        oe.sequence_count_corrected as obs_edna_sequence_count_corrected,
        oe.notes as obs_edna_notes
    from campaigns c
    left join sites s on s.id = c.site_id
    left join observations o on o.campaign_id = c.id
    left join obs_edna oe on oe.observation_id = o.id
    where c.type = 'ADNe_corrigé'
    order by (c.opened_at, s.site_code, c.technicians)
);

GRANT SELECT ON TABLE api.gabarit_adne_corrige_long TO coleo_test_user;
GRANT ALL ON TABLE api.gabarit_adne_corrige_long TO glaroc;
GRANT ALL ON TABLE api.gabarit_adne_corrige_long TO postgres;
GRANT SELECT ON TABLE api.gabarit_adne_corrige_long TO read_only_all;
GRANT SELECT ON TABLE api.gabarit_adne_corrige_long TO read_only_public;
GRANT SELECT ON TABLE api.gabarit_adne_corrige_long TO read_write_all;




-------------------------------------------------------------------------------
-- VIEW api.gabarit_adne_corrige_short
-- DESCRIPTION Short representation of the data for the adne_corrigé campaign
-------------------------------------------------------------------------------

-- CREATE VIEW FOR ADNE-CORRIGÉ CAMPAIGN
-- View: api.gabarit_adne_corrige_short

-- DROP VIEW api.gabarit_adne_corrige_short;

CREATE OR REPLACE VIEW api.gabarit_adne_corrige_short AS (
    select COALESCE(cl.name, '') || CASE WHEN s.site_name IS NOT NULL THEN ' - ' || s.site_name ELSE '' END as "Nom du site",
        s.type as "Type de site",
        s.site_code as "Code du site",
        c.opened_at as "Date de l'inventaire",
        -- o.date_obs as "Date d'observation",
        -- o.time_obs as "Heure d'observation",
        CASE WHEN t.observed_scientific_name IS NULL THEN oe.taxa_name ELSE t.observed_scientific_name END as "Taxon observé",
        oe.type_edna as "Statut de l'observation",
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
    left join obs_edna oe on oe.observation_id = o.id
    left join api.taxa t on t.id_taxa_obs= oe.id_taxa_obs
    where c.type = 'ADNe_corrigé'
        -- and oe.type_edna = 'confirmé'
    order by 
        -- t.observed_scientific_name NULLS LAST,
        c.opened_at ASC,
        s.site_code,
        o.date_obs, 
        o.time_obs
);

GRANT SELECT ON TABLE api.gabarit_adne_corrige_short TO coleo_test_user;
GRANT ALL ON TABLE api.gabarit_adne_corrige_short TO glaroc;
GRANT ALL ON TABLE api.gabarit_adne_corrige_short TO postgres;
GRANT SELECT ON TABLE api.gabarit_adne_corrige_short TO read_only_all;
GRANT SELECT ON TABLE api.gabarit_adne_corrige_short TO read_only_public;
GRANT SELECT ON TABLE api.gabarit_adne_corrige_short TO read_write_all;
