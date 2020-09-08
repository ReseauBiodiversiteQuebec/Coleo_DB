# Structure de l'API et BD Coléo

## Cellules

**Nom de la table** : cells

**Point d'accès** : /api/v1/cells

Champs | Type | Description | Options
------------ | ------------- | ------------- | -------------
name | texte | Nom de la cellule | |
**cell_code** | texte | Code de la cellule | |
**geom** | geometry | Localisation de la cellule | |

***

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

***

## Campagnes

**Nom de la table** : campaigns

**Point d'accès** : /api/v1/campaings

**Inclus dans le résultat** : efforts, environments, devices, lures, landmarks(+thermographs), traps

Champs | Type | Description | Options
------------ | ------------- | ------------- | -------------
**site_id** | texte | Identifiant unique du site attaché à la campagne d'échantillonnage | |
**type** | choix | Le type campagne réalisé | 'végétation', 'végétation_transect', 'sol', 'acoustique', 'phénologie', 'mammifères', 'papilionidés', 'odonates', 'insectes_sol', 'ADNe','zooplancton', 'température_eau', 'température_sol', 'marais_profondeur_température' |
technicians | ARRAY(texte) | Noms des technicien(ne)s | |
opened_at | date | Date d'ouverture de la campagne d'échantillonnage | |
closed_at | date | Date de fermeture de la campagne d'échantillonnage | |
notes | texte | Commentaires | |

***

## Efforts

**Nom de la table** : efforts

**Point d'accès** : /api/v1/efforts

Champs | Type | Description | Options
------------ | ------------- | ------------- | -------------
**campaing_id** | nombre entier | Numéro d'identification de la campagne | |
stratum | choix | Strate de végétation concernée par l'effort d'échantillonage | 'arbres', 'arbustes/herbacées', 'bryophytes' |
time_start | date et heure | Date et heure de début de l'inventaire | |
time_finish | date et heure | Date et heure de fin de l'inventaire | |
samp_surf | nombre décimal| Taille de la surface d'échantillonage | |
samp_surf_unit | choix | Unité de mesure utilisé pour la surface d'échantillonnage | 'cm2', 'm2', 'km2' |
notes | texte | Commentaires | |

***

## Environnements

**Nom de la table** : environments

**Point d'accès** : /api/v1/environments

Champs | Type | Description | Options
------------ | ------------- | ------------- | -------------
**campaing_id** | nombre entier | Numéro d'identification de la campagne | |
wind | choix | Vent en km/h | 'calme (moins de 1 km/h)', 'très légère brise (1 à 5 km/h)', 'légère brise (6 à 11 km/h)', 'petite brise (12 à 19 km/h)', 'jolie brise (20 à 28 km/h)' |
sky | choix | Allure du ciel | 'dégagé (0 à 10 %)', 'nuageux (50 à 90 %)', 'orageux', 'partiellement nuageux (10 à 50 %)', 'pluvieux' |
temp_c | nombre décimal | Date et heure de fin de l'inventaire | |
samp_surf | nombre décimal| Température en celsius | |
samp_surf_unit | choix | Unité de mesure utilisé pour la surface d'échantillonnage | 'cm2', 'm2', 'km2' |
notes | texte | Commentaires | |


***

## Appareils

**Nom de la table** : devices

**Point d'accès** : /api/v1/devices

Champs | Type | Description | Options
------------ | ------------- | ------------- | -------------
**campaing_id** | nombre entier | Numéro d'identification de la campagne | |
sd_card_codes | ARRAY(texte) | Numéro d'identification des cartes SD utilisées |  |
cam_code | ARRAY(texte) | Numéro d'identification de la caméra utilisée |  |
cam_h_cm | nombre décimal | Hauteur de la camera en centimètres | |
mic_logger_code | texte| Numéro d'identification du enregistreur utilisé | |
mic_acc_code | texte | Numéro d'identification du microphone accoustique utilisé | |
mic_h_cm_acc | nombre décimal | Hauteur du microphone ultrason utilisé en centimètres | |
mic_ultra_code | texte | Hauteur du microphone ultrason utilisé en centimètres | |
mic_orientation | choix | Orientation du dispositif | 'n', 's', 'e', 'o', 'ne', 'no', 'se', 'so' | 

***

## Appâts

**Nom de la table** : lures

**Point d'accès** : /api/v1/lures

Champs | Type | Description | Options
------------ | ------------- | ------------- | -------------
lure | nombre entier | Numéro d'identification de la campagne | |
installed_at | date | Date d'installation de l'appât/leurre | |

***

## Pièges

**Nom de la table** : traps

**Point d'accès** : /api/v1/traps

**Inclus dans le résultat** : landmarks, samples.

Champs | Type | Description | Options
------------ | ------------- | ------------- | -------------
trap_code | texte | Code du piège | |
campaign_id | texte | Code d'identification de la campagne | |
notes | texte | Commentaires | |

***

## Repères

**Nom de la table** : landmarks

**Point d'accès** : /api/v1/landmarks

**Inclus dans le résultat** : thermographs

Champs | Type | Description | Options
------------ | ------------- | ------------- | -------------
**campaing_id** | nombre entier | Numéro d'identification de la campagne | |
tree_code | texte | Identifiant unique de l'arbre repère | |
taxa_name | texte | Espèce de l'arbre repère | |
dbh | nombre entier | DHP de l'arbre repère | |
dbh_unit | choix | Unité pour le DHP | 'mm','cm','m' |
axis | choix | L'axe du transect pour la végétation | 'n','se','so' |
azimut | nombre entier | Azimut du dispositif/appât/borne depuis le repère (arbre ou borne), entre 0 et 360 | |
distance | nombre décimal | Distance du dispositif/appât/borne depuis le repère (arbre ou borne) | | 
distance_unit | choix | Distance du dispositif/appât/borne depuis le repère (arbre ou borne) | 'mm','cm','m' |
geom | geometry(POINT) | Position du repère |  |
type | choix |  Type de repère | 'gps', 'arbre', 'gps+arbre', 'borne_axe', 'thermographe' | 
thermograph_type | choix | Type de thermographe | 'eau', 'eau_extérieur', 'sol', 'sol_extérieur', 'puit_marais' |
notes | texte | Commentaires | |

***
## Échantillons

**Nom de la table** : samples

**Point d'accès** : /api/v1/samples

Champs | Type | Description | Options
------------ | ------------- | ------------- | -------------
**sample_code** | texte | Numéro de l'échantillon | |
date_samp | date | Date de collecte de l'échantillon | |
**trap_id** | nombre entier | Numéro d'identification unique du piège | |
notes | texte | Commentaires | |

***

## Thermographs

**Nom de la table** : thermographs

**Point d'accès** : /api/v1/thermographs

Champs | Type | Description | Options
------------ | ------------- | ------------- | -------------
**landmark_id** | nombre entier| Numéro du repère | |
**thermograph_no** | texte | Numéro/code du thermographe | |
depth | nombre décimal | Profondeur dans l'eau ou dans le sol | |
height | nombre décimal | Hauteur pour les thermographes extérieurs | |
is_on_bag | booléen 1/0 | Est-ce le dernier thermographe sur le sac de la chaîne? | |
shading | nombre entier| Ombrage de 1 (aucun ombrage) à 5 (complètement ombragé) | |
notes | texte | Commentaires | |

***

## Observations

**Nom de la table** : observations

**Point d'accès** : /api/v1/observations

**Inclus dans le résultat**: media, obs_soil, obs_species, obs_soil_decomposition

Cette table est la table principale qui contient les informations communes à toutes les observations. Dépendamment du type de campagne, les informations complémentaires sont dans les tables obs_*

Champs | Type | Description | Options
------------ | ------------- | ------------- | -------------
**date_obs** | date | Date d'observation à l'intérieur de la campagne d'inventaire | |
time_obs | heure HH:mm:ss| Heure de l'observation à l'intérieur de la campagne d'inventaire | |
stratum | choix | Strate de végétation inventoriée (spécifique aux campagnes de type végétation) | 'arborescente', 'arbustive', 'herbacées', 'bryophytes' |
axis | choix | L\'axe du transect pour la végétation | 'n','se','so' |
distance | nombre décimal| La distance le long du transect pour la végétation | | 
distance_unit | choix | Unité de mesure utilisé pour la distance le long du transect | |
depth | nombre décimal | Profondeur pour les observations de zooplancton | |
sample_id | nombre entier | numéro de l'échantillon | |
**is_valid** | booléen 1/0 | L'observation est-elle valide?| par défaut: 1 |
**campaing_id** | nombre entier | Numéro d'identification de la campagne | |
**campaing_info** | champs virtuel | Informations sur la campagne | |
thermograph_id | nombre entier | Numéro du thermographe | |
notes | texte | Commentaires | |

***


## Observations d'espèces

**Nom de la table** : obs_species

**Point d'accès** : /api/v1/obs_species

**Inclus dans le résultat**: attributes, ref_species


Champs | Type | Description | Options
------------ | ------------- | ------------- | -------------
**taxa_name** | texte | Nom complet de l'espèce observée | |
**variable** | texte | Référence vers la table t'attributs | |
value | nombre décimal | Valeur de l'attribut | | 
**observation_id** | nombre entier | Identifiant unique de la table d'observations| 

***


## Attributs

**Nom de la table** : attributes

**Point d'accès** : /api/v1/attributes

Champs | Type | Description | Options
------------ | ------------- | ------------- | -------------
**variable** | texte | Nom de la variable attribuée | |
**description** | texte | Description de la variable attribuée | |
unit | texte | Unité de la variable attribuée | |

***

## Observations de la décomposition du sol (sacs de thé)

**Nom de la table** : obs_soil_decomposition

**Point d'accès** : /api/v1/obs_soil_decomposition


Champs | Type | Description | Options
------------ | ------------- | ------------- | -------------
**observation_id** | nombre entier | Numéro de l'observation dans la table observation | |
**bag_no** | texte | Code du sachet de thé | |
type | choix | Type de sachet de thé | 'thé vert', 'rooibos' | 
**observation_id** | nombre entier | Identifiant unique de la table d'observations| |
geom | geometry(POINT) | localisation du sachet | |
date_end | date | Date de la collecte du sachet de thé. La date de l'observation est la date de la mise en place. ||
**start_weight** | nombre décimal | Poids du sachet au départ||
end_weight_with_bag | nombre décimal | Poids avec le sachet à la fin||
end_weight_tea | nombre décimal | Poids sans le sachet à la fin ||
shading | nombre entier | Ombrage 1-5 | 1=Aucun ombrage à  5=Complètement ombragé| 
human_impact | nombre entier |  Impacts anthropique 1-5 | 1=Aucun impact à 5=Beaucoup d'impacts| 

***

## Media

**Nom de la table** : media

**Point d'accès** : /api/v1/attributes

Champs | Type | Description | Options
------------ | ------------- | ------------- | -------------
**type** | choix | Type de média | 'image', 'audio', 'video' | |
**recorder** | choix | Type d'enregistreur | 'ultrasound', 'audible' |
**og_format** | texte | Original format (jpeg, png, etc) | |
**og_extention** | texte | Original extension (.jpg, .png, etc.) | |
**uuid* | texte | UUID, Identifiant unique généré par Coléo | | 
**name** | texte | Nom du fichier original | | 

***

## Table de correspondance - Observation-media

**Nom de la table** : obs_media

**Point d'accès** : /api/v1/obs_media

Champs | Type | Description | Options
------------ | ------------- | ------------- | -------------
**obs_id** | Nombre entier | Identifiant de l'observation | |
**media_id** | Nombre entier | Identifiant du média |  |

***
