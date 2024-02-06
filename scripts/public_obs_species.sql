-------------------------------------------------------------------------------
-- CREATE public.obs_species resource
-------------------------------------------------------------------------------
-- DROP TABLE IF EXISTS public.obs_species;

CREATE TABLE IF NOT EXISTS public.obs_species
(
    id integer NOT NULL DEFAULT nextval('obs_species_id_seq'::regclass),
    taxa_name character varying(255) COLLATE pg_catalog."default" NOT NULL,
    variable character varying(255) COLLATE pg_catalog."default" NOT NULL,
    value double precision,
    observation_id integer,
    created_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_taxa_obs integer,
    value_string character varying(100) COLLATE pg_catalog."default",
    parent_taxa_name text COLLATE pg_catalog."default" DEFAULT ''::text,
    CONSTRAINT obs_species_pkey PRIMARY KEY (id),
    CONSTRAINT obs_species_id_taxa_obs_fkey FOREIGN KEY (id_taxa_obs)
        REFERENCES public.taxa_obs (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE NO ACTION,
    CONSTRAINT obs_species_observation_id_fkey FOREIGN KEY (observation_id)
        REFERENCES public.observations (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT obs_species_variable_fkey FOREIGN KEY (variable)
        REFERENCES public.attributes (variable) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.obs_species
    OWNER to postgres;

REVOKE ALL ON TABLE public.obs_species FROM coleo_remote;
REVOKE ALL ON TABLE public.obs_species FROM coleo_test_user;
REVOKE ALL ON TABLE public.obs_species FROM read_only_all;
REVOKE ALL ON TABLE public.obs_species FROM read_only_public;
REVOKE ALL ON TABLE public.obs_species FROM read_write_all;

GRANT SELECT ON TABLE public.obs_species TO coleo_remote;

GRANT SELECT ON TABLE public.obs_species TO coleo_test_user;

GRANT ALL ON TABLE public.obs_species TO glaroc;

GRANT ALL ON TABLE public.obs_species TO postgres;

GRANT SELECT ON TABLE public.obs_species TO read_only_all;

GRANT SELECT ON TABLE public.obs_species TO read_only_public;

GRANT INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.obs_species TO read_write_all;

COMMENT ON COLUMN public.obs_species.taxa_name
    IS 'Code de l''espèce observé';

COMMENT ON COLUMN public.obs_species.variable
    IS 'Référence vers la table d''attributs';

COMMENT ON COLUMN public.obs_species.value
    IS 'Valeur de l''attribut';

COMMENT ON COLUMN public.obs_species.observation_id
    IS 'Identifiant unique de la table observation';

COMMENT ON COLUMN public.obs_species.value_string
    IS 'Valeur de l''attribut en format caractère';
-- Index: obs_species_id_taxa_obs_idx

-- DROP INDEX IF EXISTS public.obs_species_id_taxa_obs_idx;

CREATE INDEX IF NOT EXISTS obs_species_id_taxa_obs_idx
    ON public.obs_species USING btree
    (id_taxa_obs ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: obs_species_taxa_name_idx

-- DROP INDEX IF EXISTS public.obs_species_taxa_name_idx;

CREATE INDEX IF NOT EXISTS obs_species_taxa_name_idx
    ON public.obs_species USING btree
    (taxa_name COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;

-- Trigger: insert_taxa_obs

-- DROP TRIGGER IF EXISTS insert_taxa_obs ON public.obs_species;

CREATE TRIGGER insert_taxa_obs
    BEFORE INSERT
    ON public.obs_species
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_insert_taxa_obs_from_obs_species();