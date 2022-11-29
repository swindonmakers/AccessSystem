-- Convert schema './AccessSystem-Schema-6.0-MySQL.sql' to 'AccessSystem::Schema v7.0':;

BEGIN;

SET foreign_key_checks=0;

CREATE TABLE `tools` (
  `id` varchar(40) NOT NULL,
  `name` varchar(255) NOT NULL,
  `assigned_ip` varchar(15) NULL,
  `requires_induction` enum('0','1') NOT NULL,
  `team` varchar(50) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE `name` (`name`)
) ENGINE=InnoDB;

SET foreign_key_checks=1;

ALTER TABLE allowed DROP PRIMARY KEY,
                    DROP FOREIGN KEY allowed_fk_accessible_thing_id,
                    DROP INDEX allowed_idx_accessible_thing_id,
                    DROP COLUMN accessible_thing_id,
                    ADD COLUMN tool_id varchar(40) NOT NULL,
                    CHANGE COLUMN is_admin is_admin enum('0','1') NOT NULL,
                    ADD INDEX allowed_idx_tool_id (tool_id),
                    ADD PRIMARY KEY (person_id, tool_id),
                    ADD CONSTRAINT allowed_fk_tool_id FOREIGN KEY (tool_id) REFERENCES tools (id) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE communications ADD COLUMN status varchar(10) NOT NULL,
                           CHANGE COLUMN content content text NOT NULL;

ALTER TABLE membership_register CHANGE COLUMN address address text NOT NULL,
                                CHANGE COLUMN updated_reason updated_reason text NOT NULL;

ALTER TABLE message_log DROP PRIMARY KEY,
                        DROP FOREIGN KEY message_log_fk_accessible_thing_id,
                        DROP INDEX message_log_idx_accessible_thing_id,
                        DROP COLUMN accessible_thing_id,
                        ADD COLUMN tool_id varchar(40) NOT NULL,
                        CHANGE COLUMN message message text NOT NULL,
                        ADD INDEX message_log_idx_tool_id (tool_id),
                        ADD PRIMARY KEY (tool_id, written_date),
                        ADD CONSTRAINT message_log_fk_tool_id FOREIGN KEY (tool_id) REFERENCES tools (id) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE people CHANGE COLUMN opt_in opt_in enum('0','1') NOT NULL DEFAULT '0',
                   CHANGE COLUMN address address text NOT NULL,
                   CHANGE COLUMN member_of_other_hackspace member_of_other_hackspace enum('0','1') NOT NULL DEFAULT '0';

ALTER TABLE usage_log DROP PRIMARY KEY,
                      DROP FOREIGN KEY usage_log_fk_accessible_thing_id,
                      DROP INDEX usage_log_idx_accessible_thing_id,
                      DROP COLUMN accessible_thing_id,
                      ADD COLUMN tool_id varchar(40) NOT NULL,
                      ADD INDEX usage_log_idx_tool_id (tool_id),
                      ADD PRIMARY KEY (tool_id, accessed_date),
                      ADD CONSTRAINT usage_log_fk_tool_id FOREIGN KEY (tool_id) REFERENCES tools (id);

DROP TABLE accessible_things;


COMMIT;


