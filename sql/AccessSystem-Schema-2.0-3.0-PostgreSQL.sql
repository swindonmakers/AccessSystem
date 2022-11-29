-- Convert schema './AccessSystem-Schema-2.0-PostgreSQL.sql' to './AccessSystem-Schema-3.0-PostgreSQL.sql':;

BEGIN;

ALTER TABLE login_tokens DROP CONSTRAINT login_tokens_fk_person_id;

ALTER TABLE login_tokens ADD CONSTRAINT login_tokens_fk_person_id FOREIGN KEY (person_id)
  REFERENCES people (id) ON DELETE cascade ON UPDATE cascade DEFERRABLE;

ALTER TABLE people ADD COLUMN payment_override float(20);


COMMIT;


