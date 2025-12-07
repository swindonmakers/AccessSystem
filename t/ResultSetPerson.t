#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use DateTime;

use AccessSystem::Schema;

use lib 't/lib';
use AccessSystem::Fixtures;

my $testdb="test_db.db";
unlink $testdb if(-e $testdb);

my $schema = AccessSystem::Schema->connect("dbi:SQLite:$testdb");
$schema->deploy();
# my $fixtures = AccessSystem::Fixtures->new( { schema => $schema } );
# $fixtures->load('standard_member');

# tiers:
AccessSystem::Fixtures::create_tiers($schema);

# Fobs + acccess
my $test9 = AccessSystem::Fixtures::create_person($schema);

my $no_token = $schema->resultset('Person')->allowed_to_thing('12345678', 'blahblahblah');
like($no_token->{error}, qr/not recognised/, 'No such member with that token');
$test9->create_related('tokens', { id => '12345678', type => 'test token' });

my $no_thing = $schema->resultset('Person')->allowed_to_thing('12345678', 'blahblahblah');
like($no_thing->{error}, qr/not recognised/, 'No such missing thing');

my $thing = $schema->resultset('Tool')->create({ name => 'test thing', assigned_ip => '10.0.0.1', requires_induction => 1, team => 'Who knows' });

my $no_allowed = $schema->resultset('Person')->allowed_to_thing('12345678', $thing->id);
like($no_allowed->{error}, qr/not inducted/, 'Person cannot use the thing');

$test9->create_related('allowed', { tool => $thing, is_admin => 0 });

my $no_pay = $schema->resultset('Person')->allowed_to_thing('12345678', $thing->id);
like($no_pay->{error}, qr/Pay up please/, 'Member hasnt paid');

$test9->create_related('payments', { paid_on_date => DateTime->now, expires_on_date => DateTime->now->add(months => 1, days => 14), amount_p => $test9->dues });

my $no_confirm = $schema->resultset('Person')->allowed_to_thing('12345678', $thing->id);
like($no_confirm->{error}, qr/Induction not confirmed/, 'Member hasnt confirmed induction');

my $allowed = $test9->allowed->find({tool_id => $thing->id });
$allowed->update({ pending_acceptance => 'false' });

my $good = $schema->resultset('Person')->allowed_to_thing('12345678', $thing->id);
ok(!$good->{error}, 'Allowed to use thing now');

unlink($testdb);

done_testing;

