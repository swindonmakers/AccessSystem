-- Convert schema 'sql/AccessSystem-Schema-14.0-PostgreSQL.sql' to 'sql/AccessSystem-Schema-15.0-PostgreSQL.sql':;

BEGIN;

CREATE TABLE "vehicles" (
  "person_id" integer NOT NULL,
  "plate_reg" character varying(7) NOT NULL,
  "added_on" timestamp NOT NULL,
  PRIMARY KEY ("person_id", "plate_reg")
);
CREATE INDEX "vehicles_idx_person_id" on "vehicles" ("person_id");

ALTER TABLE "vehicles" ADD CONSTRAINT "vehicles_fk_person_id" FOREIGN KEY ("person_id")
  REFERENCES "people" ("id") ON DELETE cascade ON UPDATE cascade DEFERRABLE;

ALTER TABLE communications ALTER COLUMN created_on SET DEFAULT 'CURRENT_TIMESTAMP';

ALTER TABLE communications ALTER COLUMN html TYPE character varying(10240);


COMMIT;


