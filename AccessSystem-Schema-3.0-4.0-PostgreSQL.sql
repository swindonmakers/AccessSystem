-- Convert schema './AccessSystem-Schema-3.0-PostgreSQL.sql' to './AccessSystem-Schema-4.0-PostgreSQL.sql':;

BEGIN;

CREATE TABLE "membership_register" (
  "name" character varying(255) NOT NULL,
  "address" character varying(1024) NOT NULL,
  "started_date" timestamp NOT NULL,
  "ended_date" timestamp,
  "updated_date" timestamp,
  "updated_reason" character varying(1024) NOT NULL,
  PRIMARY KEY ("name", "started_date")
);

ALTER TABLE people ADD COLUMN analytics_use boolean DEFAULT '0' NOT NULL;

ALTER TABLE usage_log DROP CONSTRAINT usage_log_fk_person_id;

ALTER TABLE usage_log ADD CONSTRAINT usage_log_fk_person_id FOREIGN KEY (person_id)
  REFERENCES people (id) ON DELETE cascade ON UPDATE cascade DEFERRABLE;


COMMIT;


