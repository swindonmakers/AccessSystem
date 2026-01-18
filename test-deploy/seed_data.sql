INSERT INTO tiers (id, name, description, price, concessions_allowed, in_use, restrictions) VALUES 
(1, 'Other Hackspace', 'Member of another hackspace/makerspace', 500, false, true, '{}'),
(2, 'Standard', 'Standard full membership', 2500, true, true, '{}'),
(3, 'Student', 'Student membership (requires proof)', 1250, false, true, '{}'),
(4, 'Weekend', 'Weekend access only', 1500, true, true, '{"times":[{"from":"6:00:00","to":"7:23:59"}]}'),
(5, 'Men''s Shed', 'Men''s Shed membership', 1000, false, true, '{}'),
(6, 'Donation', 'Donor only membership (no access)', 0, false, true, '{}');

INSERT INTO tools (id, name, assigned_ip, requires_induction, team) VALUES
('09637E38-F469-11F0-A94B-FD08D99F0D81', 'The Door', '10.0.0.1', false, 'Everyone');
