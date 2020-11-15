-- Convert schema './AccessSystem-Schema-6.0-PostgreSQL.sql' to './AccessSystem-Schema-7.0-PostgreSQL.sql':;

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

CREATE TABLE "tools" (
  "id" character varying(40) NOT NULL,
  "name" character varying(255) NOT NULL,
  "assigned_ip" character varying(15),
  "requires_induction" boolean NOT NULL,
  "team" character varying(50) NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "name" UNIQUE ("name")
);

ALTER TABLE allowed DROP CONSTRAINT ;

ALTER TABLE allowed DROP CONSTRAINT allowed_pkey;

ALTER TABLE allowed DROP CONSTRAINT allowed_fk_accessible_thing_id;

ALTER TABLE allowed DROP COLUMN accessible_thing_id;

ALTER TABLE allowed ADD COLUMN tool_id character varying(40) NOT NULL;

UPDATE allowed SET tool_id = accessible_thing_id;

DROP INDEX allowed_idx_accessible_thing_id;

CREATE INDEX allowed_idx_tool_id on allowed (tool_id);

ALTER TABLE allowed ADD PRIMARY KEY (person_id, tool_id);

ALTER TABLE allowed ADD CONSTRAINT allowed_fk_tool_id FOREIGN KEY (tool_id)
  REFERENCES tools (id) ON DELETE cascade ON UPDATE cascade DEFERRABLE;

ALTER TABLE communications ADD COLUMN status character varying(10) NOT NULL DEFAULT 'unsent';

ALTER TABLE message_log DROP CONSTRAINT ;

ALTER TABLE message_log DROP CONSTRAINT message_log_pkey;

ALTER TABLE message_log DROP CONSTRAINT message_log_fk_accessible_thing_id;

DROP INDEX message_log_idx_accessible_thing_id;

ALTER TABLE message_log ADD COLUMN tool_id character varying(40) NOT NULL;

UPDATE message_log SET tool_id = accessible_thing_id;

ALTER TABLE message_log DROP COLUMN accessible_thing_id;

CREATE INDEX message_log_idx_tool_id on message_log (tool_id);

ALTER TABLE message_log ADD PRIMARY KEY (tool_id, written_date);

ALTER TABLE message_log ADD CONSTRAINT message_log_fk_tool_id FOREIGN KEY (tool_id)
  REFERENCES tools (id) ON DELETE cascade ON UPDATE cascade DEFERRABLE;

ALTER TABLE usage_log DROP CONSTRAINT ;

ALTER TABLE usage_log DROP CONSTRAINT usage_log_pkey;

ALTER TABLE usage_log DROP CONSTRAINT usage_log_fk_accessible_thing_id;

DROP INDEX usage_log_idx_accessible_thing_id;

ALTER TABLE usage_log ADD COLUMN tool_id character varying(40) NOT NULL;

ALTER TABLE usage_log DROP COLUMN accessible_thing_id;

ALTER TABLE usage_log DROP COLUMN accessible_thing_id;

CREATE INDEX usage_log_idx_tool_id on usage_log (tool_id);

ALTER TABLE usage_log ADD PRIMARY KEY (tool_id, accessed_date);

ALTER TABLE usage_log ADD CONSTRAINT usage_log_fk_tool_id FOREIGN KEY (tool_id)
  REFERENCES tools (id) DEFERRABLE;

DROP TABLE accessible_things CASCADE;


COMMIT;


