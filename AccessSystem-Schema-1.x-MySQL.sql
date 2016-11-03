-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Thu Nov  3 19:50:01 2016
-- 
SET foreign_key_checks=0;

DROP TABLE IF EXISTS accessible_things;

--
-- Table: accessible_things
--
CREATE TABLE accessible_things (
  id varchar(40) NOT NULL,
  name varchar(255) NOT NULL,
  assigned_ip varchar(15) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE name (name)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS people;

--
-- Table: people
--
CREATE TABLE people (
  id integer NOT NULL auto_increment,
  parent_id integer NULL,
  name varchar(255) NOT NULL,
  email varchar(255) NULL,
  opt_in enum('0','1') NOT NULL DEFAULT '0',
  dob datetime NOT NULL,
  address text NOT NULL,
  github_user varchar(255) NULL,
  concessionary_rate enum('0','1') NOT NULL DEFAULT '0',
  member_of_other_hackspace enum('0','1') NOT NULL DEFAULT '0',
  created_date datetime NOT NULL,
  end_date datetime NULL,
  INDEX people_idx_parent_id (parent_id),
  PRIMARY KEY (id),
  CONSTRAINT people_fk_parent_id FOREIGN KEY (parent_id) REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS access_tokens;

--
-- Table: access_tokens
--
CREATE TABLE access_tokens (
  id varchar(255) NOT NULL,
  person_id integer NOT NULL,
  type varchar(20) NOT NULL,
  INDEX access_tokens_idx_person_id (person_id),
  PRIMARY KEY (person_id, id),
  CONSTRAINT access_tokens_fk_person_id FOREIGN KEY (person_id) REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS communications;

--
-- Table: communications
--
CREATE TABLE communications (
  person_id integer NOT NULL auto_increment,
  sent_on datetime NOT NULL,
  type varchar(50) NOT NULL,
  content text NOT NULL,
  INDEX communications_idx_person_id (person_id),
  PRIMARY KEY (person_id, sent_on),
  CONSTRAINT communications_fk_person_id FOREIGN KEY (person_id) REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS dues;

--
-- Table: dues
--
CREATE TABLE dues (
  person_id integer NOT NULL,
  paid_on_date datetime NOT NULL,
  expires_on_date datetime NOT NULL,
  amount_p integer NOT NULL,
  added_on datetime NOT NULL,
  INDEX dues_idx_person_id (person_id),
  PRIMARY KEY (person_id, paid_on_date),
  CONSTRAINT dues_fk_person_id FOREIGN KEY (person_id) REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS message_log;

--
-- Table: message_log
--
CREATE TABLE message_log (
  accessible_thing_id varchar(40) NOT NULL,
  message text NOT NULL,
  from_ip varchar(15) NOT NULL,
  written_date datetime NOT NULL,
  INDEX message_log_idx_accessible_thing_id (accessible_thing_id),
  PRIMARY KEY (accessible_thing_id, written_date),
  CONSTRAINT message_log_fk_accessible_thing_id FOREIGN KEY (accessible_thing_id) REFERENCES accessible_things (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS allowed;

--
-- Table: allowed
--
CREATE TABLE allowed (
  person_id integer NOT NULL,
  accessible_thing_id varchar(40) NOT NULL,
  is_admin enum('0','1') NOT NULL,
  INDEX allowed_idx_accessible_thing_id (accessible_thing_id),
  INDEX allowed_idx_person_id (person_id),
  PRIMARY KEY (person_id, accessible_thing_id),
  CONSTRAINT allowed_fk_accessible_thing_id FOREIGN KEY (accessible_thing_id) REFERENCES accessible_things (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT allowed_fk_person_id FOREIGN KEY (person_id) REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS usage_log;

--
-- Table: usage_log
--
CREATE TABLE usage_log (
  person_id integer NULL,
  accessible_thing_id varchar(40) NOT NULL,
  token_id varchar(255) NOT NULL,
  status varchar(20) NOT NULL,
  accessed_date datetime NOT NULL,
  INDEX usage_log_idx_accessible_thing_id (accessible_thing_id),
  INDEX usage_log_idx_person_id (person_id),
  PRIMARY KEY (accessible_thing_id, accessed_date),
  CONSTRAINT usage_log_fk_accessible_thing_id FOREIGN KEY (accessible_thing_id) REFERENCES accessible_things (id),
  CONSTRAINT usage_log_fk_person_id FOREIGN KEY (person_id) REFERENCES people (id)
) ENGINE=InnoDB;

SET foreign_key_checks=1;


