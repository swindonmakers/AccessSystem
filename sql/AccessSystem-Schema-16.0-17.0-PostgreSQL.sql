-- Convert schema 'sql/AccessSystem-Schema-16.0-PostgreSQL.sql' to 'sql/AccessSystem-Schema-17.0-PostgreSQL.sql':;

BEGIN;

ALTER TABLE allowed ADD COLUMN inducted_by_id integer DEFAULT NULL;

CREATE INDEX allowed_idx_inducted_by_id on allowed (inducted_by_id);

ALTER TABLE allowed ADD CONSTRAINT allowed_fk_inducted_by_id FOREIGN KEY (inducted_by_id)
  REFERENCES people (id) DEFERRABLE;

ALTER TABLE communications DROP CONSTRAINT communications_pkey;

ALTER TABLE communications ALTER COLUMN plain_text TYPE text;

ALTER TABLE communications ALTER COLUMN html TYPE text;

ALTER TABLE communications ADD PRIMARY KEY (person_id, created_on);


COMMIT;


