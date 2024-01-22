--------------------------------------------------------------------------------
-- Fix problematic taxa names
-- The taxa_obs.scientific_names that match multiple taxa_ref.scientific_names
--------------------------------------------------------------------------------
SELECT
    o.scientific_name,
    COUNT(DISTINCT r.scientific_name) AS counts,
    ARRAY_AGG(DISTINCT r.scientific_name),
    ARRAY_AGG(DISTINCT o.id) as id_taxa_obs,
    ARRAY_AGG(DISTINCT c.type) as campaign_type
FROM taxa_ref r
JOIN taxa_obs_ref_lookup lu ON r.id = lu.id_taxa_ref
JOIN taxa_obs o ON o.id = lu.id_taxa_obs
JOIN obs_species os ON os.id_taxa_obs = o.id
JOIN observations obs ON obs.id = os.observation_id
JOIN campaigns c ON c.id = obs.campaign_id
WHERE r.rank = 'phylum'
GROUP BY o.scientific_name
HAVING COUNT(DISTINCT r.scientific_name) > 1
ORDER BY counts DESC;

-- Fix issues
select fix_taxa_obs_parent_taxa_name(23531, 'Plantae');
select fix_taxa_obs_parent_taxa_name(2418, 'Plantae');
select fix_taxa_obs_parent_taxa_name(2418, 'Plantae');
select fix_taxa_obs_parent_taxa_name(6172, 'Mollusca');
select fix_taxa_obs_parent_taxa_name(6586, 'Arthropoda');
select fix_taxa_obs_parent_taxa_name(95727, 'Rotifera');
select fix_taxa_obs_parent_taxa_name(2565, 'Rotifera');
select fix_taxa_obs_parent_taxa_name(5815, 'Arthropoda');
select fix_taxa_obs_parent_taxa_name(6491, 'Annelida');
select fix_taxa_obs_parent_taxa_name(116517, 'Arthropoda');
select fix_taxa_obs_parent_taxa_name(6237, 'Arthropoda');
select fix_taxa_obs_parent_taxa_name(5898, 'Arthropoda');
select fix_taxa_obs_parent_taxa_name(2433, 'Rotifera');