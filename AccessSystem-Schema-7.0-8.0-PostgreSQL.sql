-- Convert schema './AccessSystem-Schema-7.0-PostgreSQL.sql' to './AccessSystem-Schema-8.0-PostgreSQL.sql':;

BEGIN;

CREATE TABLE "tool_status" (
  "id" serial NOT NULL,
  "tool_id" integer NOT NULL,
  "entered_at" timestamp NOT NULL,
  "who_id" integer NOT NULL,
  "status" character varying(20) NOT NULL,
  "description" character varying(1024) NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "tool_status_idx_tool_id" on "tool_status" ("tool_id");
CREATE INDEX "tool_status_idx_who_id" on "tool_status" ("who_id");

ALTER TABLE "tool_status" ADD CONSTRAINT "tool_status_fk_tool_id" FOREIGN KEY ("tool_id")
  REFERENCES "tools" ("id") ON DELETE cascade ON UPDATE cascade DEFERRABLE;

ALTER TABLE "tool_status" ADD CONSTRAINT "tool_status_fk_who_id" FOREIGN KEY ("who_id")
  REFERENCES "people" ("id") DEFERRABLE;

ALTER TABLE people ADD COLUMN how_found_us character varying(50);

ALTER TABLE people ADD COLUMN telegram_username character varying(255);

ALTER TABLE people ADD COLUMN telegram_chatid integer;

ALTER TABLE people ADD COLUMN voucher_code character varying(50);

ALTER TABLE people ADD COLUMN voucher_start timestamp;

ALTER TABLE tools ALTER COLUMN requires_induction DROP DEFAULT;

ALTER TABLE tools ALTER COLUMN team DROP DEFAULT;


COMMIT;


