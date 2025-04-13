-- Convert schema 'sql/AccessSystem-Schema-17.0-PostgreSQL.sql' to 'sql/AccessSystem-Schema-18.0-PostgreSQL.sql':;

BEGIN;

CREATE TABLE "required_tools" (
  "required_id" character varying(40) NOT NULL,
  "tool_id" character varying(40) NOT NULL,
  PRIMARY KEY ("required_id", "tool_id")
);
CREATE INDEX "required_tools_idx_tool_id" on "required_tools" ("tool_id");

ALTER TABLE "required_tools" ADD CONSTRAINT "required_tools_fk_tool_id" FOREIGN KEY ("tool_id")
  REFERENCES "tools" ("id") ON DELETE cascade ON UPDATE cascade DEFERRABLE;

ALTER TABLE tools ADD COLUMN lone_working_allowed boolean DEFAULT 'true' NOT NULL;

ALTER TABLE tools ALTER COLUMN requires_induction SET DEFAULT false;

ALTER TABLE transactions DROP CONSTRAINT transactions_pkey;

ALTER TABLE transactions ADD PRIMARY KEY (person_id, added_on, amount_p);


COMMIT;


