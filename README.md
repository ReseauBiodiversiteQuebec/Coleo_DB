# Coleo_DB

## API endpoints

**FUNCTION** `api.taxa_abundance(group_by_column text, cell_id_filter integer, cell_code_filter text, site_id_filter integer, site_code_filter text, site_type_filter text, campaign_id_filter integer, campaign_type_filter text)`

Returns a table with the sum of observation values from `obs_species` for each taxon, grouped by the column name specified as parameter and filtered by column values. The column names accepted can be any of : `site_id`, `site_type`, `site_code`, `campaign_id`, `campaign_type`, `cell_id`, `cell_code`.