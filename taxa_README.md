## Features

* **Raw observed taxonomic entry stored as-is**. Minimal maintenance of stored taxon database and taxon entries overhead operation (validation, correction) is allowed by storing raw taxon values as-is. All corrected and validated referenced taxonomic entries are found through fuzzy matching and stored independently.
* **Taxon accepted for all ranks** : Observation may be be related to an organism identified at many different levels ie. `species`, `genus`, `family` depending on the type of survey. All taxonomic entries may be ingested into the observed taxon table regardless of their rank and will be related to their referenced taxons.
* **Fuzzy matching** : Raw taxon are matched to entries in reference taxonomic databases using fuzzy matching, thus correcting for orthographic or casing error.
* **Unresolved entry** : If a raw taxonomic entry cannot be matched, closest taxonomic parent reference will be obtained and related if possible. 
* **Multiple and conflicting taxonomic sources** : Raw taxons are matched to their referenced counterparts from multiple taxonomic databases. These matches allows for use of specialized databases or conflicting ones. They are stored without priority, making it possible to reference a raw taxon and related observation through any names obtained through conflicting reference database.
* **Parent-children taxonomic relationship** : Search taxons and related observations through parent taxons possible through stored reference taxons for parents and relationship to raw entry. ie. Parent taxon class `Aves` can be related to all children species taxon entries `Cyanocitta cristata`, `Falco peregrinus`, etc.
* **Revised taxon and valid synonym :** Raw taxon whose valid reference named has changed are matched to both deprecated references and valid ones, making it possible to search raw taxons and related observation and event through either one.
* **Updating and change in reference taxonomic database** : Updates to the validity of a taxonomic entry is possible through periodic update of references obtained from raw taxon entries. Raw taxons are thus stored and maintained as described in original sources and surveys

* **Vernacular names** : A list of vernacular names (*fr* & *en*) are found for each reference taxons (parents, synonyms) related to a raw taxon and for a number of reference vernacular databases.

* **Complex observation** : When the taxon related to an observation is complex, such as multiple organism are identified for the same observation(*Species 1 | Species 2 | Species 3*), a single observed taxonomic entry is injected as such. References will be obtained for each single organism listed by the complex and all related parents. References matched from complex observed taxons are identified as such and can then be included or discarded from queries performed by the user. Common parent taxon are identified as such and can be used to query complex observed taxons.

## Principles

* Raw observed taxons are stored as is as rows in table `taxa_obs`, no orthographic correction nor validation of values is required. It's primary key `id_taxa_obs` is used to be related to tables
* A list of reference taxons (parent, valid synonym) are found for each raw taxon and for a number of taxonomic reference databases through fuzzy match based on the `Global names` and `GBIF` taxononomic backbone API. All reference taxons are stored in table `taxa_ref` and may be related to observed raw `taxa_obs` rows through `taxa_obs_ref_lookup` lookup table.
* A list of vernacular names (*fr* & *en*) are found for each reference taxons (parents, synonyms) related to a raw taxons and for a number of reference vernacular databases through the `GBIF` taxononomic backbone API. All vernacular taxons are stored in table `taxa_vernacular` and may be related to observe `taxa_obs` rows through `taxa_obs_vernacular_lookup` lookup table.



## Common workflows and procedures

### Ingesting entries with related taxa attributes

Example. Insert rows in `obs_species` related to taxa attributes

#### Process summary

* User : Inject raw species observation rows in `TABLE obs_species`
* Auto : Trigger is called on inject.
  * Row in `TABLE taxa_obs` is injected from `taxa_name` in `obs_species`
  * Field `id_tax_obs` in `TABLE obs_species` is updated before injection
  * `FUNCTION match_taxa_sources(taxa_name)` is called to obtain related reference taxonomy entries (synonyms, parents)
  * Reference taxonomic entries are injected into `TABLE taxa_ref`
  * Correspondence between raw observed taxon and related reference taxons are injected into `TABLE taxa_obs_ref_lookup`


#### SQL Command

```postgresql
INSERT INTO obs_species (taxa_name, variable, value, observation_id)
VALUES (...)
```

### List species related to observations

#### Process summary

* User : Query required observations using filters (site, campaign if required)
* User : Join `api.taxa` using the `id_taxa_obs` foreign key

#### SQL Command examples

Observed taxons using `api.taxa` attributes (scientific name, group name, vernacular names, rank, etc).

```postgresql
SELECT taxa.*
FROM api.taxa
```



List observed species using `api.taxa` attributes (scientific name, group name, vernacular names, rank, etc)

```postgresql
SELECT taxa.*
FROM api.taxa WHERE rank = 'species'
```



Listing observed species by site, site_type, campaigns, cells with `api.taxa` attributes (scientific name, group name, vernacular names, rank, etc).

```postgresql
select * from api.taxa_surveyed
where site_type = 'forestier' -- May also use : site_id, site_code, site_type, cell_code, campaign_id, campaign_type
and rank = 'species'
```



Listing observed richness for by site, site_type, campaigns, cells (etc). This function returns all distinct valid taxa name that is not a parent of any observed taxa, thus where all taxa equals 1 organism, regardless of their rank if they satisfy previous criterias.

```postgresql
-- api.taxa_richness(cell_id integer, cell_code text, site_id integer, site_code text, site_type text, campaign_id integer, campaign_type text)
select api.taxa_richness(NULL, NULL, NULL, NULL, 'forestier', NULL, NULL)
```



## IMPORTANT NOTES

* `ALTER TABLE public.obs_species DROP CONSTRAINT obs_species_taxa_name_fkey;`

* ```
  select *                                     
  from taxa_obs
  where id not in (
  select id_taxa_obs from taxa_obs_ref_lookup)
  ;
    id  | scientific_name |          created_at          
  ------+-----------------+------------------------------
   2380 | sphaigne verte  | 2022-04-07 17:14:09.45303-04
   2658 | pellie sp.      | 2022-04-07 17:14:09.45303-04
   5934 | Maccafertium    | 2022-08-17 18:06:51.7358-04
   5986 | Caecidota       | 2022-08-17 18:06:51.7358-04
   6277 | Callophrus      | 2022-08-17 18:06:51.7358-04
  (5 rows)
  ```

* No index on columns from `cells`, `sites`, `campaigns`, etc.

* No complex are listed through API endpoints. However, their closest common parents are.

* TODO

  * [ ] What's up with l'aulne rugueux
  * [ ] api.taxa disctint on id_taxa_obs ? Grouper les sources conflictuelles dans le json
  * [ ] `Bezzia|Palpomyia` is observed, should not because, to be fixed
