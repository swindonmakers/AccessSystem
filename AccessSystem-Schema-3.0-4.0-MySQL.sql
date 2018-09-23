-- Convert schema './AccessSystem-Schema-3.0-MySQL.sql' to 'AccessSystem::Schema v4.0':;

BEGIN;

SET foreign_key_checks=0;

CREATE TABLE `membership_register` (
  `name` varchar(255) NOT NULL,
  `address` text NOT NULL,
  `started_date` date NOT NULL,
  `ended_date` date NULL,
  `updated_date` datetime NULL,
  `updated_reason` text NOT NULL,
  PRIMARY KEY (`name`, `started_date`)
);

SET foreign_key_checks=1;

ALTER TABLE allowed ADD COLUMN added_on datetime NOT NULL,
                    CHANGE COLUMN is_admin is_admin enum('0','1') NOT NULL;

ALTER TABLE communications CHANGE COLUMN content content text NOT NULL;

ALTER TABLE message_log CHANGE COLUMN message message text NOT NULL;

ALTER TABLE people ADD COLUMN analytics_use enum('0','1') NOT NULL DEFAULT '0',
                   CHANGE COLUMN opt_in opt_in enum('0','1') NOT NULL DEFAULT '0',
                   CHANGE COLUMN dob dob varchar(7) NOT NULL,
                   CHANGE COLUMN address address text NOT NULL,
                   CHANGE COLUMN member_of_other_hackspace member_of_other_hackspace enum('0','1') NOT NULL DEFAULT '0';

ALTER TABLE usage_log DROP FOREIGN KEY usage_log_fk_person_id;

ALTER TABLE usage_log ADD CONSTRAINT usage_log_fk_person_id FOREIGN KEY (person_id) REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE;


COMMIT;


