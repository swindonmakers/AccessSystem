--
-- Created by SQL::Translator::Producer::MySQL
-- Created on Sun Dec 31 15:57:16 2023
--
SET foreign_key_checks=0;

DROP TABLE IF EXISTS membership_register;

--
-- Table: membership_register
--
CREATE TABLE membership_register (
  name varchar(255) NOT NULL,
  address text NOT NULL,
  started_date date NOT NULL,
  ended_date date NULL,
  updated_date datetime NULL,
  updated_reason text NOT NULL,
  PRIMARY KEY (name, started_date)
);

DROP TABLE IF EXISTS tiers;

--
-- Table: tiers
--
CREATE TABLE tiers (
  id integer NOT NULL auto_increment,
  name varchar(50) NOT NULL,
  description text NOT NULL DEFAULT '',
  price integer NOT NULL,
  concessions_allowed enum('0','1') NOT NULL DEFAULT '1',
  in_use enum('0','1') NOT NULL DEFAULT '1',
  restrictions text NOT NULL DEFAULT '{}',
  PRIMARY KEY (id),
  UNIQUE tier_name (name)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS tools;

--
-- Table: tools
--
CREATE TABLE tools (
  id varchar(40) NOT NULL,
  name varchar(255) NOT NULL,
  assigned_ip varchar(15) NULL,
  requires_induction enum('0','1') NOT NULL,
  team varchar(50) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE name (name)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS message_log;

--
-- Table: message_log
--
CREATE TABLE message_log (
  tool_id varchar(40) NOT NULL,
  message text NOT NULL,
  from_ip varchar(15) NOT NULL,
  written_date datetime NOT NULL,
  INDEX message_log_idx_tool_id (tool_id),
  PRIMARY KEY (tool_id, written_date),
  CONSTRAINT message_log_fk_tool_id FOREIGN KEY (tool_id) REFERENCES tools (id) ON DELETE CASCADE ON UPDATE CASCADE
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
  dob varchar(7) NOT NULL,
  address text NOT NULL,
  how_found_us varchar(50) NULL,
  github_user varchar(255) NULL,
  telegram_username varchar(255) NULL,
  telegram_chatid bigint NULL,
  google_id varchar(255) NULL,
  concessionary_rate_override varchar(255) NULL DEFAULT '',
  payment_override float NULL,
  tier_id integer NOT NULL DEFAULT 0,
  door_colour varchar(20) NOT NULL DEFAULT 'green',
  voucher_code varchar(50) NULL,
  voucher_start datetime NULL,
  created_date datetime NOT NULL,
  end_date datetime NULL,
  INDEX people_idx_parent_id (parent_id),
  INDEX people_idx_tier_id (tier_id),
  PRIMARY KEY (id),
  UNIQUE telegram_id (telegram_chatid),
  CONSTRAINT people_fk_parent_id FOREIGN KEY (parent_id) REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT people_fk_tier_id FOREIGN KEY (tier_id) REFERENCES tiers (id) ON DELETE CASCADE ON UPDATE CASCADE
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
  person_id integer NOT NULL,
  created_on datetime NOT NULL,
  sent_on datetime NULL,
  type varchar(50) NOT NULL,
  status varchar(10) NOT NULL DEFAULT 'unsent',
  subject text NOT NULL DEFAULT 'Communication from Swindon Makerspace',
  plain_text text NOT NULL,
  html text NULL,
  INDEX communications_idx_person_id (person_id),
  PRIMARY KEY (person_id, type),
  CONSTRAINT communications_fk_person_id FOREIGN KEY (person_id) REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS confirmations;

--
-- Table: confirmations
--
CREATE TABLE confirmations (
  person_id integer NOT NULL,
  token varchar(36) NOT NULL,
  storage text NOT NULL,
  INDEX confirmations_idx_person_id (person_id),
  PRIMARY KEY (token),
  CONSTRAINT confirmations_fk_person_id FOREIGN KEY (person_id) REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE
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

DROP TABLE IF EXISTS login_tokens;

--
-- Table: login_tokens
--
CREATE TABLE login_tokens (
  person_id integer NOT NULL,
  login_token varchar(36) NOT NULL,
  INDEX login_tokens_idx_person_id (person_id),
  PRIMARY KEY (person_id, login_token),
  CONSTRAINT login_tokens_fk_person_id FOREIGN KEY (person_id) REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS transactions;

--
-- Table: transactions
--
CREATE TABLE transactions (
  person_id integer NOT NULL,
  added_on timestamp NOT NULL,
  amount_p integer NOT NULL,
  reason varchar(255) NOT NULL,
  INDEX transactions_idx_person_id (person_id),
  PRIMARY KEY (person_id, added_on),
  CONSTRAINT transactions_fk_person_id FOREIGN KEY (person_id) REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS allowed;

--
-- Table: allowed
--
CREATE TABLE allowed (
  person_id integer NOT NULL,
  tool_id varchar(40) NOT NULL,
  is_admin enum('0','1') NOT NULL,
  pending_acceptance enum('0','1') NOT NULL DEFAULT 'true',
  accepted_on datetime NULL,
  added_on datetime NOT NULL,
  INDEX allowed_idx_person_id (person_id),
  INDEX allowed_idx_tool_id (tool_id),
  PRIMARY KEY (person_id, tool_id),
  CONSTRAINT allowed_fk_person_id FOREIGN KEY (person_id) REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT allowed_fk_tool_id FOREIGN KEY (tool_id) REFERENCES tools (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS tool_status;

--
-- Table: tool_status
--
CREATE TABLE tool_status (
  id integer NOT NULL auto_increment,
  tool_id varchar(40) NOT NULL,
  entered_at datetime NOT NULL,
  who_id integer NOT NULL,
  status varchar(20) NOT NULL,
  description text NOT NULL,
  INDEX tool_status_idx_tool_id (tool_id),
  INDEX tool_status_idx_who_id (who_id),
  PRIMARY KEY (id),
  CONSTRAINT tool_status_fk_tool_id FOREIGN KEY (tool_id) REFERENCES tools (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT tool_status_fk_who_id FOREIGN KEY (who_id) REFERENCES people (id)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS usage_log;

--
-- Table: usage_log
--
CREATE TABLE usage_log (
  person_id integer NULL,
  tool_id varchar(40) NOT NULL,
  token_id varchar(255) NOT NULL,
  status varchar(20) NOT NULL,
  accessed_date datetime NOT NULL,
  INDEX usage_log_idx_person_id (person_id),
  INDEX usage_log_idx_tool_id (tool_id),
  PRIMARY KEY (tool_id, accessed_date),
  CONSTRAINT usage_log_fk_person_id FOREIGN KEY (person_id) REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT usage_log_fk_tool_id FOREIGN KEY (tool_id) REFERENCES tools (id)
) ENGINE=InnoDB;

SET foreign_key_checks=1;


