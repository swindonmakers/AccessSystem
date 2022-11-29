-- 
-- Created by SQL::Translator::Producer::SQLite
-- Created on Sat Jan 12 23:00:46 2019
-- 

BEGIN TRANSACTION;

--
-- Table: accessible_things
--
DROP TABLE accessible_things;

CREATE TABLE accessible_things (
  id varchar(40) NOT NULL,
  name varchar(255) NOT NULL,
  assigned_ip varchar(15) NOT NULL,
  PRIMARY KEY (id)
);

CREATE UNIQUE INDEX name ON accessible_things (name);

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
  github_user varchar(255),
  google_id varchar(255),
  concessionary_rate_override varchar(255) DEFAULT '',
  payment_override float,
  member_of_other_hackspace boolean NOT NULL DEFAULT 0,
  created_date datetime NOT NULL,
  end_date datetime,
  FOREIGN KEY (parent_id) REFERENCES people(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX people_idx_parent_id ON people (parent_id);

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
  sent_on datetime NOT NULL,
  type varchar(50) NOT NULL,
  content varchar(10240) NOT NULL,
  PRIMARY KEY (person_id, sent_on),
  FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX communications_idx_person_id ON communications (person_id);

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
-- Table: message_log
--
DROP TABLE message_log;

CREATE TABLE message_log (
  accessible_thing_id varchar(40) NOT NULL,
  message varchar(2048) NOT NULL,
  from_ip varchar(15) NOT NULL,
  written_date datetime NOT NULL,
  PRIMARY KEY (accessible_thing_id, written_date),
  FOREIGN KEY (accessible_thing_id) REFERENCES accessible_things(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX message_log_idx_accessible_thing_id ON message_log (accessible_thing_id);

--
-- Table: allowed
--
DROP TABLE allowed;

CREATE TABLE allowed (
  person_id integer NOT NULL,
  accessible_thing_id varchar(40) NOT NULL,
  is_admin boolean NOT NULL,
  added_on datetime NOT NULL,
  PRIMARY KEY (person_id, accessible_thing_id),
  FOREIGN KEY (accessible_thing_id) REFERENCES accessible_things(id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX allowed_idx_accessible_thing_id ON allowed (accessible_thing_id);

CREATE INDEX allowed_idx_person_id ON allowed (person_id);

--
-- Table: usage_log
--
DROP TABLE usage_log;

CREATE TABLE usage_log (
  person_id integer,
  accessible_thing_id varchar(40) NOT NULL,
  token_id varchar(255) NOT NULL,
  status varchar(20) NOT NULL,
  accessed_date datetime NOT NULL,
  PRIMARY KEY (accessible_thing_id, accessed_date),
  FOREIGN KEY (accessible_thing_id) REFERENCES accessible_things(id),
  FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX usage_log_idx_accessible_thing_id ON usage_log (accessible_thing_id);

CREATE INDEX usage_log_idx_person_id ON usage_log (person_id);

COMMIT;

