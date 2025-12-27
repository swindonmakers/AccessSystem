#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use DateTime;

use AccessSystem::Schema;

use lib 't/lib';
use AccessSystem::Fixtures;

my $overlap_days = 14;
$ENV{CATALYST_HOME} = '.';

my $testdb="test_db.db";
unlink $testdb if(-e $testdb);

my $schema = AccessSystem::Schema->connect("dbi:SQLite:$testdb");

{
    $| = 1;

    $schema->deploy();
    # my $fixtures = AccessSystem::Fixtures->new( { schema => $schema } );
    # $fixtures->load('standard_member');

    # tiers:
    AccessSystem::Fixtures::create_tiers($schema);

    ## Fobs + acccess, verify normal access with person, token, tool + induction
    my $test9 = AccessSystem::Fixtures::create_person($schema);

    my $no_token = $schema->resultset('Person')->allowed_to_thing('12345678', 'blahblahblah');
    like($no_token->{error}, qr/not recognised/, 'No such member with that token');
    $test9->create_related('tokens', { id => '12345678', type => 'test token' });

    my $no_thing = $schema->resultset('Person')->allowed_to_thing('12345678', 'blahblahblah');
    like($no_thing->{error}, qr/not recognised/, 'No such missing thing');

    my $thing = $schema->resultset('Tool')->create({ name => 'test thing', assigned_ip => '10.0.0.1', requires_induction => 1, team => 'Who knows' });

    my $no_allowed = $schema->resultset('Person')->allowed_to_thing('12345678', $thing->id);
    like($no_allowed->{error}, qr{accepted/inducted}, 'Person cannot use the thing');

    $test9->create_related('allowed', { tool => $thing, is_admin => 0 });

    my $no_pay = $schema->resultset('Person')->allowed_to_thing('12345678', $thing->id);
    like($no_pay->{error}, qr/Pay up please/, 'Member hasnt paid');

    $test9->create_related('payments', { paid_on_date => DateTime->now, expires_on_date => DateTime->now->add(months => 1, days => 14), amount_p => $test9->dues });

    my $no_confirm = $schema->resultset('Person')->allowed_to_thing('12345678', $thing->id);
    like($no_confirm->{error}, qr/Induction not confirmed/, 'Member hasnt confirmed induction');

    my $allowed = $test9->allowed->find({tool_id => $thing->id });
    $allowed->update({ pending_acceptance => 0 });

    my $good = $schema->resultset('Person')->allowed_to_thing('12345678', $thing->id);
    ok(!$good->{error}, 'Allowed to use thing now');

    unlink($testdb);
}

{
    $| = 1;

    ## Test fees - Person, with tier, with matching payment override, create transaction, create payment/fees

    # Deploy fresh DB:
    $schema->deploy();

    # tiers:
    AccessSystem::Fixtures::create_tiers($schema);

    ## sends correct emails?
    # standard tier (3), cost 2500
    # "thing" to test access against
    my $payment_amount = 2500;
    my $comms_count = 0;
    my $testee = AccessSystem::Fixtures::create_person($schema, payment => $payment_amount);
    $testee->create_related('tokens', { id => '12345678', type => 'test token' });
    # The Door so that Result::Person::update_door_access works
    my $thing = $schema->resultset('Tool')->create({ name => 'The Door', assigned_ip => '10.0.0.1', requires_induction => 1, team => 'Who knows' });
    my $allowed = $testee->create_related('allowed', { tool => $thing, is_admin => 0});
    $allowed->discard_changes();
    $allowed->update({ pending_acceptance => 0 });
    $allowed->discard_changes();

    # simulate (under)payment by creating a transaction for payment amount
    my $now = DateTime->now();
    $testee->import_transaction(
        {
            dtposted => $now->clone->subtract(hours => 5),
            trnamt   => ($payment_amount - 500) / 100,
        });
    is($testee->balance_p, $payment_amount - 500, 'Imported underpay transaction');
    # (no emails, does not create a payment)
    lives_ok(sub { $testee->create_payment($overlap_days); }, 'Attempted create_payment without dying');
    is($testee->balance_p, $payment_amount - 500, 'Balance remains the same');
    is($testee->communications_rs->count, $comms_count, 'No communications yet');

    # simulate corrected payment by adding a transaction that makes it up to correct amount
    $testee->import_transaction(
        {
            dtposted => $now->clone->subtract(hours => 4),
            trnamt   => 500 / 100,
        });
    lives_ok( sub { $testee->create_payment($overlap_days); }, '2nd create payment, should actually create one without dying');
    is($testee->balance_p, 0, 'Balance now empty');

    my $good = $schema->resultset('Person')->allowed_to_thing('12345678', $thing->id);
    ok(!$good->{error}, 'Can access Door');

    # (has started email, creates a payment)
    is($testee->payments_rs->count, 1, 'Has a payment');
    is($testee->communications_rs->count, ++$comms_count, 'Sent a communication');
    my $comms = $testee->communications_rs->find({'type' => 'first_payment'});
    ok($comms, 'Created a first_payment email');

    # change valid_date so that its over 5 days ago (attempt to
    # resolve payments will cause a membership reminder)
    my $existing_payment = $testee->payments_rs->first;
    $existing_payment->update({ expires_on_date => $now->clone->subtract(days => 6)});
    # attempt to pay - should send reminder_email
    # sleep cos the timestamp is part of the primary key (seconds resolution!)
    sleep 1;
    lives_ok( sub { $testee->create_payment($overlap_days); }, 'Run create payment with an expir(ing) member without dying');
    is($testee->communications_rs->count, ++$comms_count, 'Sent a communication');
    $comms = $testee->communications_rs->find({'type' => 'reminder_email'});
    ok($comms, 'Created a reminder_email email');
    
    # simulate full transaction, attempt to pay, should send 'rejoined' email and remove 'reminder_email'
    $testee->import_transaction(
        {
            dtposted => $now->clone->subtract(hours => 3),
            trnamt   => 2500 / 100,
        });
    sleep 1;
    lives_ok( sub { $testee->create_payment($overlap_days); }, 'Run create payment with normal payment without dying');
    is($testee->communications_rs->count, $comms_count, 'Same communication count (deleted one)');
    $comms = $testee->communications_rs->find({'type' => 'rejoin_payment'});
    ok($comms, 'Created a rejoin_payment email');

    ## Tier fees change, test what happens!
    # update testee to have a 20% higher fee:
    # store current tier id:
    my $old_tier_id = $testee->tier_id;
    my $tier_fee = $testee->tier->price;
    $testee->tier->update({ price => $tier_fee * 1.2 });
    ok($testee->tier->price > $tier_fee, 'Tier is now a higher fee');
    $payment_amount = $testee->payment_override;
    diag("Payment Amount: $payment_amount");
    ok($payment_amount < $testee->tier->price, 'Member thinks they are paying less, still');
    ok($testee->dues > $payment_amount, 'System disagrees (lower payment_override ignored)');
    is($testee->balance_p, 0, 'Should start at 0 to do this test');

    # reset expiry dates
    $existing_payment = $testee->last_payment;
    # Expires in 10 days, should add new payment if available
    # NB If this gets to 2 days it will also send a reminder_email?
    # but not change to donor yet as not entirely expired:
    $existing_payment->update({ expires_on_date => $now->clone->add(days => 10) });
    # try to access Door - should send email! (last payment was less than dues)
    # sleep - comms emails also have timestamps in the PK
    sleep 1;
    $good = $schema->resultset('Person')->allowed_to_thing('12345678', $thing->id);
    ok(!$good->{error}, 'No Door error');
    is($testee->communications_rs->count, ++$comms_count, 'Sent a communication');
    $comms = $testee->communications_rs->find({'type' => 'membership_fees_change'});
    ok($comms, 'Sent a membership_fees_change email');

    # pay the old amount:
    $testee->import_transaction(
        {
            dtposted => $now->clone->subtract(hours => 2),
            trnamt   => $payment_amount / 100,
        });
    # No emails.. normal "under balance" status until actually expired
    # Aka access allowed for whole of final month..
    my $payment_count = $testee->payments->count;
    sleep 1;
    lives_ok( sub { $testee->create_payment($overlap_days); }, 'Run create payment with old fees without dying');
    is($testee->balance_p, $payment_amount, 'Balance unused');
    is($testee->payments->count, $payment_count, 'Not made a new payment');
    is($testee->communications_rs->count, $comms_count, 'No new communication');
    $testee->discard_changes();
    is($testee->tier_id, $old_tier_id, 'Tier not changed');
    
    # Now "expire" the last payment:
    $existing_payment->update({ expires_on_date => $now->clone->subtract(days => 1) });
    # and attempt to make a new payment with the lower balance:
    sleep 1;
    lives_ok( sub { $testee->create_payment($overlap_days); }, 'Run create payment with old payment, expired member, without dying');
    # still no payment:
    is($testee->balance_p, $payment_amount, 'Balance unused');
    is($testee->payments->count, $payment_count, 'Not made a new payment');

    # and a new email:
    is($testee->communications_rs->count, ++$comms_count, 'Sent a communication');
    $comms = $testee->communications_rs->find({'type' => 'move_to_donation_tier'});
    ok($comms, 'Sent a move_to_donation_tier email');
    # changed tier:
    $testee->discard_changes();
    isnt($testee->tier_id, $old_tier_id, 'Changed tier id');
    # should be in confirmations:
    my $conf = $testee->confirmations->find({ token => 'old_tier' });
    ok($conf, 'Stored old tier settings');

    # top up missing amount
    # old tier price:
    my $old_tier = $schema->resultset('Tier')->find({ id => $old_tier_id });
    $testee->import_transaction(
        {
            dtposted => $now->clone->subtract(hours => 1),
            trnamt   => ($old_tier->price - $payment_amount) / 100,
        });

    # retry payment, should revert tier!?
    sleep 1;
    lives_ok( sub { $testee->create_payment($overlap_days); }, 'Run create payment with new fees without dying');
    is($testee->balance_p, 0, 'Balance empty');
    is($testee->payments->count, $payment_count+1, 'Made a new fees payment');
    is($testee->tier_id, $old_tier_id, 'Reset tier id');
    ok($testee->payment_override >= $testee->tier->price, 'Corrected payment_override');

    # Bob's my uncle?

    unlink($testdb);
}


done_testing;

