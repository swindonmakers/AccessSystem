INSERT INTO tiers (name, description, price, in_use, concessions_allowed) values ('Donation Only', 'Making voluntary contributions to help support the Makerspace', 0, true, false);
UPDATE tiers SET price=600 where id=1;
UPDATE tiers SET price=1800 where id=2;
UPDATE tiers SET price=3000 where id=3;
UPDATE tiers SET price=4200 where id=4;
