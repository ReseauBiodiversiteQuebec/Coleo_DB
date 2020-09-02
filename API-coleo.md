# Structure de l'API et BD Coléo

## Cells

**Nom de la table** : cells
**Point d'accès** : /api/v1/cells

Champs | Type | Description | Options
------------ | ------------- | ------------- | -------------
name | texte | Nom de la cellule | |
**cell_code** | texte | Code de la cellule | |
**geom** | geometry | Localisation de la cellule | |

## Sites

**Nom de la table** : sites
**Point d'accès** : /api/v1/sites

Champs | Type | Description | Options
------------ | ------------- | ------------- | -------------
**cell_id** | nombre entier | Identifiant de la cellule | |
off_station_code_id | texte |  | |
**site_code** | texte | Identifiant unique du site | |
**type** | choix | Type d'inventaire réalisé sur le site | 'lac', 'rivière', 'forestier', 'marais', 'marais côtier', 'toundrique', 'tourbière' |
**opened_at** | date | Date de l'ouverture du site | |
**geom** | geometry | Localisation du site | |
