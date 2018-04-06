-- Convert schema './AccessSystem-Schema-2.0-MySQL.sql' to 'AccessSystem::Schema v3.0':;

BEGIN;

ALTER TABLE allowed CHANGE COLUMN is_admin is_admin enum('0','1') NOT NULL;

ALTER TABLE communications CHANGE COLUMN content content text NOT NULL;

ALTER TABLE login_tokens DROP FOREIGN KEY login_tokens_fk_person_id;

ALTER TABLE login_tokens ADD CONSTRAINT login_tokens_fk_person_id FOREIGN KEY (person_id) REFERENCES people (id) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE message_log CHANGE COLUMN message message text NOT NULL;

ALTER TABLE people ADD COLUMN payment_override float NULL,
                   CHANGE COLUMN opt_in opt_in enum('0','1') NOT NULL DEFAULT '0',
                   CHANGE COLUMN address address text NOT NULL,
                   CHANGE COLUMN member_of_other_hackspace member_of_other_hackspace enum('0','1') NOT NULL DEFAULT '0';


COMMIT;


