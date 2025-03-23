-- Convert schema 'sql/AccessSystem-Schema-16.0-MySQL.sql' to 'AccessSystem::Schema v17.0':;

BEGIN;

ALTER TABLE allowed ADD COLUMN inducted_by_id integer NULL DEFAULT NULL,
                    CHANGE COLUMN is_admin is_admin enum('0','1') NOT NULL,
                    CHANGE COLUMN pending_acceptance pending_acceptance enum('0','1') NOT NULL DEFAULT 'true',
                    ADD INDEX allowed_idx_inducted_by_id (inducted_by_id),
                    ADD CONSTRAINT allowed_fk_inducted_by_id FOREIGN KEY (inducted_by_id) REFERENCES people (id);

ALTER TABLE communications DROP PRIMARY KEY,
                           CHANGE COLUMN created_on created_on datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
                           CHANGE COLUMN type type varchar(50) NOT NULL,
                           CHANGE COLUMN subject subject text NOT NULL DEFAULT 'Communication from Swindon Makerspace',
                           ADD PRIMARY KEY (person_id, created_on);

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

ALTER TABLE tools CHANGE COLUMN requires_induction requires_induction enum('0','1') NOT NULL;


COMMIT;


