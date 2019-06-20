#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use DateTime;

use AccessSystem::Schema;

my $testdb="test_db.db";
unlink $testdb if(-e $testdb);

my $schema = AccessSystem::Schema->connect("dbi:SQLite:$testdb");
$schema->deploy();

# basic test Person

my $test1 = create_person($schema,);

# basic new-member status:
is($test1->dob->ymd, '1980-01-28', 'Date of birth inflated to 28th day of day/month');
ok(!$test1->is_valid, 'New unpaid member is not valid');
is($test1->last_payment, undef, 'No last payment when no payments received');
is($test1->valid_until, undef, 'No valid_until date when no payments received');
like($test1->bank_ref, qr/^SM\d+$/, 'generated SM ref');
is($test1->dues, 2500, 'Default to £25 dues');
is($test1->balance_p, 0, '0 balance with no transactions/payments');

# should be a concession!
my $test2 = create_person($schema,dob => '1900-01');
is($test2->dues, 1250, 'Senipr citizen gets a concessionary rate by default');

# Should also be a concession:
my $test3 = create_person($schema,c_rate => 'student');
is($test3->dues, 1250, 'Student gets a concessionary rate');

# Specialist concession:
my $test4 = create_person($schema,c_rate => 'mensshed');
is($test4->dues, 1000, 'Mens shed pay £10');

# Own choice of payment
my $test5 = create_person($schema,payment => '3000');
is($test5->dues, 3000, 'Member specified payment');

my $test6 = create_person($schema,dob => '1900-01', c_rate => 'student', payment => '3000');
is($test6->dues, 3000, 'Member specified payment (corrent when also senior+student');

# member of another hackspace
my $test7 = create_person($schema,other => 1);
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
my $test8 = create_person($schema);
# manual date creation, else the primary key to transactions clashes
my $t_date = DateTime->now->subtract(minutes => 10);
$test8->create_related('transactions', { added_on => $t_date, amount_p => 5200, reason => "testing" });
# $overlap days to add onto expiry date
$test8->create_payment(14);
is($test8->transactions_rs->count, 2, 'Now 2 transactions in account');
is($test8->balance_p, 2700, '£27 remaining in account');
ok($test8->is_valid, 'Member is now valid');
is($test8->valid_until->ymd, DateTime->now->add(days => 14, months => 1)->ymd, 'Valid until 1mo/+14days into the future');

# Fobs + acccess
my $test9 = create_person($schema);

my $no_token = $schema->resultset('Person')->allowed_to_thing('12345678', 'blahblahblah');
like($no_token->{error}, qr/isn't associated with any user/, 'No such member with that token');
$test9->create_related('tokens', { id => '12345678', type => 'test token' });

my $no_thing = $schema->resultset('Person')->allowed_to_thing('12345678', 'blahblahblah');
like($no_thing->{error}, qr/doesn't represent any AccessibleThing I've heard of/, 'No such missing thing');

my $thing = $schema->resultset('AccessibleThing')->create({ name => 'test thing', assigned_ip => '10.0.0.1' });

my $no_allowed = $schema->resultset('Person')->allowed_to_thing('12345678', $thing->id);
like($no_allowed->{error}, qr/The thing exists, but the Person isn't allowed to access it/, 'Person cannot use the thing');

$test9->create_related('allowed', { accessible_thing => $thing, is_admin => 0 });

my $no_pay = $schema->resultset('Person')->allowed_to_thing('12345678', $thing->id);
like($no_pay->{error}, qr/Member would have access with that token, but their membership has expired/, 'Member hasnt paid');

$test9->create_related('payments', { paid_on_date => DateTime->now, expires_on_date => DateTime->now->add(months => 1, days => 14), amount_p => $test9->dues });

my $good = $schema->resultset('Person')->allowed_to_thing('12345678', $thing->id);
ok(!$good->{error}, 'Access to thing allowed when valid + connected to it');







unlink($testdb);

done_testing;

sub create_person {
    my ($schema, %args) = @_;
    my $dob = $args{dob}|| '1980-01';
    my $c_rate = $args{c_rate} || undef;
    my $payment = $args{payment} || undef;
    my $other = $args{other} || 0;

    $schema->resultset('Person')->create({
        parent_id => undef,
        name => 'Fred Bloggs',
        email => 'fred@example.com',
        opt_in => 0,
        dob => $dob,
        address => 'Somewhere, Somehow',
        github_user => undef,
        google_id => undef,
        concessionary_rate_override => $c_rate,
        payment_override => $payment,
        member_of_other_hackspace => $other,
    });
}
