-- -----------------------------------------------------------------------------
-- TABLE api.taxa_source_priority
-- DESCRIPTION Simple priority to order taxa from source
-- -----------------------------------------------------------------------------

DROP TABLE if exists taxa_source_priority;

CREATE TABLE taxa_source_priority (
	source_id integer NOT NULL PRIMARY KEY,
	source_name text NOT NULL,
	priority integer NOT NULL
); 

INSERT INTO taxa_source_priority (source_id, source_name, priority)
VALUES (147, 'VASCAN', 1),
 (11, 'GBIF Backbone Taxonomy', 2),
 (3, 'ITIS', 3),
 (1, 'Catalogue of Life', 4);
