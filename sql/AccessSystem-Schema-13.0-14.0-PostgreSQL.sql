-- Convert schema 'sql/AccessSystem-Schema-13.0-PostgreSQL.sql' to 'sql/AccessSystem-Schema-14.0-PostgreSQL.sql':;

BEGIN;

ALTER TABLE communications DROP CONSTRAINT communications_pkey;

ALTER TABLE communications ADD COLUMN created_on timestamp NOT NULL;

ALTER TABLE communications ADD COLUMN subject character varying(1024) DEFAULT 'Communication from Swindon Makerspace' NOT NULL;

ALTER TABLE communications RENAME COLUMN content TO plain_text;

ALTER TABLE communications ADD COLUMN html character varying(10240);

ALTER TABLE communications ALTER COLUMN sent_on DROP NOT NULL;

ALTER TABLE communications ALTER COLUMN status SET DEFAULT 'unsent';

ALTER TABLE communications ADD PRIMARY KEY (person_id, type);


COMMIT;


