-- Convert schema './AccessSystem-Schema-8.0-SQLite.sql' to './AccessSystem-Schema-9.0-SQLite.sql':;

BEGIN;

CREATE TABLE "confirmations" (
  "person_id" integer NOT NULL,
  "token" varchar(36) NOT NULL,
  "storage" varchar(1024) NOT NULL,
  PRIMARY KEY ("token"),
  FOREIGN KEY ("person_id") REFERENCES "people"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "confirmations_idx_person_id" ON "confirmations" ("person_id");

CREATE UNIQUE INDEX "telegram_id02" ON "people" ("telegram_chatid");

CREATE TEMPORARY TABLE "tool_status_temp_alter" (
  "id" INTEGER PRIMARY KEY NOT NULL,
  "tool_id" varchar(40) NOT NULL,
  "entered_at" datetime NOT NULL,
  "who_id" integer NOT NULL,
  "status" varchar(20) NOT NULL,
  "description" varchar(1024) NOT NULL,
  FOREIGN KEY ("tool_id") REFERENCES "tools"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY ("who_id") REFERENCES "people"("id")
);

INSERT INTO "tool_status_temp_alter"( "id", "tool_id", "entered_at", "who_id", "status", "description") SELECT "id", "tool_id", "entered_at", "who_id", "status", "description" FROM "tool_status";

DROP TABLE "tool_status";

CREATE TABLE "tool_status" (
  "id" INTEGER PRIMARY KEY NOT NULL,
  "tool_id" varchar(40) NOT NULL,
  "entered_at" datetime NOT NULL,
  "who_id" integer NOT NULL,
  "status" varchar(20) NOT NULL,
  "description" varchar(1024) NOT NULL,
  FOREIGN KEY ("tool_id") REFERENCES "tools"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY ("who_id") REFERENCES "people"("id")
);

CREATE INDEX "tool_status_idx_tool_id03" ON "tool_status" ("tool_id");

CREATE INDEX "tool_status_idx_who_id03" ON "tool_status" ("who_id");

INSERT INTO "tool_status" SELECT "id", "tool_id", "entered_at", "who_id", "status", "description" FROM "tool_status_temp_alter";

DROP TABLE "tool_status_temp_alter";


COMMIT;


