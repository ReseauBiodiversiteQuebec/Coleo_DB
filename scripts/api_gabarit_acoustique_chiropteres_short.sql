-------------------------------------------------------------------------------
-- VIEW api.gabarit_acoustique_chiropteres_short
-- DESCRIPTION Short representation of the data for the acoustique_chiroptères campaign
-------------------------------------------------------------------------------

-- CREATE VIEW FOR ACOUSTIQUE CHIROPTERES CAMPAIGN
-- View: api.gabarit_acoustique_chiropteres_short

-- DROP VIEW api.gabarit_acoustique_chiropteres_short;

CREATE OR REPLACE VIEW api.gabarit_acoustique_chiropteres_short AS (
    
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
    where c.type = 'acoustique_chiroptères'
        and site_code = '135_104_H01'
    order by 
        -- t.observed_scientific_name NULLS LAST,
        s.site_code,
        c.opened_at ASC,
        e.time_start, 
        o.date_obs, 
        o.time_obs
);

