-- Convert schema 'sql/AccessSystem-Schema-18.0-PostgreSQL.sql' to 'sql/AccessSystem-Schema-19.0-PostgreSQL.sql':;

BEGIN;

ALTER TABLE transactions RENAME to person_transactions;

ALTER TABLE person_transactions ADD COLUMN "transaction_id" integer;

CREATE TABLE transactions (
  id serial NOT NULL,
  fitid character varying(20) NOT NULL,
  posted_on timestamp NOT NULL,
  name character varying(32) NOT NULL,
  amount_p integer NOT NULL,
  type character varying(10) NOT NULL,
  category character varying(1024) NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT trn UNIQUE (fitid)
);

ALTER TABLE "person_transactions" ADD CONSTRAINT "person_transactions_fk_transaction_id" FOREIGN KEY ("transaction_id")
  REFERENCES "transactions" ("id") DEFERRABLE;

ALTER TABLE allowed ALTER COLUMN is_admin SET DEFAULT false;

COMMIT;


