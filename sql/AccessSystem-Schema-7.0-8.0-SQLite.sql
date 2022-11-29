-- Convert schema './AccessSystem-Schema-7.0-SQLite.sql' to './AccessSystem-Schema-8.0-SQLite.sql':;

BEGIN;

-- CREATE TABLE "tool_status" (
--   "id" INTEGER PRIMARY KEY NOT NULL,
--   "tool_id" integer NOT NULL,
--   "entered_at" datetime NOT NULL,
--   "who_id" integer NOT NULL,
--   "status" varchar(20) NOT NULL,
--   "description" varchar(1024) NOT NULL,
--   FOREIGN KEY ("tool_id") REFERENCES "tools"("id") ON DELETE CASCADE ON UPDATE CASCADE,
--   FOREIGN KEY ("who_id") REFERENCES "people"("id")
-- );

-- CREATE INDEX "tool_status_idx_tool_id" ON "tool_status" ("tool_id");

-- CREATE INDEX "tool_status_idx_who_id" ON "tool_status" ("who_id");

ALTER TABLE "people" ADD COLUMN "how_found_us" varchar(50);

ALTER TABLE "people" ADD COLUMN "telegram_username" varchar(255);

ALTER TABLE "people" ADD COLUMN "telegram_chatid" integer;

ALTER TABLE "people" ADD COLUMN "voucher_code" varchar(50);

ALTER TABLE "people" ADD COLUMN "voucher_start" datetime;

-- CREATE TEMPORARY TABLE "tools_temp_alter" (
--   "id" varchar(40) NOT NULL,
--   "name" varchar(255) NOT NULL,
--   "assigned_ip" varchar(15),
--   "requires_induction" boolean NOT NULL,
--   "team" varchar(50) NOT NULL,
--   PRIMARY KEY ("id")
-- );

-- INSERT INTO "tools_temp_alter"( "id", "name", "assigned_ip", "requires_induction", "team") SELECT "id", "name", "assigned_ip", "requires_induction", "team" FROM "tools";

-- DROP TABLE "tools";

-- CREATE TABLE "tools" (
--   "id" varchar(40) NOT NULL,
--   "name" varchar(255) NOT NULL,
--   "assigned_ip" varchar(15),
--   "requires_induction" boolean NOT NULL,
--   "team" varchar(50) NOT NULL,
--   PRIMARY KEY ("id")
-- );

-- CREATE UNIQUE INDEX "name03" ON "tools" ("name");

-- INSERT INTO "tools" SELECT "id", "name", "assigned_ip", "requires_induction", "team" FROM "tools_temp_alter";

-- DROP TABLE "tools_temp_alter";


COMMIT;


