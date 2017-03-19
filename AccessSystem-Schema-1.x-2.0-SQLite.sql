-- Convert schema './AccessSystem-Schema-1.x-SQLite.sql' to './AccessSystem-Schema-2.0-SQLite.sql':;

BEGIN;

CREATE TABLE "login_tokens" (
  "person_id" integer NOT NULL,
  "login_token" varchar(36) NOT NULL,
  PRIMARY KEY ("person_id", "login_token"),
  FOREIGN KEY ("person_id") REFERENCES "people"("id")
);

CREATE INDEX "login_tokens_idx_person_id" ON "login_tokens" ("person_id");


COMMIT;


