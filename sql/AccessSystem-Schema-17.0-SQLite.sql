--
-- Created by SQL::Translator::Producer::SQLite
-- Created on Sun Mar 23 16:24:30 2025
--

BEGIN TRANSACTION;

--
-- Table: membership_register
--
DROP TABLE membership_register;

CREATE TABLE membership_register (
  name varchar(255) NOT NULL,
  address varchar(1024) NOT NULL,
  started_date date NOT NULL,
  ended_date date,
  updated_date datetime,
  updated_reason varchar(1024) NOT NULL,
  PRIMARY KEY (name, started_date)
);

--
-- Table: tiers
--
DROP TABLE tiers;

CREATE TABLE tiers (
  id INTEGER PRIMARY KEY NOT NULL,
  name varchar(50) NOT NULL,
  description varchar(2048) NOT NULL DEFAULT '',
  price integer NOT NULL,
  concessions_allowed boolean NOT NULL DEFAULT 1,
  in_use boolean NOT NULL DEFAULT 1,
  restrictions varchar(2048) NOT NULL DEFAULT '{}'
);

CREATE UNIQUE INDEX tier_name ON tiers (name);

--
-- Table: tools
--
DROP TABLE tools;

CREATE TABLE tools (
  id varchar(40) NOT NULL,
  name varchar(255) NOT NULL,
  assigned_ip varchar(15),
  requires_induction boolean NOT NULL,
  team varchar(50) NOT NULL,
  PRIMARY KEY (id)
);

CREATE UNIQUE INDEX name ON tools (name);

--
-- Table: message_log
--
DROP TABLE message_log;

CREATE TABLE message_log (
  tool_id varchar(40) NOT NULL,
  message varchar(2048) NOT NULL,
  from_ip varchar(15) NOT NULL,
  written_date datetime NOT NULL,
  PRIMARY KEY (tool_id, written_date),
  FOREIGN KEY (tool_id) REFERENCES tools(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX message_log_idx_tool_id ON message_log (tool_id);

--
-- Table: people
--
DROP TABLE people;

CREATE TABLE people (
  id INTEGER PRIMARY KEY NOT NULL,
  parent_id integer,
  name varchar(255) NOT NULL,
  email varchar(255),
  opt_in boolean NOT NULL DEFAULT 0,
  dob varchar(7) NOT NULL,
  address varchar(1024) NOT NULL,
  how_found_us varchar(50),
  github_user varchar(255),
  telegram_username varchar(255),
  telegram_chatid bigint,
  google_id varchar(255),
  concessionary_rate_override varchar(255) DEFAULT '',
  payment_override float,
  tier_id integer NOT NULL DEFAULT 0,
  door_colour varchar(20) NOT NULL DEFAULT 'green',
  voucher_code varchar(50),
  voucher_start datetime,
  created_date datetime NOT NULL,
  end_date datetime,
  FOREIGN KEY (parent_id) REFERENCES people(id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (tier_id) REFERENCES tiers(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX people_idx_parent_id ON people (parent_id);

CREATE INDEX people_idx_tier_id ON people (tier_id);

CREATE UNIQUE INDEX telegram_id ON people (telegram_chatid);

--
-- Table: access_tokens
--
DROP TABLE access_tokens;

CREATE TABLE access_tokens (
  id varchar(255) NOT NULL,
  person_id integer NOT NULL,
  type varchar(20) NOT NULL,
  PRIMARY KEY (person_id, id),
  FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX access_tokens_idx_person_id ON access_tokens (person_id);

--
-- Table: communications
--
DROP TABLE communications;

CREATE TABLE communications (
  person_id integer NOT NULL,
  created_on datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  sent_on datetime,
  type varchar(50) NOT NULL,
  status varchar(10) NOT NULL DEFAULT 'unsent',
  subject varchar(1024) NOT NULL DEFAULT 'Communication from Swindon Makerspace',
  plain_text text NOT NULL,
  html text,
  PRIMARY KEY (person_id, created_on),
  FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX communications_idx_person_id ON communications (person_id);

--
-- Table: confirmations
--
DROP TABLE confirmations;

CREATE TABLE confirmations (
  person_id integer NOT NULL,
  token varchar(36) NOT NULL,
  storage varchar(1024) NOT NULL,
  PRIMARY KEY (token),
  FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX confirmations_idx_person_id ON confirmations (person_id);

--
-- Table: dues
--
DROP TABLE dues;

CREATE TABLE dues (
  person_id integer NOT NULL,
  paid_on_date datetime NOT NULL,
  expires_on_date datetime NOT NULL,
  amount_p integer NOT NULL,
  added_on datetime NOT NULL,
  PRIMARY KEY (person_id, paid_on_date),
  FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX dues_idx_person_id ON dues (person_id);

--
-- Table: login_tokens
--
DROP TABLE login_tokens;

CREATE TABLE login_tokens (
  person_id integer NOT NULL,
  login_token varchar(36) NOT NULL,
  PRIMARY KEY (person_id, login_token),
  FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX login_tokens_idx_person_id ON login_tokens (person_id);

--
-- Table: transactions
--
DROP TABLE transactions;

CREATE TABLE transactions (
  person_id integer NOT NULL,
  added_on timestamp NOT NULL,
  amount_p integer NOT NULL,
  reason varchar(255) NOT NULL,
  PRIMARY KEY (person_id, added_on),
  FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX transactions_idx_person_id ON transactions (person_id);

--
-- Table: vehicles
--
DROP TABLE vehicles;

CREATE TABLE vehicles (
  person_id integer NOT NULL,
  plate_reg varchar(7) NOT NULL,
  added_on datetime NOT NULL,
  PRIMARY KEY (person_id, plate_reg),
  FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX vehicles_idx_person_id ON vehicles (person_id);

--
-- Table: allowed
--
DROP TABLE allowed;

CREATE TABLE allowed (
  person_id integer NOT NULL,
  inducted_by_id integer DEFAULT NULL,
  tool_id varchar(40) NOT NULL,
  is_admin boolean NOT NULL,
  pending_acceptance boolean NOT NULL DEFAULT 'true',
  accepted_on datetime,
  added_on datetime NOT NULL,
  PRIMARY KEY (person_id, tool_id),
  FOREIGN KEY (inducted_by_id) REFERENCES people(id),
  FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (tool_id) REFERENCES tools(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX allowed_idx_inducted_by_id ON allowed (inducted_by_id);

CREATE INDEX allowed_idx_person_id ON allowed (person_id);

CREATE INDEX allowed_idx_tool_id ON allowed (tool_id);

--
-- Table: tool_status
--
DROP TABLE tool_status;

CREATE TABLE tool_status (
  id INTEGER PRIMARY KEY NOT NULL,
  tool_id varchar(40) NOT NULL,
  entered_at datetime NOT NULL,
  who_id integer NOT NULL,
  status varchar(20) NOT NULL,
  description varchar(1024) NOT NULL,
  FOREIGN KEY (tool_id) REFERENCES tools(id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (who_id) REFERENCES people(id)
);

CREATE INDEX tool_status_idx_tool_id ON tool_status (tool_id);

CREATE INDEX tool_status_idx_who_id ON tool_status (who_id);

--
-- Table: usage_log
--
DROP TABLE usage_log;

CREATE TABLE usage_log (
  person_id integer,
  tool_id varchar(40) NOT NULL,
  token_id varchar(255) NOT NULL,
  status varchar(20) NOT NULL,
  accessed_date datetime NOT NULL,
  running_for integer NOT NULL DEFAULT 0,
  PRIMARY KEY (tool_id, accessed_date),
  FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (tool_id) REFERENCES tools(id)
);

CREATE INDEX usage_log_idx_person_id ON usage_log (person_id);

CREATE INDEX usage_log_idx_tool_id ON usage_log (tool_id);

COMMIT;

