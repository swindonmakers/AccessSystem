-- Convert schema 'sql/AccessSystem-Schema-13.0-SQLite.sql' to 'sql/AccessSystem-Schema-14.0-SQLite.sql':;

BEGIN;

CREATE TEMPORARY TABLE "communications_temp_alter" (
  "person_id" integer NOT NULL,
  "created_on" datetime NOT NULL  DEFAULT CURRENT_TIMESTAMP,
  "sent_on" datetime,
  "type" varchar(50) NOT NULL,
  "status" varchar(10) NOT NULL DEFAULT 'unsent',
  "subject" varchar(1024) NOT NULL DEFAULT 'Communication from Swindon Makerspace',
  "plain_text" varchar(10240) NOT NULL,
  "html" varchar(10240),
  PRIMARY KEY ("person_id", "type"),
  FOREIGN KEY ("person_id") REFERENCES "people"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

INSERT INTO "communications_temp_alter"( "person_id", "sent_on", "type", "status", "plain_text") SELECT "person_id", "sent_on", "type", "status", "content"  FROM "communications";

DROP TABLE "communications";

CREATE TABLE "communications" (
  "person_id" integer NOT NULL,
  "created_on" datetime NOT NULL  DEFAULT CURRENT_TIMESTAMP,
  "sent_on" datetime,
  "type" varchar(50) NOT NULL,
  "status" varchar(10) NOT NULL DEFAULT 'unsent',
  "subject" varchar(1024) NOT NULL DEFAULT 'Communication from Swindon Makerspace',
  "plain_text" varchar(10240) NOT NULL,
  "html" varchar(10240),
  PRIMARY KEY ("person_id", "type"),
  FOREIGN KEY ("person_id") REFERENCES "people"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "communications_idx_person_id03" ON "communications" ("person_id");

INSERT INTO "communications" SELECT "person_id", "created_on", "sent_on", "type", "status", "subject", "plain_text", "html" FROM "communications_temp_alter";

DROP TABLE "communications_temp_alter";


COMMIT;


