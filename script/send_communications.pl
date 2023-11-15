#!/usr/bin/perl
use warnings;
use strict;

use 5.30.0;

use Time::HiRes 'time', 'sleep';
use Config::General;
use Email::Sender::Simple;
use Email::Sender::Transport::SMTP;
use Email::MIME;
use DateTime;
use Getopt::Long;

use lib "$ENV{CATALYST_HOME}/lib";
use AccessSystem::Schema;

=head1 NAME send_communications

=head1 DESCRIPTION

Check for unsent communications and attempt to send them (via email)

=cut

if(!$ENV{CATALYST_HOME}) {
    die "Please set the CATALYST_HOME environment variable and try again\n";
}

# debug/all
my $debug = 0;
my $mails_per_run = 400;
GetOptions(
    'debug'  => \$debug,
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

my %m_config = Config::General->new("$ENV{CATALYST_HOME}/accesssystem_api.conf")->getall;
my $smtp = $m_config{'View::Email'}{sender}{mailer_args};
my $transport = Email::Sender::Transport::SMTP->new($smtp);

my $unsent_comms = $schema->resultset('Communication')->search({
    status => 'unsent'
}, { prefetch => 'person'});

# Count as sendinblue/brevo only allow X transactions per day (500?)
# leave some for signups etc
my $sent_count = 0;
while(my $comms = $unsent_comms->next) {
    last if $sent_count >= $mails_per_run;
    if($debug) {
        print "Sending to " . $comms->person->name . " type: " . $comms->type . "\n";
    }
    my @parts;

    if ($comms->plain_text) {
        push @parts, Email::MIME->create(
                attributes => {
                    content_type => 'text/plain',
                    charset => 'utf-8',
                },
                body => $comms->plain_text,
            );
    }
    if ($comms->html) {
        push @parts, Email::MIME->create(
                attributes => {
                    content_type => 'text/plain',
                    charset => 'utf-8',
                },
                body => $comms->html,
            );
    }

    my $email = Email::MIME->create(
        header_str => [
            From => 'info@swindon-makerspace.org',
            To   => $comms->person->email,
            Cc => $m_config{emails}{cc},
            Subject => $comms->subject,
        ],
        parts => \@parts
        );
    my $start_time = time;
    if(Email::Sender::Simple->try_to_send($email)) {
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
    my $sleep_time = 2 * ($start_time - $end_time);
    $sleep_time = 0.5 if $sleep_time < 0.5;

    if ($debug) {
        say "Send took ", ($start_time-$end_time), " seconds, will sleep $sleep_time seconds";
    }

    $sent_count++;
    sleep $sleep_time;
}
