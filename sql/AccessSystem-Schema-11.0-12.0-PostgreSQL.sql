-- Convert schema 'sql/AccessSystem-Schema-11.0-PostgreSQL.sql' to 'sql/AccessSystem-Schema-12.0-PostgreSQL.sql':;

BEGIN;

CREATE TABLE "tiers" (
  "id" serial NOT NULL,
  "name" character varying(50) NOT NULL,
  "description" character varying(2048) DEFAULT '' NOT NULL,
  "price" integer NOT NULL,
  "concessions_allowed" boolean DEFAULT '1' NOT NULL,
  "dont_use" boolean DEFAULT '0' NOT NULL,
  "restrictions" character varying(2048) DEFAULT '{}' NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "tier_name" UNIQUE ("name")
);

INSERT INTO tiers (name, description, price, concessions_allowed) values ('MemberOfOtherHackspace', 'Living outside of Swindon Borough and a fully paid up member of another Maker or Hackspace', 500, 0);
INSERT INTO tiers (name, description, price, restrictions) values ('Weekend', 'Access 12:00am Saturday until 12:00am Monday, and Wednesdays 6:30pm to 11:59pm only', 1500, '{"times":[{"from":"3:18:00","to":"3:23:59"},{"from":"6:00:01","to":"6:23:59"},{"from":"7:00:01","to":"7:23:59"}]}');
INSERT INTO tiers (name, description, price) values ('Standard', 'Access 24hours a day, 365 days a year', 2500);
INSERT INTO tiers (name, description, price) values ('Sponsor', 'Access 24hours a day, 365 days a year', 3500);
INSERT INTO tiers (name, description, price, dont_use) values ('MensShed', 'Members of Renew only, rate now retired', 1000, 1);

ALTER TABLE people DROP CONSTRAINT ;

ALTER TABLE people ADD COLUMN tier_id integer DEFAULT 0 NOT NULL;

UPDATE people SET tier_id = 1 WHERE member_of_other_hackspace = 1;

UPDATE people SET tier_id = 5 WHERE concessionary_rate_override = 'mensshed';

ALTER TABLE people DROP COLUMN member_of_other_hackspace;

ALTER TABLE people ADD COLUMN tier_id integer DEFAULT 0 NOT NULL;

ALTER TABLE people ADD COLUMN door_colour character varying(20) DEFAULT 'green' NOT NULL;

CREATE INDEX people_idx_tier_id on people (tier_id);

ALTER TABLE people ADD CONSTRAINT people_fk_tier_id FOREIGN KEY (tier_id)
  REFERENCES tiers (id) ON DELETE cascade ON UPDATE cascade DEFERRABLE;


COMMIT;


