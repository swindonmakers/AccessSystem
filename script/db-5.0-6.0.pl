#!/usr/bin/perl

use strict;
use warnings;

use lib "$ENV{CATALYST_HOME}/lib";
use AccessSystem::Schema;
use Config::General;

if(!$ENV{CATALYST_HOME}) {
    die "Please set the CATALYST_HOME environment variable and try again\n";
}

my %config = Config::General->new("$ENV{CATALYST_HOME}/accesssystem_api.conf")->getall;
my $schema = AccessSystem::Schema->connect(
    $config{'Model::AccessDB'}{connect_info}{dsn},
    $config{'Model::AccessDB'}{connect_info}{user},
    $config{'Model::AccessDB'}{connect_info}{password},
    );

my $dues_rs = $schema->resultset('Dues');
while (my $payment = $dues_rs->next) {
    $schema->txn_do( sub {
        $schema->resultset('Transactions')->create({
            person_id => $payment->person_id,
            added_on  => $payment->paid_on_date,
            amount_p  => $payment->amount_p,
            reason    => 'Dues to Transactions upgrade - Transaction',
        });
        # Slightly artificial datetime for debit row, as person/added is the PK
        my $debit_added = $payment->paid_on_date->clone;
        $debit_added->set_day(1);
        $debit_added->set_hour(4);
        $debit_added->set_minute(0);
        $debit_added->set_second(0);
        my $dtf = $schema->storage->datetime_parser;
        my $debit_row = $schema->resultset('Transactions')->find_or_new({
            person_id => $payment->person_id,
            added_on  => $dtf->format_datetime($debit_added),
            amount_p  => -1*$payment->amount_p,
            reason    => 'Dues to Transactions upgrade - Debit',
        });
        if($debit_row->in_storage) {
            # If there are more than 2 in a month I'll eat my hat..
            warn("in storage already");
            $debit_added->set_hour(5);
            $debit_row = $schema->resultset('Transactions')->create({
                person_id => $payment->person_id,
                added_on  => $debit_added,
                amount_p  => -1*$payment->amount_p,
                reason    => 'Dues to Transactions upgrade - Debit',
            });         
        } else {
            $debit_row->insert;
        }
    });
}
