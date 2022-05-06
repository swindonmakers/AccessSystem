-- Convert schema './AccessSystem-Schema-7.0-MySQL.sql' to 'AccessSystem::Schema v8.0':;

BEGIN;

SET foreign_key_checks=0;

CREATE TABLE `tool_status` (
  `id` integer NOT NULL auto_increment,
  `tool_id` integer NOT NULL,
  `entered_at` datetime NOT NULL,
  `who_id` integer NOT NULL,
  `status` varchar(20) NOT NULL,
  `description` text NOT NULL,
  INDEX `tool_status_idx_tool_id` (`tool_id`),
  INDEX `tool_status_idx_who_id` (`who_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `tool_status_fk_tool_id` FOREIGN KEY (`tool_id`) REFERENCES `tools` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `tool_status_fk_who_id` FOREIGN KEY (`who_id`) REFERENCES `people` (`id`)
) ENGINE=InnoDB;

SET foreign_key_checks=1;

ALTER TABLE allowed CHANGE COLUMN is_admin is_admin enum('0','1') NOT NULL;

ALTER TABLE communications CHANGE COLUMN content content text NOT NULL;

ALTER TABLE membership_register CHANGE COLUMN address address text NOT NULL,
                                CHANGE COLUMN updated_reason updated_reason text NOT NULL;

ALTER TABLE message_log CHANGE COLUMN message message text NOT NULL;

ALTER TABLE people ADD COLUMN how_found_us varchar(50) NULL,
                   ADD COLUMN telegram_username varchar(255) NULL,
                   ADD COLUMN telegram_chatid integer NULL,
                   ADD COLUMN voucher_code varchar(50) NULL,
                   ADD COLUMN voucher_start datetime NULL,
                   CHANGE COLUMN opt_in opt_in enum('0','1') NOT NULL DEFAULT '0',
                   CHANGE COLUMN address address text NOT NULL,
                   CHANGE COLUMN member_of_other_hackspace member_of_other_hackspace enum('0','1') NOT NULL DEFAULT '0';

ALTER TABLE tools CHANGE COLUMN requires_induction requires_induction enum('0','1') NOT NULL;


COMMIT;


