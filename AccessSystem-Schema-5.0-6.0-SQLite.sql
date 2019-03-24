-- Convert schema './AccessSystem-Schema-5.0-SQLite.sql' to './AccessSystem-Schema-6.0-SQLite.sql':;

BEGIN;

CREATE TABLE "transactions" (
  "person_id" integer NOT NULL,
  "added_on" timestamp NOT NULL,
  "amount_p" integer NOT NULL,
  "reason" varchar(255) NOT NULL,
  PRIMARY KEY ("person_id", "added_on"),
  FOREIGN KEY ("person_id") REFERENCES "people"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "transactions_idx_person_id" ON "transactions" ("person_id");


COMMIT;


