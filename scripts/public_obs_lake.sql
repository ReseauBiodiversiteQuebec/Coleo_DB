-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- % TABLE public.obs_lake
-- % Metrics for lake physicochimie
-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
CREATE TABLE IF NOT EXISTS public.obs_lake (
    id SERIAL NOT NULL,
    observation_id INTEGER NOT NULL,
    water_transparency DOUBLE PRECISION,
    water_temp DOUBLE PRECISION,
    oxygen_concentration DOUBLE PRECISION,
    pH DOUBLE PRECISION,
    conductivity DOUBLE PRECISION,
    turbidity DOUBLE PRECISION,
    dissolved_organic_carbon DOUBLE PRECISION,
    ammonia_nitrogen DOUBLE PRECISION,
    nitrates_and_nitrites DOUBLE PRECISION,
    total_nitrogen DOUBLE PRECISION,
    total_phosphorus DOUBLE PRECISION,
    chlorophyl_a DOUBLE PRECISION,
    pheophytin_a DOUBLE PRECISION,
    notes text COLLATE pg_catalog."default",
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    CONSTRAINT obs_lake_pkey PRIMARY KEY (id),
    CONSTRAINT observations_id_fkey FOREIGN KEY (observation_id)
        REFERENCES public.observations (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.obs_soil
    OWNER to postgres;

REVOKE ALL ON TABLE public.obs_lake FROM read_write_all;

GRANT ALL ON TABLE public.obs_lake TO postgres;

GRANT SELECT ON TABLE public.obs_lake TO read_only_all;

GRANT UPDATE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE public.obs_lake TO read_write_all;

COMMENT ON COLUMN public.obs_lake.water_transparency
    IS 'Transparence dans la colonne d''eau exprimée en mètres à l''aide d''un disque de Secchi';
    
COMMENT ON COLUMN public.obs_lake.water_temp
    IS 'Température de l''eau en degrés Celsius';

COMMENT ON COLUMN public.obs_lake.oxygen_concentration
    IS 'Concentration de l''oxygène dans l''eau (mg/L)';

COMMENT ON COLUMN public.obs_lake.pH
    IS 'Mesure du pH de l''eau';

COMMENT ON COLUMN public.obs_lake.conductivity
    IS 'Conductivité de l''eau en mètres/seconde (m/s)';

COMMENT ON COLUMN public.obs_lake.turbidity
    IS 'Turbidité de l''eau en unités de turbidité néphalométriques (uNT)';

COMMENT ON COLUMN public.obs_lake.dissolved_organic_carbon
    IS 'Carbone organique dissous (filtré 0,45 µm)';

COMMENT ON COLUMN public.obs_lake.ammonia_nitrogen
    IS 'Azote ammonical (filtré ou non)';

COMMENT ON COLUMN public.obs_lake.nitrates_and_nitrites
    IS 'Nitrates et nitrites (filtré ou non)';

COMMENT ON COLUMN public.obs_lake.total_nitrogen
    IS 'Azote total (filtré ou non)';

COMMENT ON COLUMN public.obs_lake.total_phosphorus
    IS 'Phosphore total en trace lac 660 nm ou 660 nm verre';

COMMENT ON COLUMN public.obs_lake.chlorophyl_a
    IS 'Chlorophyle A active';

COMMENT ON COLUMN public.obs_lake.pheophytin_a
    IS 'Phéophytine A';

COMMENT ON COLUMN public.obs_lake.notes
    IS 'Notes sur l''observation en lac';
