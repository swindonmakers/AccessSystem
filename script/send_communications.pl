#!/usr/bin/perl
use warnings;
use strict;

use 5.28.0;

use Time::HiRes 'time', 'sleep';
use Config::General;
use DateTime;
use Getopt::Long;

use lib "$ENV{CATALYST_HOME}/lib";
use AccessSystem::Schema;
use AccessSystem::Emailer;

=head1 NAME send_communications

=head1 DESCRIPTION

Check for unsent communications and attempt to send them (via email)

=cut

if(!$ENV{CATALYST_HOME}) {
    die "Please set the CATALYST_HOME environment variable and try again\n";
}

# debug/all
my $debug = 0;
my $id;
my $mails_per_run = 400;
GetOptions(
    'debug'  => \$debug,
    'id=i'   => \$id,
    );

if($debug) {
    print "Debug mode, only doing one entry\n";
    $mails_per_run = 1;
}

# Read config to get db connection info:
my %l_config = Config::General->new("$ENV{CATALYST_HOME}/accesssystem_api_local.conf")->getall;
my $schema = AccessSystem::Schema->connect(
    $l_config{'Model::AccessDB'}{connect_info}{dsn},
    $l_config{'Model::AccessDB'}{connect_info}{user},
    $l_config{'Model::AccessDB'}{connect_info}{password},
    );

my $emailer = AccessSystem::Emailer->new();

my $unsent_comms = $schema->resultset('Communication')->search({
    status => 'unsent'
}, { prefetch => 'person'});

# Count as sendinblue/brevo only allow X transactions per day (500?)
# leave some for signups etc
my $sent_count = 0;
while(my $comms = $unsent_comms->next) {
    last if $sent_count >= $mails_per_run;
    next if ($id && $comms->person_id != $id);
    if($debug) {
        print "Sending to " . $comms->person->name . " type: " . $comms->type . "\n";
    }
    my $email = $emailer->generate_email($comms);
    my $start_time = time;
    if ($emailer->send($email)) {
        $comms->update({ status => 'sent' });
        if ($debug) {
            say "Sent successfully";
        }
    } else {
        if ($debug) {
            say "Failed";
        }
    }
    my $end_time = time;
    my $sleep_time = 2 * ($end_time - $start_time);
    $sleep_time = 0.5 if $sleep_time < 0.5;

    if ($debug) {
        say "Send took ", ($end_time-$start_time), " seconds, will sleep $sleep_time seconds";
    }

    $sent_count++;
    sleep $sleep_time;
}
