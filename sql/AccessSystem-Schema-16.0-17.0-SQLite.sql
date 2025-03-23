-- Convert schema 'sql/AccessSystem-Schema-16.0-SQLite.sql' to 'sql/AccessSystem-Schema-17.0-SQLite.sql':;

BEGIN;

ALTER TABLE "allowed" ADD COLUMN "inducted_by_id" integer DEFAULT NULL;

CREATE INDEX "allowed_idx_inducted_by_id02" ON "allowed" ("inducted_by_id");


CREATE TEMPORARY TABLE "communications_temp_alter" (
  "person_id" integer NOT NULL,
  "created_on" datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "sent_on" datetime,
  "type" varchar(50) NOT NULL,
  "status" varchar(10) NOT NULL DEFAULT 'unsent',
  "subject" varchar(1024) NOT NULL DEFAULT 'Communication from Swindon Makerspace',
  "plain_text" text NOT NULL,
  "html" text,
  PRIMARY KEY ("person_id", "created_on"),
  FOREIGN KEY ("person_id") REFERENCES "people"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

INSERT INTO "communications_temp_alter"( "person_id", "created_on", "sent_on", "type", "status", "subject", "plain_text", "html") SELECT "person_id", "created_on", "sent_on", "type", "status", "subject", "plain_text", "html" FROM "communications";

DROP TABLE "communications";

CREATE TABLE "communications" (
  "person_id" integer NOT NULL,
  "created_on" datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "sent_on" datetime,
  "type" varchar(50) NOT NULL,
  "status" varchar(10) NOT NULL DEFAULT 'unsent',
  "subject" varchar(1024) NOT NULL DEFAULT 'Communication from Swindon Makerspace',
  "plain_text" text NOT NULL,
  "html" text,
  PRIMARY KEY ("person_id", "created_on"),
  FOREIGN KEY ("person_id") REFERENCES "people"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "communications_idx_person_id03" ON "communications" ("person_id");

INSERT INTO "communications" SELECT "person_id", "created_on", "sent_on", "type", "status", "subject", "plain_text", "html" FROM "communications_temp_alter";

DROP TABLE "communications_temp_alter";


COMMIT;


