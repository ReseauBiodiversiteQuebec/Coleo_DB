# Coleo_DB

## API endpoints

**FUNCTION** `api.taxa_abundance(group_by_column text, cell_id_filter integer, cell_code_filter text, site_id_filter integer, site_code_filter text, site_type_filter text, campaign_id_filter integer, campaign_type_filter text)`

Returns a table with the sum of observation values from `obs_species` and `obs_edna` for each taxon, grouped by the column name specified as parameter and filtered by column values. The column names accepted can be any of : `site_id`, `site_type`, `site_code`, `campaign_id`, `campaign_type`, `cell_id`, `cell_code`.

All parameters are optionals and can be used in any combination. If no parameter is specified, the function will return the total abundance.

**FUNCTION** `api.taxa_abundance_year

Returns the same table, expect the abundance is returned for each year of the campaigns. 

**FUNCTION** `api.taxa_richness(group_by_column text, cell_id_filter integer, cell_code_filter text, site_id_filter integer, site_code_filter text, site_type_filter text, campaign_id_filter integer, campaign_type_filter text)`

Returns a table with the number of validated and unique taxa, based on the tip of the branch method, from both `obs_species` and `obs_edna` grouped by the column name specified as parameter and filtered by column values. The column names accepted can be any of : `site_id`, `site_type`, `site_code`, `campaign_id`, `campaign_type`, `cell_id`, `cell_code`.

All parameters are optionals and can be used in any combination. If no parameter is specified, the function will return the total richness.

**FUNCTION** `api.taxa_richness_year

Returns the same table, expect the richness is returned for each year of the campaigns. 
