-- Convert schema './AccessSystem-Schema-1.x-MySQL.sql' to 'AccessSystem::Schema v2.0':;

BEGIN;

SET foreign_key_checks=0;

CREATE TABLE `login_tokens` (
  `person_id` integer NOT NULL,
  `login_token` varchar(36) NOT NULL,
  INDEX `login_tokens_idx_person_id` (`person_id`),
  PRIMARY KEY (`person_id`, `login_token`),
  CONSTRAINT `login_tokens_fk_person_id` FOREIGN KEY (`person_id`) REFERENCES `people` (`id`)
) ENGINE=InnoDB;

SET foreign_key_checks=1;

ALTER TABLE allowed CHANGE COLUMN is_admin is_admin enum('0','1') NOT NULL;

ALTER TABLE communications CHANGE COLUMN content content text NOT NULL;

ALTER TABLE message_log CHANGE COLUMN message message text NOT NULL;

ALTER TABLE people CHANGE COLUMN opt_in opt_in enum('0','1') NOT NULL DEFAULT '0',
                   CHANGE COLUMN address address text NOT NULL,
                   CHANGE COLUMN member_of_other_hackspace member_of_other_hackspace enum('0','1') NOT NULL DEFAULT '0';


COMMIT;


