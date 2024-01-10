----------------------------------------------------------------------------------------------
-- Introduce correspondance of best_ref with parent taxa in api.taxa
--
-- api.taxa mélange différentes sources pour combler sa taxonomie, ce qui entraine des erreurs 
-- lorsqu'il y a synonimie. Le rang du best_ref doit être conservé dans l'élaboration de api.taxa.
----------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------
-- 1. Fix problematic names that cause api.taxa to reference multiple species within its taxonomy
----------------------------------------------------------------------------------------------

select id_taxa_obs, observed_scientific_name, valid_scientific_name, rank, kingdom, phylum, class, "order", family, genus, species
from api.taxa
where --observed_scientific_name ilike '%Daphnia%'
	rank <> 'species'
	and species is not NULL

-- Unknown Daphnia male
-- 1. update obs_species
update obs_species
set parent_taxa_name = 'Arthropoda',
	taxa_name = 'Daphnia',
	id_taxa_obs = 2368
where taxa_name like 'Unknown Daphnia male'
-- 2. update taxa_obs
update taxa_obs set parent_taxa_name = 'Arthropoda' where id = 2368
delete from taxa_obs where id = 96049

-- Unknown Daphnia female
-- 1. update obs_species
update obs_species
set parent_taxa_name = 'Arthropoda',
	taxa_name = 'Daphnia',
	id_taxa_obs = 2368
where taxa_name like 'Unknown Daphnia female'
-- 2. update taxa_obs
delete from taxa_obs where id = 96049

-- Ceriodaphnia unknown
select *
from obs_species 
where taxa_name ilike 'Ceriodaphnia unknown'
-- 1. update obs_species
select * 
from taxa_obs 
where scientific_name ilike '%Daphnia%'
delete from obs_species where taxa_name like 'Ceriodaphnia unknown'
insert into obs_species (taxa_name, variable, value, observation_id, parent_taxa_name)
	values ('Ceriodaphnia', 'abondance', 1, 558870, 'Arthropoda')
insert into obs_species (taxa_name, variable, value, observation_id, parent_taxa_name)
	values ('Ceriodaphnia', 'abondance', 1, 558883, 'Arthropoda')
insert into obs_species (taxa_name, variable, value, observation_id, parent_taxa_name)
	values ('Ceriodaphnia', 'abondance', 1, 558540, 'Arthropoda')
insert into obs_species (taxa_name, variable, value, observation_id, parent_taxa_name)
	values ('Ceriodaphnia', 'abondance', 1, 558554, 'Arthropoda')
-- 2. update taxa_obs
delete from taxa_obs_ref_lookup where id_taxa_obs in (select id from taxa_obs where scientific_name = 'Ceriodaphnia unknown')
delete from taxa_obs_vernacular_lookup where id_taxa_obs in (select id from taxa_obs where scientific_name = 'Ceriodaphnia unknown')
delete from taxa_obs where scientific_name = 'Ceriodaphnia unknown'

-- Daphnia pulex / pulcaria
select *
from obs_species 
where taxa_name ilike 'Daphnia pulex / pulcaria'
-- 1. update obs_species
update obs_species 
set taxa_name = 'Daphnia pulex | pulcaria',
	updated_at = current_timestamp
where taxa_name like 'Daphnia pulex / pulcaria'
-- 2. update taxa_obs
update taxa_obs 
set scientific_name = 'Daphnia pulex | pulcaria'
where scientific_name like 'Daphnia pulex / pulcaria'

-- Daphnia mendotae / dentifera
select *
from obs_species 
where taxa_name ilike 'Daphnia mendotae / dentifera'
-- 1. update obs_species
update obs_species 
set taxa_name = 'Daphnia mendotae | dentifera',
	updated_at = current_timestamp
where taxa_name like 'Daphnia mendotae / dentifera'
-- 2. update taxa_obs
update taxa_obs 
set scientific_name = 'Daphnia mendotae | dentifera'
where scientific_name like 'Daphnia mendotae / dentifera'



-------------------------------------------------------------------------------
-- REFRESH taxa_ref and taxa_obs_ref_lookup
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION refresh_taxa_ref()
RETURNS void AS
$$
BEGIN
    DELETE FROM public.taxa_obs_ref_lookup;
	DELETE FROM public.taxa_ref;
    PERFORM public.insert_taxa_ref_from_taxa_obs(
        id, scientific_name, parent_taxa_name)
    FROM public.taxa_obs;
END;
$$ LANGUAGE 'plpgsql';


-- LAST
select public.refresh_taxa_ref();
select public.refresh_taxa_vernacular();
REFRESH MATERIALIZED VIEW CONCURRENTLY public.taxa_obs_group_lookup;


----------------------------------------------------------------------------------------------
-- 2. create taxa_rank_order to order taxa_ref by rank
----------------------------------------------------------------------------------------------
 -- Table: public.taxa_rank_order

-- DROP TABLE IF EXISTS public.taxa_rank_order;

CREATE TABLE IF NOT EXISTS public.taxa_rank_order
(
    rank_name text COLLATE pg_catalog."default" NOT NULL,
    "order" integer NOT NULL,
    CONSTRAINT taxa_rank_priority_pkey PRIMARY KEY (rank_name)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.taxa_rank_order
    OWNER to postgres;

REVOKE ALL ON TABLE public.taxa_rank_order FROM coleo_test_user;
REVOKE ALL ON TABLE public.taxa_rank_order FROM read_only_all;
REVOKE ALL ON TABLE public.taxa_rank_order FROM read_only_public;
REVOKE ALL ON TABLE public.taxa_rank_order FROM read_write_all;

GRANT SELECT ON TABLE public.taxa_rank_order TO coleo_test_user;

GRANT ALL ON TABLE public.taxa_rank_order TO glaroc;

GRANT ALL ON TABLE public.taxa_rank_order TO postgres;

GRANT SELECT ON TABLE public.taxa_rank_order TO read_only_all;

GRANT SELECT ON TABLE public.taxa_rank_order TO read_only_public;

GRANT UPDATE, SELECT ON TABLE public.taxa_rank_order TO read_write_all;


-- Insert data
insert into taxa_rank_order (rank_name, "order") values ('kingdom', 1);
insert into taxa_rank_order (rank_name, "order") values ('phylum', 2);
insert into taxa_rank_order (rank_name, "order") values ('class', 3);
insert into taxa_rank_order (rank_name, "order") values ('order', 4);
insert into taxa_rank_order (rank_name, "order") values ('family', 5);
insert into taxa_rank_order (rank_name, "order") values ('genus', 6);
insert into taxa_rank_order (rank_name, "order") values ('species', 7);


----------------------------------------------------------------------------------------------
-- 3. update api.taxa
----------------------------------------------------------------------------------------------
-- View: api.taxa

-- DROP VIEW api.taxa;

CREATE OR REPLACE VIEW api.taxa
 AS
 WITH all_ref AS (
         SELECT obs_lookup.id_taxa_obs,
            taxa_ref.scientific_name AS valid_scientific_name,
            taxa_ref.rank,
            taxa_ref.source_name,
            taxa_ref_sources.source_priority,
            taxa_ref.source_record_id AS source_taxon_key
           FROM taxa_obs_ref_lookup obs_lookup
             LEFT JOIN taxa_ref ON obs_lookup.id_taxa_ref_valid = taxa_ref.id
             JOIN taxa_ref_sources USING (source_id)
          WHERE obs_lookup.match_type IS NOT NULL AND obs_lookup.match_type <> 'complex'::text
          ORDER BY obs_lookup.id_taxa_obs, taxa_ref_sources.source_priority
        ), agg_ref AS (
         SELECT all_ref.id_taxa_obs,
            json_agg(json_build_object('source_name', all_ref.source_name, 'valid_scientific_name', all_ref.valid_scientific_name, 'rank', all_ref.rank, 'source_taxon_key', all_ref.source_taxon_key)) AS source_references
           FROM all_ref
          GROUP BY all_ref.id_taxa_obs
        ), best_ref AS (
         SELECT DISTINCT ON (all_ref.id_taxa_obs) all_ref.id_taxa_obs,
            all_ref.valid_scientific_name,
            all_ref.rank,
			api.taxa_ref_sources.source_priority,
			taxa_rank_order.order as rank_order
           FROM all_ref
             JOIN api.taxa_ref_sources USING (source_name)
			 JOIN taxa_rank_order on all_ref.rank = taxa_rank_order.rank_name
          ORDER BY all_ref.id_taxa_obs, api.taxa_ref_sources.source_priority
        ), obs_group AS (
         SELECT DISTINCT ON (group_lookup.id_taxa_obs) group_lookup.id_taxa_obs,
            COALESCE(taxa_groups.vernacular_en, 'others'::text) AS group_en,
            COALESCE(taxa_groups.vernacular_fr, 'autres'::text) AS group_fr
           FROM taxa_obs_group_lookup group_lookup
             LEFT JOIN taxa_groups ON group_lookup.id_group = taxa_groups.id
          WHERE taxa_groups.level = 1
        ), vernacular_all AS (
         SELECT v_lookup.id_taxa_obs,
            taxa_vernacular.id,
            taxa_vernacular.source_name,
            taxa_vernacular.source_record_id,
            taxa_vernacular.name,
            taxa_vernacular.language,
            taxa_vernacular.gbif_taxon_key,
            taxa_vernacular.created_at,
            taxa_vernacular.modified_at,
            taxa_vernacular.modified_by,
            COALESCE(taxa_vernacular_sources.source_priority, 9999) AS "coalesce",
            v_lookup.match_type,
            COALESCE(v_lookup.rank_order, 9999) AS rank_order
           FROM taxa_obs_vernacular_lookup v_lookup
             LEFT JOIN taxa_vernacular ON v_lookup.id_taxa_vernacular = taxa_vernacular.id
             LEFT JOIN taxa_vernacular_sources USING (source_name)
          WHERE v_lookup.match_type IS NOT NULL AND v_lookup.match_type <> 'complex'::text
          ORDER BY v_lookup.id_taxa_obs, v_lookup.match_type, (COALESCE(v_lookup.rank_order, 9999)) DESC, taxa_vernacular_sources.source_priority
        ), best_vernacular AS (
         SELECT ver_en.id_taxa_obs,
            ver_en.name AS vernacular_en,
            ver_fr.name AS vernacular_fr
           FROM ( SELECT DISTINCT ON (vernacular_all.id_taxa_obs) vernacular_all.id_taxa_obs,
                    vernacular_all.name
                   FROM vernacular_all
                  WHERE vernacular_all.language = 'eng'::text) ver_en
             LEFT JOIN ( SELECT DISTINCT ON (vernacular_all.id_taxa_obs) vernacular_all.id_taxa_obs,
                    vernacular_all.name
                   FROM vernacular_all
                  WHERE vernacular_all.language = 'fra'::text) ver_fr ON ver_en.id_taxa_obs = ver_fr.id_taxa_obs
        ), vernacular_group AS (
         SELECT vernacular_all.id_taxa_obs,
            json_agg(json_build_object('name', vernacular_all.name, 'source', vernacular_all.source_name, 'source_taxon_key', vernacular_all.source_record_id, 'language', vernacular_all.language)) AS vernacular
           FROM vernacular_all
          GROUP BY vernacular_all.id_taxa_obs
        ), ref_all_rank AS (
         SELECT DISTINCT ON (lu.id_taxa_obs, taxa_ref.rank) lu.id_taxa_obs,
            taxa_ref.scientific_name,
            taxa_ref.rank,
			taxa_rank_order.order,
			taxa_ref_sources.source_priority
           FROM taxa_obs taxa_obs_1,
            taxa_ref,
            taxa_obs_ref_lookup lu,
            taxa_ref_sources,
			best_ref,
			taxa_rank_order
          WHERE lu.id_taxa_obs = taxa_obs_1.id AND taxa_ref.id = lu.id_taxa_ref_valid AND taxa_ref.source_name = taxa_ref_sources.source_name AND lu.id_taxa_obs = best_ref.id_taxa_obs AND taxa_ref.rank = taxa_rank_order.rank_name
          ORDER BY lu.id_taxa_obs, taxa_ref.rank, taxa_ref_sources.source_priority
        ), ref_rank AS (
			select ref_all_rank.id_taxa_obs,
				ref_all_rank.scientific_name,
				ref_all_rank.rank,
				ref_all_rank.order,
				best_ref.source_priority,
				best_ref.rank_order best_ref_rank
			from ref_all_rank
			left join best_ref on best_ref.id_taxa_obs = ref_all_rank.id_taxa_obs
			where ref_all_rank.order <= best_ref.rank_order
		), full_taxonomy AS (
         SELECT kingdom.id_taxa_obs,
            kingdom.scientific_name AS kingdom,
            phylum.scientific_name AS phylum,
            class.scientific_name AS class,
            "order".scientific_name AS "order",
            family.scientific_name AS family,
            genus.scientific_name AS genus,
            species.scientific_name AS species
           FROM ( SELECT ref_rank.id_taxa_obs,
                    ref_rank.scientific_name
                   FROM ref_rank
                  WHERE ref_rank.rank = 'kingdom'::text) kingdom
             LEFT JOIN ( SELECT ref_rank.id_taxa_obs,
                    ref_rank.scientific_name
                   FROM ref_rank
                  WHERE ref_rank.rank = 'species'::text) species USING (id_taxa_obs)
             LEFT JOIN ( SELECT ref_rank.id_taxa_obs,
                    ref_rank.scientific_name
                   FROM ref_rank
                  WHERE ref_rank.rank = 'genus'::text) genus USING (id_taxa_obs)
             LEFT JOIN ( SELECT ref_rank.id_taxa_obs,
                    ref_rank.scientific_name
                   FROM ref_rank
                  WHERE ref_rank.rank = 'family'::text) family USING (id_taxa_obs)
             LEFT JOIN ( SELECT ref_rank.id_taxa_obs,
                    ref_rank.scientific_name
                   FROM ref_rank
                  WHERE ref_rank.rank = 'order'::text) "order" USING (id_taxa_obs)
             LEFT JOIN ( SELECT ref_rank.id_taxa_obs,
                    ref_rank.scientific_name
                   FROM ref_rank
                  WHERE ref_rank.rank = 'class'::text) class USING (id_taxa_obs)
             LEFT JOIN ( SELECT ref_rank.id_taxa_obs,
                    ref_rank.scientific_name
                   FROM ref_rank
                  WHERE ref_rank.rank = 'phylum'::text) phylum USING (id_taxa_obs)
        )					
 SELECT best_ref.id_taxa_obs,
    taxa_obs.scientific_name AS observed_scientific_name,
    best_ref.valid_scientific_name,
    best_ref.rank,
    best_vernacular.vernacular_en,
    best_vernacular.vernacular_fr,
    obs_group.group_en,
    obs_group.group_fr,
    vernacular_group.vernacular,
    agg_ref.source_references,
    full_taxonomy.kingdom,
    full_taxonomy.phylum,
    full_taxonomy.class,
    full_taxonomy."order",
    full_taxonomy.family,
    full_taxonomy.genus,
    full_taxonomy.species
   FROM best_ref
     LEFT JOIN taxa_obs ON taxa_obs.id = best_ref.id_taxa_obs
     LEFT JOIN vernacular_group ON best_ref.id_taxa_obs = vernacular_group.id_taxa_obs
     LEFT JOIN obs_group ON best_ref.id_taxa_obs = obs_group.id_taxa_obs
     LEFT JOIN best_vernacular ON best_ref.id_taxa_obs = best_vernacular.id_taxa_obs
     LEFT JOIN agg_ref ON best_ref.id_taxa_obs = agg_ref.id_taxa_obs
     LEFT JOIN full_taxonomy ON best_ref.id_taxa_obs = full_taxonomy.id_taxa_obs
  ORDER BY best_ref.id_taxa_obs, best_vernacular.vernacular_en;