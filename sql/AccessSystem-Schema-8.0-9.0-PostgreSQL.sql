-- Convert schema './AccessSystem-Schema-8.0-PostgreSQL.sql' to './AccessSystem-Schema-9.0-PostgreSQL.sql':;

BEGIN;

CREATE TABLE "confirmations" (
  "person_id" integer NOT NULL,
  "token" character varying(36) NOT NULL,
  "storage" character varying(1024) NOT NULL,
  PRIMARY KEY ("token")
);
CREATE INDEX "confirmations_idx_person_id" on "confirmations" ("person_id");

ALTER TABLE "confirmations" ADD CONSTRAINT "confirmations_fk_person_id" FOREIGN KEY ("person_id")
  REFERENCES "people" ("id") ON DELETE cascade ON UPDATE cascade DEFERRABLE;

ALTER TABLE people ADD CONSTRAINT telegram_id UNIQUE (telegram_chatid);

ALTER TABLE tool_status ALTER COLUMN tool_id TYPE character varying(40);


COMMIT;


