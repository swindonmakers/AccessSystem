-- Convert schema './AccessSystem-Schema-8.0-MySQL.sql' to 'AccessSystem::Schema v9.0':;

BEGIN;

SET foreign_key_checks=0;

CREATE TABLE `confirmations` (
  `person_id` integer NOT NULL,
  `token` varchar(36) NOT NULL,
  `storage` text NOT NULL,
  INDEX `confirmations_idx_person_id` (`person_id`),
  PRIMARY KEY (`token`),
  CONSTRAINT `confirmations_fk_person_id` FOREIGN KEY (`person_id`) REFERENCES `people` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

SET foreign_key_checks=1;

ALTER TABLE allowed CHANGE COLUMN is_admin is_admin enum('0','1') NOT NULL;

ALTER TABLE communications CHANGE COLUMN content content text NOT NULL;

ALTER TABLE membership_register CHANGE COLUMN address address text NOT NULL,
                                CHANGE COLUMN updated_reason updated_reason text NOT NULL;

ALTER TABLE message_log CHANGE COLUMN message message text NOT NULL;

ALTER TABLE people CHANGE COLUMN opt_in opt_in enum('0','1') NOT NULL DEFAULT '0',
                   CHANGE COLUMN address address text NOT NULL,
                   CHANGE COLUMN member_of_other_hackspace member_of_other_hackspace enum('0','1') NOT NULL DEFAULT '0',
                   ADD UNIQUE telegram_id (telegram_chatid);

ALTER TABLE tool_status CHANGE COLUMN tool_id tool_id varchar(40) NOT NULL,
                        CHANGE COLUMN description description text NOT NULL;

ALTER TABLE tools CHANGE COLUMN requires_induction requires_induction enum('0','1') NOT NULL;


COMMIT;


