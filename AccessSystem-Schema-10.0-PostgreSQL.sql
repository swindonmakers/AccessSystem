--
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Thu Jul 14 19:38:54 2022
--
--
-- Table: membership_register
--
DROP TABLE membership_register CASCADE;
CREATE TABLE membership_register (
  name character varying(255) NOT NULL,
  address character varying(1024) NOT NULL,
  started_date date NOT NULL,
  ended_date date,
  updated_date timestamp,
  updated_reason character varying(1024) NOT NULL,
  PRIMARY KEY (name, started_date)
);

--
-- Table: people
--
DROP TABLE people CASCADE;
CREATE TABLE people (
  id serial NOT NULL,
  parent_id integer,
  name character varying(255) NOT NULL,
  email character varying(255),
  opt_in boolean DEFAULT '0' NOT NULL,
  dob character varying(7) NOT NULL,
  address character varying(1024) NOT NULL,
  how_found_us character varying(50),
  github_user character varying(255),
  telegram_username character varying(255),
  telegram_chatid bigint,
  google_id character varying(255),
  concessionary_rate_override character varying(255) DEFAULT '',
  payment_override float,
  member_of_other_hackspace boolean DEFAULT '0' NOT NULL,
  voucher_code character varying(50),
  voucher_start timestamp,
  created_date timestamp NOT NULL,
  end_date timestamp,
  PRIMARY KEY (id),
  CONSTRAINT telegram_id UNIQUE (telegram_chatid)
);
CREATE INDEX people_idx_parent_id on people (parent_id);

--
-- Table: tools
--
DROP TABLE tools CASCADE;
CREATE TABLE tools (
  id character varying(40) NOT NULL,
  name character varying(255) NOT NULL,
  assigned_ip character varying(15),
  requires_induction boolean NOT NULL,
  team character varying(50) NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT name UNIQUE (name)
);

--
-- Table: access_tokens
--
DROP TABLE access_tokens CASCADE;
CREATE TABLE access_tokens (
  id character varying(255) NOT NULL,
  person_id integer NOT NULL,
  type character varying(20) NOT NULL,
  PRIMARY KEY (person_id, id)
);
CREATE INDEX access_tokens_idx_person_id on access_tokens (person_id);

--
-- Table: communications
--
DROP TABLE communications CASCADE;
CREATE TABLE communications (
  person_id integer NOT NULL,
  sent_on timestamp NOT NULL,
  type character varying(50) NOT NULL,
  status character varying(10) NOT NULL,
  content character varying(10240) NOT NULL,
  PRIMARY KEY (person_id, sent_on)
);
CREATE INDEX communications_idx_person_id on communications (person_id);

--
-- Table: confirmations
--
DROP TABLE confirmations CASCADE;
CREATE TABLE confirmations (
  person_id integer NOT NULL,
  token character varying(36) NOT NULL,
  storage character varying(1024) NOT NULL,
  PRIMARY KEY (token)
);
CREATE INDEX confirmations_idx_person_id on confirmations (person_id);

--
-- Table: dues
--
DROP TABLE dues CASCADE;
CREATE TABLE dues (
  person_id integer NOT NULL,
  paid_on_date timestamp NOT NULL,
  expires_on_date timestamp NOT NULL,
  amount_p integer NOT NULL,
  added_on timestamp NOT NULL,
  PRIMARY KEY (person_id, paid_on_date)
);
CREATE INDEX dues_idx_person_id on dues (person_id);

--
-- Table: login_tokens
--
DROP TABLE login_tokens CASCADE;
CREATE TABLE login_tokens (
  person_id integer NOT NULL,
  login_token character varying(36) NOT NULL,
  PRIMARY KEY (person_id, login_token)
);
CREATE INDEX login_tokens_idx_person_id on login_tokens (person_id);

--
-- Table: message_log
--
DROP TABLE message_log CASCADE;
CREATE TABLE message_log (
  tool_id character varying(40) NOT NULL,
  message character varying(2048) NOT NULL,
  from_ip character varying(15) NOT NULL,
  written_date timestamp NOT NULL,
  PRIMARY KEY (tool_id, written_date)
);
CREATE INDEX message_log_idx_tool_id on message_log (tool_id);

--
-- Table: transactions
--
DROP TABLE transactions CASCADE;
CREATE TABLE transactions (
  person_id integer NOT NULL,
  added_on timestamp NOT NULL,
  amount_p integer NOT NULL,
  reason character varying(255) NOT NULL,
  PRIMARY KEY (person_id, added_on)
);
CREATE INDEX transactions_idx_person_id on transactions (person_id);

--
-- Table: allowed
--
DROP TABLE allowed CASCADE;
CREATE TABLE allowed (
  person_id integer NOT NULL,
  tool_id character varying(40) NOT NULL,
  is_admin boolean NOT NULL,
  pending_acceptance boolean DEFAULT 'true' NOT NULL,
  added_on timestamp NOT NULL,
  PRIMARY KEY (person_id, tool_id)
);
CREATE INDEX allowed_idx_person_id on allowed (person_id);
CREATE INDEX allowed_idx_tool_id on allowed (tool_id);

--
-- Table: tool_status
--
DROP TABLE tool_status CASCADE;
CREATE TABLE tool_status (
  id serial NOT NULL,
  tool_id character varying(40) NOT NULL,
  entered_at timestamp NOT NULL,
  who_id integer NOT NULL,
  status character varying(20) NOT NULL,
  description character varying(1024) NOT NULL,
  PRIMARY KEY (id)
);
CREATE INDEX tool_status_idx_tool_id on tool_status (tool_id);
CREATE INDEX tool_status_idx_who_id on tool_status (who_id);

--
-- Table: usage_log
--
DROP TABLE usage_log CASCADE;
CREATE TABLE usage_log (
  person_id integer,
  tool_id character varying(40) NOT NULL,
  token_id character varying(255) NOT NULL,
  status character varying(20) NOT NULL,
  accessed_date timestamp NOT NULL,
  PRIMARY KEY (tool_id, accessed_date)
);
CREATE INDEX usage_log_idx_person_id on usage_log (person_id);
CREATE INDEX usage_log_idx_tool_id on usage_log (tool_id);

--
-- Foreign Key Definitions
--

ALTER TABLE people ADD CONSTRAINT people_fk_parent_id FOREIGN KEY (parent_id)
  REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE access_tokens ADD CONSTRAINT access_tokens_fk_person_id FOREIGN KEY (person_id)
  REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE communications ADD CONSTRAINT communications_fk_person_id FOREIGN KEY (person_id)
  REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE confirmations ADD CONSTRAINT confirmations_fk_person_id FOREIGN KEY (person_id)
  REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE dues ADD CONSTRAINT dues_fk_person_id FOREIGN KEY (person_id)
  REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE login_tokens ADD CONSTRAINT login_tokens_fk_person_id FOREIGN KEY (person_id)
  REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE message_log ADD CONSTRAINT message_log_fk_tool_id FOREIGN KEY (tool_id)
  REFERENCES tools (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE transactions ADD CONSTRAINT transactions_fk_person_id FOREIGN KEY (person_id)
  REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE allowed ADD CONSTRAINT allowed_fk_person_id FOREIGN KEY (person_id)
  REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE allowed ADD CONSTRAINT allowed_fk_tool_id FOREIGN KEY (tool_id)
  REFERENCES tools (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE tool_status ADD CONSTRAINT tool_status_fk_tool_id FOREIGN KEY (tool_id)
  REFERENCES tools (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE tool_status ADD CONSTRAINT tool_status_fk_who_id FOREIGN KEY (who_id)
  REFERENCES people (id) DEFERRABLE;

ALTER TABLE usage_log ADD CONSTRAINT usage_log_fk_person_id FOREIGN KEY (person_id)
  REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE usage_log ADD CONSTRAINT usage_log_fk_tool_id FOREIGN KEY (tool_id)
  REFERENCES tools (id) DEFERRABLE;


