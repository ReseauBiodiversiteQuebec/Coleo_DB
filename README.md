# Coleo_DB

## API endpoints

**FUNCTION** `api.taxa_abundance(column_name)`

Returns a table with the sum of observation values  from `obs_species` for each taxon, grouped by the column name specified as parameter. The column name accepted can be any of : `site_id`, `site_type`, `site_code`, `campaign_id`, `campaign_type`, `cell_id`, `cell_code`.