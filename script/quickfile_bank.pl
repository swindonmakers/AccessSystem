#!/usr/bin/perl

use strict;
use warnings;
use Config::General;
use DateTime;

use lib "$ENV{CATALYST_HOME}/lib";
use AccessSystem::Schema;
use AccessSystem::QuickFile;

my $days = shift;

my %config = Config::General->new("$ENV{CATALYST_HOME}/accesssystem_api_local.conf")->getall;
my $schema = AccessSystem::Schema->connect(
    $config{'Model::AccessDB'}{connect_info}{dsn},
    $config{'Model::AccessDB'}{connect_info}{user},
    $config{'Model::AccessDB'}{connect_info}{password},
    );


my $qf_api = AccessSystem::QuickFile->new(
    access_key => $config{QuickFile}{access_key},
    debug => 0,
);

my ($from, $to);
if ($days) {
    $to = DateTime->now();
    $from = $to->clone->subtract(days => $days);
}
my $transactions = $qf_api->get_transactions($from->ymd, $to->ymd);

# Continue with "update_payments" style import:

my $dt_parser = $schema->storage->datetime_parser;
foreach my $trn (@$transactions) {
    fiddle_payment($trn);
    next if($trn->{amount} <= 0);
    next if($trn->{reference} !~ /\s+SM\s?(\d+)/i);

    my $id = $1;
    my $member = $schema->resultset('Person')->find({ id => $id+0 });
    if(!$member) {
        warn "SM$id isn't a known membership id ($trn->{reference})\n";
        next;
    }
    print "Importing " . $member->name . " amount: " . $trn->{amount} . " on " . $trn->{date} . "\n";
    
    if(!$member->import_transaction(
            {
                trnamt => $trn->{amount},
                dtposted => $dt_parser->parse_date($trn->{date})
            })) {
        warn "Import failed! See above\n";
    }    
}

# People often cant spell "SM00.." or just fail to write one
sub fiddle_payment {
    my ($trans) = @_;

    ## Mr Netting paid to wrong membership ID (twice):
    if($trans->{reference} =~ /K WALLBANK/) {
        $trans->{reference} = 'K WALLBANK SM00194';
    } elsif($trans->{reference} =~ /J SCOTT STO/) {
        $trans->{reference} = 'J SCOTT SM0303 STO';
    } elsif($trans->{reference} =~ /Henry Russell/) {
        $trans->{reference} = 'Henry Russell SM0374';
    } elsif($trans->{reference} =~ /CROSSKEY CG I/) {
        $trans->{reference} = 'CROSSKEY CG SM0375';
    } elsif($trans->{reference} =~ /DJORN\s+FEVRIER/) {
        $trans->{reference} = 'JORN FEVRIER SM0301';
    } elsif($trans->{reference} =~ /C Hinton BGC/) {
        $trans->{reference} = 'C Hinton BGC SM0416';
    }
    $trans->{reference} =~ s/sm/SM/ig;
    $trans->{reference} =~ s/ SN/ SM/gi;
    $trans->{reference} =~ s/SMo/SM0/gi;

    print STDERR "Name now: " . $trans->{reference} . "\n";
    return 0;
}
