-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Sat Jan 12 23:00:47 2019
-- 
--
-- Table: accessible_things
--
DROP TABLE accessible_things CASCADE;
CREATE TABLE accessible_things (
  id character varying(40) NOT NULL,
  name character varying(255) NOT NULL,
  assigned_ip character varying(15) NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT name UNIQUE (name)
);

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
  opt_in integer DEFAULT '0' NOT NULL,
  dob character varying(7) NOT NULL,
  address character varying(1024) NOT NULL,
  github_user character varying(255),
  google_id character varying(255),
  concessionary_rate_override character varying(255) DEFAULT '',
  payment_override float,
  member_of_other_hackspace integer DEFAULT '0' NOT NULL,
  created_date timestamp NOT NULL,
  end_date timestamp,
  PRIMARY KEY (id)
);
CREATE INDEX people_idx_parent_id on people (parent_id);

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
  person_id serial NOT NULL,
  sent_on timestamp NOT NULL,
  type character varying(50) NOT NULL,
  content character varying(10240) NOT NULL,
  PRIMARY KEY (person_id, sent_on)
);
CREATE INDEX communications_idx_person_id on communications (person_id);

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
  accessible_thing_id character varying(40) NOT NULL,
  message character varying(2048) NOT NULL,
  from_ip character varying(15) NOT NULL,
  written_date timestamp NOT NULL,
  PRIMARY KEY (accessible_thing_id, written_date)
);
CREATE INDEX message_log_idx_accessible_thing_id on message_log (accessible_thing_id);

--
-- Table: allowed
--
DROP TABLE allowed CASCADE;
CREATE TABLE allowed (
  person_id integer NOT NULL,
  accessible_thing_id character varying(40) NOT NULL,
  is_admin integer NOT NULL,
  added_on timestamp NOT NULL,
  PRIMARY KEY (person_id, accessible_thing_id)
);
CREATE INDEX allowed_idx_accessible_thing_id on allowed (accessible_thing_id);
CREATE INDEX allowed_idx_person_id on allowed (person_id);

--
-- Table: usage_log
--
DROP TABLE usage_log CASCADE;
CREATE TABLE usage_log (
  person_id integer,
  accessible_thing_id character varying(40) NOT NULL,
  token_id character varying(255) NOT NULL,
  status character varying(20) NOT NULL,
  accessed_date timestamp NOT NULL,
  PRIMARY KEY (accessible_thing_id, accessed_date)
);
CREATE INDEX usage_log_idx_accessible_thing_id on usage_log (accessible_thing_id);
CREATE INDEX usage_log_idx_person_id on usage_log (person_id);

--
-- Foreign Key Definitions
--

ALTER TABLE people ADD CONSTRAINT people_fk_parent_id FOREIGN KEY (parent_id)
  REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE access_tokens ADD CONSTRAINT access_tokens_fk_person_id FOREIGN KEY (person_id)
  REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE communications ADD CONSTRAINT communications_fk_person_id FOREIGN KEY (person_id)
  REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE dues ADD CONSTRAINT dues_fk_person_id FOREIGN KEY (person_id)
  REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE login_tokens ADD CONSTRAINT login_tokens_fk_person_id FOREIGN KEY (person_id)
  REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE message_log ADD CONSTRAINT message_log_fk_accessible_thing_id FOREIGN KEY (accessible_thing_id)
  REFERENCES accessible_things (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE allowed ADD CONSTRAINT allowed_fk_accessible_thing_id FOREIGN KEY (accessible_thing_id)
  REFERENCES accessible_things (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE allowed ADD CONSTRAINT allowed_fk_person_id FOREIGN KEY (person_id)
  REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

ALTER TABLE usage_log ADD CONSTRAINT usage_log_fk_accessible_thing_id FOREIGN KEY (accessible_thing_id)
  REFERENCES accessible_things (id) DEFERRABLE;

ALTER TABLE usage_log ADD CONSTRAINT usage_log_fk_person_id FOREIGN KEY (person_id)
  REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;


