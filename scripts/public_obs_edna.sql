-------------------------------------------------------------------------------
-- CREATE public.obs_edna resource
-------------------------------------------------------------------------------
-- DROP TABLE IF EXISTS public.obs_edna;

CREATE TABLE IF NOT EXISTS public.obs_edna
(
    id integer NOT NULL DEFAULT nextval('obs_edna_id_seq'::regclass),
    observation_id integer NOT NULL,
    taxa_name character varying(255) COLLATE pg_catalog."default" NOT NULL,
    sequence_count double precision,
    type_edna enum_obs_edna_type_edna,
    notes text COLLATE pg_catalog."default",
    created_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    sequence_count_corrected double precision,
    id_taxa_obs integer,
    parent_taxa_name text COLLATE pg_catalog."default" DEFAULT ''::text,
    CONSTRAINT obs_edna_pkey PRIMARY KEY (id),
    CONSTRAINT obs_edna_id_taxa_obs_fkey FOREIGN KEY (id_taxa_obs)
        REFERENCES public.taxa_obs (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE NO ACTION,
    CONSTRAINT obs_edna_observation_id_fkey FOREIGN KEY (observation_id)
        REFERENCES public.observations (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.obs_edna
    OWNER to postgres;

REVOKE ALL ON TABLE public.obs_edna FROM coleo_test_user;
REVOKE ALL ON TABLE public.obs_edna FROM read_only_all;
REVOKE ALL ON TABLE public.obs_edna FROM read_only_public;
REVOKE ALL ON TABLE public.obs_edna FROM read_write_all;

GRANT SELECT ON TABLE public.obs_edna TO coleo_test_user;

GRANT ALL ON TABLE public.obs_edna TO glaroc;

GRANT ALL ON TABLE public.obs_edna TO postgres;

GRANT SELECT ON TABLE public.obs_edna TO read_only_all;

GRANT SELECT ON TABLE public.obs_edna TO read_only_public;

GRANT INSERT, TRUNCATE, REFERENCES, TRIGGER, UPDATE, SELECT ON TABLE public.obs_edna TO read_write_all;

COMMENT ON COLUMN public.obs_edna.taxa_name
    IS 'Nom de l''espèce observé';

COMMENT ON COLUMN public.obs_edna.sequence_count
    IS 'Nombre de séquences';

COMMENT ON COLUMN public.obs_edna.type_edna
    IS 'Catégorie d''observation ADNe. ';

COMMENT ON COLUMN public.obs_edna.sequence_count_corrected
    IS 'Nombre de séquences corrigés';
-- Index: obs_edna_id_taxa_obs_idx

-- DROP INDEX IF EXISTS public.obs_edna_id_taxa_obs_idx;

CREATE INDEX IF NOT EXISTS obs_edna_id_taxa_obs_idx
    ON public.obs_edna USING btree
    (id_taxa_obs ASC NULLS LAST)
    TABLESPACE pg_default;

-- Trigger: insert_taxa_obs

-- DROP TRIGGER IF EXISTS insert_taxa_obs ON public.obs_edna;

CREATE TRIGGER insert_taxa_obs
    BEFORE INSERT OR UPDATE 
    ON public.obs_edna
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_insert_taxa_obs_from_obs_edna();

GRANT EXECUTE ON FUNCTION public.trigger_insert_taxa_obs_from_obs_edna() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.trigger_insert_taxa_obs_from_obs_edna() TO coleo_test_user;
GRANT EXECUTE ON FUNCTION public.trigger_insert_taxa_obs_from_obs_edna() TO glaroc;
GRANT EXECUTE ON FUNCTION public.trigger_insert_taxa_obs_from_obs_edna() TO postgres;
GRANT EXECUTE ON FUNCTION public.trigger_insert_taxa_obs_from_obs_edna() TO read_write_all;