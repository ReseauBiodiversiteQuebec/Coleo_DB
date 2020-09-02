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
notes | texte | Commentaires | |


## Campagnes

**Nom de la table** : campaigns

**Point d'accès** : /api/v1/campaings

**Inclus dans le résultat** : efforts, environments, devices, lures, landmarks(+thermographs), traps

Champs | Type | Description | Options
------------ | ------------- | ------------- | -------------
**site_id** | texte | Identifiant unique du site attaché à la campagne d'échantillonnage | |
**type** | choix | | 'végétation', 'végétation_transect', 'sol', 'acoustique', 'phénologie', 'mammifères', 'papilionidés', 'odonates', 'insectes_sol', 'ADNe','zooplancton', 'température_eau', 'température_sol', 'marais_profondeur_température' |
technicians | ARRAY(texte) | Noms des technicien(ne)s | |
opened_at | date | Date d'ouverture de la campagne d'échantillonnage | |
closed_at | date | Date de fermeture de la campagne d'échantillonnage | |
notes | texte | Commentaires | |
