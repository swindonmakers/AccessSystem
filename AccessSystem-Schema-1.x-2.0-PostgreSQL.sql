-- Convert schema './AccessSystem-Schema-1.x-PostgreSQL.sql' to './AccessSystem-Schema-2.0-PostgreSQL.sql':;

BEGIN;

CREATE TABLE "login_tokens" (
  "person_id" integer NOT NULL,
  "login_token" character varying(36) NOT NULL,
  PRIMARY KEY ("person_id", "login_token")
);
CREATE INDEX "login_tokens_idx_person_id" on "login_tokens" ("person_id");

ALTER TABLE "login_tokens" ADD CONSTRAINT "login_tokens_fk_person_id" FOREIGN KEY ("person_id")
  REFERENCES "people" ("id") DEFERRABLE;


COMMIT;


