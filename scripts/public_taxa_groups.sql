-- -----------------------------------------------------------------------------
-- TABLE taxa_groups
-- DESCRIPTION Contains taxonomic group definition
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS public.taxa_groups CASCADE;
CREATE TABLE public.taxa_groups (
    id serial primary key,
    vernacular_fr text,
    vernacular_en text,
    level integer
);

COPY public.taxa_groups (id, vernacular_fr, vernacular_en, level) FROM stdin;
1	amphibiens	amphibians	1
2	oiseaux	birds	1
3	mammifères	mammals	1
4	reptiles	reptiles	1
5	poissons	fish	1
6	plantes	plants	1
7	arthropodes	arthropods	1
8	mollusques	mollusca	1
9	autres	others	1
\.

-- -----------------------------------------------------------------------------
-- TABLE taxa_group_members
-- DESCRIPTION Specifies list of highest ranking taxon common to members
--   of the taxonomic group
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS public.taxa_group_members CASCADE;
CREATE TABLE public.taxa_group_members (
    id_group serial,
    scientific_name text
);

CREATE INDEX IF NOT EXISTS taxa_group_members_scientific_name_idx
ON public.taxa_group_members (scientific_name);

COPY public.taxa_group_members (id_group, scientific_name) FROM stdin;
1	Amphibia
2	Aves
3	Mammalia
4	Reptilia
5	Actinopterygii
5	Cephalaspidomorphi
5	Elasmobranchii
5	Holocephali
5	Myxini
5	Sarcopterygii
6	Plantae
7	Arthropoda
8	Mollusca
\.

-- -----------------------------------------------------------------------------
-- TABLE taxa_obs_group_lookup
-- DESCRIPTION lookup table between taxa_groups and taxa_obs
-- -----------------------------------------------------------------------------

    DROP VIEW IF EXISTS public.taxa_obs_group_lookup CASCADE;
    CREATE VIEW public.taxa_obs_group_lookup AS (
        select distinct
            obs_lookup.id_taxa_obs, group_m.id_group
        from public.taxa_group_members group_m
        left join public.taxa_ref
            on group_m.scientific_name = taxa_ref.scientific_name
        left join public.taxa_obs_ref_lookup obs_lookup
            on taxa_ref.id = obs_lookup.id_taxa_ref
    );