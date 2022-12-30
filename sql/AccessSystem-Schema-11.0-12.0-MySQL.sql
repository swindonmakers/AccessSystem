-- Convert schema 'sql/AccessSystem-Schema-11.0-MySQL.sql' to 'AccessSystem::Schema v12.0':;

BEGIN;

SET foreign_key_checks=0;

CREATE TABLE `tiers` (
  `id` integer NOT NULL auto_increment,
  `name` varchar(50) NOT NULL,
  `description` text NOT NULL DEFAULT '',
  `price` integer NOT NULL,
  `concessions_allowed` enum('0','1') NOT NULL DEFAULT '1',
  `dont_use` enum('0','1') NOT NULL DEFAULT '0',
  `restrictions` text NOT NULL DEFAULT '{}',
  PRIMARY KEY (`id`),
  UNIQUE `tier_name` (`name`)
) ENGINE=InnoDB;

SET foreign_key_checks=1;

ALTER TABLE allowed CHANGE COLUMN is_admin is_admin enum('0','1') NOT NULL,
                    CHANGE COLUMN pending_acceptance pending_acceptance enum('0','1') NOT NULL DEFAULT 'true';

ALTER TABLE communications CHANGE COLUMN content content text NOT NULL;

ALTER TABLE confirmations CHANGE COLUMN storage storage text NOT NULL;

ALTER TABLE membership_register CHANGE COLUMN address address text NOT NULL,
                                CHANGE COLUMN updated_reason updated_reason text NOT NULL;

ALTER TABLE message_log CHANGE COLUMN message message text NOT NULL;

ALTER TABLE people DROP COLUMN member_of_other_hackspace,
                   ADD COLUMN tier_id integer NOT NULL DEFAULT 0,
                   ADD COLUMN door_colour varchar(20) NOT NULL DEFAULT 'green',
                   CHANGE COLUMN opt_in opt_in enum('0','1') NOT NULL DEFAULT '0',
                   CHANGE COLUMN address address text NOT NULL,
                   ADD INDEX people_idx_tier_id (tier_id),
                   ADD CONSTRAINT people_fk_tier_id FOREIGN KEY (tier_id) REFERENCES tiers (id) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE tool_status CHANGE COLUMN description description text NOT NULL;

ALTER TABLE tools CHANGE COLUMN requires_induction requires_induction enum('0','1') NOT NULL;


COMMIT;


