SELECT refresh_taxa_ref();
SELECT refresh_taxa_vernacular();
REFRESH MATERIALIZED VIEW CONCURRENTLY public.taxa_obs_group_lookup;
REFRESH MATERIALIZED VIEW api.taxa;