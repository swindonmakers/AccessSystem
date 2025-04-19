#!/usr/bin/perl
use warnings;
use strict;

use 5.28.0;

use Time::HiRes 'time', 'sleep';
use Config::General;
use DateTime;

use lib "$ENV{CATALYST_HOME}/lib";
use AccessSystem::Schema;
use AccessSystem::Emailer;

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

my $people = $schema->resultset('Person');
while(my $person = $people->next) {
    next if !$person->is_valid;

    my $comm = $person->create_all_induction_email($l_config{base_url}, 'force resend');

    my $emailer = AccessSystem::Emailer->new;
    $emailer->send($comm, 1);
    sleep 1;
}

