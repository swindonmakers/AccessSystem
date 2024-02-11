#!/usr/bin/perl
use warnings;
use strict;

use 5.28.0;

use Time::HiRes 'time', 'sleep';
use Config::General;
use DateTime;

use lib "$ENV{CATALYST_HOME}/lib";
use AccessSystem::Schema;

if(!$ENV{CATALYST_HOME}) {
    die "Please set the CATALYST_HOME environment variable and try again\n";
}

# Read config to get db connection info:
my %l_config = Config::General->new("$ENV{CATALYST_HOME}/accesssystem_api_local.conf")->getall;
my $schema = AccessSystem::Schema->connect(
    $l_config{'Model::AccessDB'}{connect_info}{dsn},
    $l_config{'Model::AccessDB'}{connect_info}{user},
    $l_config{'Model::AccessDB'}{connect_info}{password},
    );

my $jan_01 = DateTime->new(year => 2024,
                           month => 1,
                           day => 1);
my $date_str = $schema->storage->datetime_parser->format_datetime($jan_01);
my $missing_inductions = $schema->resultset('Allowed')->search(
    {
        pending_acceptance => 1,
        accepted_on => undef,
        added_on => { '>=' => $date_str },
    });

while(my $allowed = $missing_inductions->next) {
    next if !$allowed->person->is_valid;
    my $token = Data::GUID->new->as_string();
    $allowed->person->confirmations->create({
        token => $token,
        storage => {
            tool_id => $tool_id,
            person_id => $person_id,
        },
    });
    $allowed->person->create_communication(
        'Swindon Makerspace Induction Confirmation',
        'induction-on-' . $allowed->tool_id,
        { tool_name => $allowed->tool->name,
          link => $c->uri_for('confirm_induction', { token => $token }) },
        );
    # To be sent by send_communications script
}
