-- Convert schema './AccessSystem-Schema-5.0-PostgreSQL.sql' to './AccessSystem-Schema-6.0-PostgreSQL.sql':;

BEGIN;

CREATE TABLE "transactions" (
  "person_id" integer NOT NULL,
  "added_on" timestamp NOT NULL,
  "amount_p" integer NOT NULL,
  "reason" character varying(255) NOT NULL,
  PRIMARY KEY ("person_id", "added_on")
);
CREATE INDEX "transactions_idx_person_id" on "transactions" ("person_id");

ALTER TABLE "transactions" ADD CONSTRAINT "transactions_fk_person_id" FOREIGN KEY ("person_id")
  REFERENCES "people" ("id") ON DELETE cascade ON UPDATE cascade DEFERRABLE;

ALTER TABLE allowed ALTER COLUMN is_admin TYPE boolean;

ALTER TABLE people ALTER COLUMN opt_in TYPE boolean;

ALTER TABLE people ALTER COLUMN member_of_other_hackspace TYPE boolean;


COMMIT;


