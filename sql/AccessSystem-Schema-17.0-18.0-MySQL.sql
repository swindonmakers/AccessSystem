-- Convert schema 'sql/AccessSystem-Schema-17.0-MySQL.sql' to 'AccessSystem::Schema v18.0':;

BEGIN;

SET foreign_key_checks=0;

CREATE TABLE `required_tools` (
  `required_id` varchar(40) NOT NULL,
  `tool_id` varchar(40) NOT NULL,
  INDEX `required_tools_idx_tool_id` (`tool_id`),
  PRIMARY KEY (`required_id`, `tool_id`),
  CONSTRAINT `required_tools_fk_tool_id` FOREIGN KEY (`tool_id`) REFERENCES `tools` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

SET foreign_key_checks=1;

ALTER TABLE allowed CHANGE COLUMN inducted_by_id inducted_by_id integer NULL DEFAULT NULL,
                    CHANGE COLUMN is_admin is_admin enum('0','1') NOT NULL,
                    CHANGE COLUMN pending_acceptance pending_acceptance enum('0','1') NOT NULL DEFAULT 'true';

ALTER TABLE communications CHANGE COLUMN subject subject text NOT NULL DEFAULT 'Communication from Swindon Makerspace';

ALTER TABLE confirmations CHANGE COLUMN storage storage text NOT NULL;

ALTER TABLE membership_register CHANGE COLUMN address address text NOT NULL,
                                CHANGE COLUMN updated_reason updated_reason text NOT NULL;

ALTER TABLE message_log CHANGE COLUMN message message text NOT NULL;

ALTER TABLE people CHANGE COLUMN opt_in opt_in enum('0','1') NOT NULL DEFAULT '0',
                   CHANGE COLUMN address address text NOT NULL;

ALTER TABLE tiers CHANGE COLUMN description description text NOT NULL DEFAULT '',
                  CHANGE COLUMN concessions_allowed concessions_allowed enum('0','1') NOT NULL DEFAULT '1',
                  CHANGE COLUMN in_use in_use enum('0','1') NOT NULL DEFAULT '1',
                  CHANGE COLUMN restrictions restrictions text NOT NULL DEFAULT '{}';

ALTER TABLE tool_status CHANGE COLUMN description description text NOT NULL;

ALTER TABLE tools ADD COLUMN lone_working_allowed enum('0','1') NOT NULL DEFAULT false,
                  CHANGE COLUMN requires_induction requires_induction enum('0','1') NOT NULL DEFAULT false;

ALTER TABLE transactions DROP PRIMARY KEY,
                         CHANGE COLUMN amount_p amount_p integer NOT NULL,
                         ADD PRIMARY KEY (person_id, added_on, amount_p);


COMMIT;


