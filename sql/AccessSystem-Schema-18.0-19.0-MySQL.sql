-- Convert schema 'sql/AccessSystem-Schema-18.0-MySQL.sql' to 'AccessSystem::Schema v19.0':;

BEGIN;

SET foreign_key_checks=0;

CREATE TABLE `person_transactions` (
  `person_id` integer NOT NULL,
  `transaction_id` integer NULL,
  `amount_p` integer NOT NULL,
  `added_on` timestamp NOT NULL,
  `reason` varchar(255) NOT NULL,
  INDEX `person_transactions_idx_person_id` (`person_id`),
  INDEX `person_transactions_idx_transaction_id` (`transaction_id`),
  PRIMARY KEY (`person_id`, `added_on`, `amount_p`),
  CONSTRAINT `person_transactions_fk_person_id` FOREIGN KEY (`person_id`) REFERENCES `people` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `person_transactions_fk_transaction_id` FOREIGN KEY (`transaction_id`) REFERENCES `transactions` (`id`)
) ENGINE=InnoDB;

SET foreign_key_checks=1;

ALTER TABLE allowed CHANGE COLUMN inducted_by_id inducted_by_id integer NULL DEFAULT NULL,
                    CHANGE COLUMN is_admin is_admin enum('0','1') NOT NULL DEFAULT 'false',
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

ALTER TABLE tools CHANGE COLUMN requires_induction requires_induction enum('0','1') NOT NULL DEFAULT false,
                  CHANGE COLUMN lone_working_allowed lone_working_allowed enum('0','1') NOT NULL DEFAULT true;

ALTER TABLE transactions DROP PRIMARY KEY,
                         DROP FOREIGN KEY transactions_fk_person_id,
                         DROP INDEX transactions_idx_person_id,
                         DROP COLUMN person_id,
                         DROP COLUMN added_on,
                         DROP COLUMN reason,
                         ADD COLUMN id integer NOT NULL auto_increment,
                         ADD COLUMN fitid varchar(20) NOT NULL,
                         ADD COLUMN posted_on timestamp NOT NULL,
                         ADD COLUMN name varchar(32) NOT NULL,
                         ADD COLUMN type varchar(10) NOT NULL,
                         ADD COLUMN category text NOT NULL,
                         CHANGE COLUMN amount_p amount_p integer NOT NULL,
                         ADD PRIMARY KEY (id),
                         ADD UNIQUE trn (fitid);


COMMIT;


