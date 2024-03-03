#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use DateTime;
use Cwd qw/getcwd/;

use AccessSystem::Schema;

use lib 't/lib';
use AccessSystem::Fixtures;

my $testdb="test_db.db";
unlink $testdb if(-e $testdb);

# ENV needed for emails:
$ENV{CATALYST_HOME} = getcwd();

my $schema = AccessSystem::Schema->connect("dbi:SQLite:$testdb");
$schema->deploy();
# my $fixtures = AccessSystem::Fixtures->new( { schema => $schema } );
# $fixtures->load('standard_member');

# tiers:
AccessSystem::Fixtures::create_tiers($schema);

# basic test Person
my $test1 = AccessSystem::Fixtures::create_person($schema,);

# basic new-member status:
is($test1->dob->ymd, '1980-01-28', 'Date of birth inflated to 28th day of day/month');
ok(!$test1->is_valid, 'New unpaid member is not valid');
is($test1->last_payment, undef, 'No last payment when no payments received');
is($test1->valid_until, undef, 'No valid_until date when no payments received');
like($test1->bank_ref, qr/^SM\d+$/, 'generated SM ref');
is($test1->dues, 2500, 'Default to £25 dues');
is($test1->balance_p, 0, '0 balance with no transactions/payments');

# should be a concession!
my $test2 = AccessSystem::Fixtures::create_person($schema,dob => '1900-01');
is($test2->dues, 1250, 'Senior citizen gets a concessionary rate by default');

# Should also be a concession:
my $test3 = AccessSystem::Fixtures::create_person($schema,c_rate => 'student');
is($test3->dues, 1250, 'Student gets a concessionary rate');

# Specialist concession:
my $test4 = AccessSystem::Fixtures::create_person($schema,tier_id => 5);
is($test4->dues, 1000, 'Mens shed pay £10');

# Own choice of payment
my $test5 = AccessSystem::Fixtures::create_person($schema,payment => '3000');
is($test5->dues, 3000, 'Member specified payment');

my $test6 = AccessSystem::Fixtures::create_person($schema,dob => '1900-01', c_rate => 'student', payment => '3000');
is($test6->dues, 3000, 'Member specified payment (corrent when also senior+student');

# member of another hackspace
my $test7 = AccessSystem::Fixtures::create_person($schema,tier_id => 1);
is($test7->dues, 500, 'Member of another space pays £5');

# Make a payment, then see what happens:
## NB: name mostly ignored here, already parsed into person_id in calling code in update_payments script
$test1->import_transaction({
    dtposted => DateTime->now,
    trnamt   => 52,
    name     => 'FRED BLOGGS SM0001',
});
is($test1->transactions_rs->count, 1, 'Imported one transaction into account');
is($test1->balance_p, 5200, '£52 total in account');

# manually in case that failed:
my $test8 = AccessSystem::Fixtures::create_person($schema);
# manual date creation, else the primary key to transactions clashes
my $t_date = DateTime->now->subtract(minutes => 10);
$test8->create_related('transactions', { added_on => $t_date, amount_p => 5200, reason => "testing" });

# $overlap days to add onto expiry date
$test8->create_payment(14);
is($test8->transactions_rs->count, 2, 'Now 2 transactions in account');
is($test8->recent_transactions->count, 2, 'Recent transactions returns 2');
is($test8->balance_p, 2700, '£27 remaining in account');
ok($test8->is_valid, 'Member is now valid');
is($test8->valid_until->ymd, DateTime->now->add(days => 14, months => 1)->ymd, 'Valid until 1mo/+14days into the future');
is($test8->communications->count, 1, 'Created a communication');
is($test8->communications->first->type, 'first_payment', 'Its a first payment communication');

unlink($testdb);

done_testing;

