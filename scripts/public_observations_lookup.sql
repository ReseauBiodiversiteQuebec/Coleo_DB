-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- % TABLE observations_efforts_lookup
-- % Links observations with efforts
-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
CREATE TABLE IF NOT EXISTS public.observations_efforts_lookup (
    effort_id integer NOT NULL,
    observation_id bigint NOT NULL,
    CONSTRAINT observations_efforts_lookup_effort_id_fkey FOREIGN KEY (effort_id)
        REFERENCES public.efforts (id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT observations_efforts_lookup_observation_id_fkey FOREIGN KEY (observation_id)
        REFERENCES public.observations (id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);


-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- % TABLE observations_landmarks_lookup
-- % Links observations with landmarks
-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
CREATE TABLE IF NOT EXISTS public.observations_landmarks_lookup (
    landmark_id integer NOT NULL,
    observation_id bigint NOT NULL,
    CONSTRAINT observations_landmarks_lookup_landmark_id_fkey FOREIGN KEY (landmark_id)
        REFERENCES public.landmarks (id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT observations_landmarks_lookup_observation_id_fkey FOREIGN KEY (observation_id)
        REFERENCES public.observations (id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);
