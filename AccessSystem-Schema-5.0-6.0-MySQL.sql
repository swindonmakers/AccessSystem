-- Convert schema './AccessSystem-Schema-5.0-MySQL.sql' to 'AccessSystem::Schema v6.0':;

BEGIN;

SET foreign_key_checks=0;

CREATE TABLE `transactions` (
  `person_id` integer NOT NULL,
  `added_on` timestamp NOT NULL,
  `amount_p` integer NOT NULL,
  `reason` varchar(255) NOT NULL,
  INDEX `transactions_idx_person_id` (`person_id`),
  PRIMARY KEY (`person_id`, `added_on`),
  CONSTRAINT `transactions_fk_person_id` FOREIGN KEY (`person_id`) REFERENCES `people` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

SET foreign_key_checks=1;

ALTER TABLE allowed CHANGE COLUMN is_admin is_admin enum('0','1') NOT NULL;

ALTER TABLE communications CHANGE COLUMN person_id person_id integer NOT NULL,
                           CHANGE COLUMN content content text NOT NULL;

ALTER TABLE membership_register CHANGE COLUMN address address text NOT NULL,
                                CHANGE COLUMN updated_reason updated_reason text NOT NULL;

ALTER TABLE message_log CHANGE COLUMN message message text NOT NULL;

ALTER TABLE people CHANGE COLUMN opt_in opt_in enum('0','1') NOT NULL DEFAULT '0',
                   CHANGE COLUMN address address text NOT NULL,
                   CHANGE COLUMN member_of_other_hackspace member_of_other_hackspace enum('0','1') NOT NULL DEFAULT '0';


COMMIT;


