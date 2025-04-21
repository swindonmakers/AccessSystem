INSERT INTO tiers (id, name, description, price, concessions_allowed, in_use, restrictions)
VALUES (4, 'Sponsor', 'Access 24hours a day, 365 days a year', 3500, true, true, '{}');
INSERT INTO tiers (id, name, description, price, concessions_allowed, in_use, restrictions)
VALUES (3, 'Standard', 'Access 24hours a day, 365 days a year', 2500, true, true, '{}');
INSERT INTO tiers (id, name, description, price, concessions_allowed, in_use, restrictions)
VALUES (1, 'MemberOfOtherHackspace',
        'Living outside of Swindon Borough and a fully paid up member of another Maker or Hackspace', 500, false, true,
        '{}');
INSERT INTO tiers (id, name, description, price, concessions_allowed, in_use, restrictions)
VALUES (2, 'Weekend', 'Access 12:00am Saturday until 12:00am Monday, and Wednesdays 6:30pm to 11:59pm only', 1500, true,
        true,
        '{"times":[{"from":"3:18:00","to":"3:23:59"},{"from":"6:00:01","to":"6:23:59"},{"from":"7:00:01","to":"7:23:59"}]}');
INSERT INTO tiers (id, name, description, price, concessions_allowed, in_use, restrictions)
VALUES (5, 'MensShed', 'Members of Renew only, rate now retired', 1000, false, false, '{}');
