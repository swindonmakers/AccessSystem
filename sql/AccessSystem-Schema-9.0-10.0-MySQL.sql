-- Convert schema './AccessSystem-Schema-9.0-MySQL.sql' to 'AccessSystem::Schema v10.0':;

BEGIN;

ALTER TABLE allowed ADD COLUMN pending_acceptance enum('0','1') NOT NULL DEFAULT 'true',
                    CHANGE COLUMN is_admin is_admin enum('0','1') NOT NULL;

ALTER TABLE communications CHANGE COLUMN content content text NOT NULL;

ALTER TABLE confirmations CHANGE COLUMN storage storage text NOT NULL;

ALTER TABLE membership_register CHANGE COLUMN address address text NOT NULL,
                                CHANGE COLUMN updated_reason updated_reason text NOT NULL;

ALTER TABLE message_log CHANGE COLUMN message message text NOT NULL;

ALTER TABLE people CHANGE COLUMN opt_in opt_in enum('0','1') NOT NULL DEFAULT '0',
                   CHANGE COLUMN address address text NOT NULL,
                   CHANGE COLUMN telegram_chatid telegram_chatid bigint NULL,
                   CHANGE COLUMN member_of_other_hackspace member_of_other_hackspace enum('0','1') NOT NULL DEFAULT '0';

ALTER TABLE tool_status CHANGE COLUMN description description text NOT NULL;

ALTER TABLE tools CHANGE COLUMN requires_induction requires_induction enum('0','1') NOT NULL;


COMMIT;


