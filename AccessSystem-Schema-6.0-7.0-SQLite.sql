-- Convert schema './AccessSystem-Schema-6.0-SQLite.sql' to './AccessSystem-Schema-7.0-SQLite.sql':;

BEGIN;

CREATE TABLE "tool_status" (
  "id" INTEGER PRIMARY KEY NOT NULL,
  "tool_id" integer NOT NULL,
  "entered_at" datetime NOT NULL,
  "who_id" integer NOT NULL,
  "status" varchar(20) NOT NULL,
  "description" varchar(1024) NOT NULL,
  FOREIGN KEY ("tool_id") REFERENCES "tools"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY ("who_id") REFERENCES "people"("id")
);

CREATE INDEX "tool_status_idx_tool_id" ON "tool_status" ("tool_id");

CREATE INDEX "tool_status_idx_who_id" ON "tool_status" ("who_id");

CREATE TABLE "tools" (
  "id" varchar(40) NOT NULL,
  "name" varchar(255) NOT NULL,
  "assigned_ip" varchar(15),
  "requires_induction" boolean NOT NULL DEFAULT 0,
  "team" varchar(50) NOT NULL DEFAULT 'Unknown',
  PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "name" ON "tools" ("name");

INSERT INTO "tools"( "id", "name", "assigned_ip", "requires_induction") SELECT "id", "name", "assigned_ip", 1 FROM "accessible_things";

CREATE TEMPORARY TABLE "allowed_temp_alter" (
  "person_id" integer NOT NULL,
  "tool_id" varchar(40) NOT NULL,
  "is_admin" boolean NOT NULL,
  "added_on" datetime NOT NULL,
  PRIMARY KEY ("person_id", "tool_id"),
  FOREIGN KEY ("person_id") REFERENCES "people"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY ("tool_id") REFERENCES "tools"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

INSERT INTO "allowed_temp_alter"( "person_id", "is_admin", "tool_id", "added_on") SELECT "person_id", "is_admin", "accessible_thing_id", "added_on" FROM "allowed";

DROP TABLE "allowed";

CREATE TABLE "allowed" (
  "person_id" integer NOT NULL,
  "tool_id" varchar(40) NOT NULL,
  "is_admin" boolean NOT NULL,
  "added_on" datetime NOT NULL,
  PRIMARY KEY ("person_id", "tool_id"),
  FOREIGN KEY ("person_id") REFERENCES "people"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY ("tool_id") REFERENCES "tools"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "allowed_idx_person_id03" ON "allowed" ("person_id");

CREATE INDEX "allowed_idx_tool_id03" ON "allowed" ("tool_id");

INSERT INTO "allowed" SELECT "person_id", "tool_id", "is_admin", "added_on" FROM "allowed_temp_alter";

DROP TABLE "allowed_temp_alter";

ALTER TABLE "communications" ADD COLUMN "status" varchar(10) NOT NULL DEFAULT 'unsent';

CREATE TEMPORARY TABLE "message_log_temp_alter" (
  "tool_id" varchar(40) NOT NULL,
  "message" varchar(2048) NOT NULL,
  "from_ip" varchar(15) NOT NULL,
  "written_date" datetime NOT NULL,
  PRIMARY KEY ("tool_id", "written_date"),
  FOREIGN KEY ("tool_id") REFERENCES "tools"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

INSERT INTO "message_log_temp_alter"( "message", "from_ip", "tool_id", "written_date") SELECT "message", "from_ip", "accessible_thing_id", "written_date" FROM "message_log";

DROP TABLE "message_log";

CREATE TABLE "message_log" (
  "tool_id" varchar(40) NOT NULL,
  "message" varchar(2048) NOT NULL,
  "from_ip" varchar(15) NOT NULL,
  "written_date" datetime NOT NULL,
  PRIMARY KEY ("tool_id", "written_date"),
  FOREIGN KEY ("tool_id") REFERENCES "tools"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "message_log_idx_tool_id03" ON "message_log" ("tool_id");

INSERT INTO "message_log" SELECT "tool_id", "message", "from_ip", "written_date" FROM "message_log_temp_alter";

DROP TABLE "message_log_temp_alter";

CREATE TEMPORARY TABLE "usage_log_temp_alter" (
  "person_id" integer,
  "tool_id" varchar(40) NOT NULL,
  "token_id" varchar(255) NOT NULL,
  "status" varchar(20) NOT NULL,
  "accessed_date" datetime NOT NULL,
  PRIMARY KEY ("tool_id", "accessed_date"),
  FOREIGN KEY ("person_id") REFERENCES "people"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY ("tool_id") REFERENCES "tools"("id")
);

INSERT INTO "usage_log_temp_alter"( "person_id", "tool_id", "token_id", "status", "accessed_date") SELECT "person_id", "accessible_thing_id", "token_id", "status", "accessed_date" FROM "usage_log";

DROP TABLE "usage_log";

CREATE TABLE "usage_log" (
  "person_id" integer,
  "tool_id" varchar(40) NOT NULL,
  "token_id" varchar(255) NOT NULL,
  "status" varchar(20) NOT NULL,
  "accessed_date" datetime NOT NULL,
  PRIMARY KEY ("tool_id", "accessed_date"),
  FOREIGN KEY ("person_id") REFERENCES "people"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY ("tool_id") REFERENCES "tools"("id")
);

CREATE INDEX "usage_log_idx_person_id03" ON "usage_log" ("person_id");

CREATE INDEX "usage_log_idx_tool_id03" ON "usage_log" ("tool_id");

INSERT INTO "usage_log" SELECT "person_id", "tool_id", "token_id", "status", "accessed_date" FROM "usage_log_temp_alter";

DROP TABLE "usage_log_temp_alter";

DROP TABLE "accessible_things";


COMMIT;


