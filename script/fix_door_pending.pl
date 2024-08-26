#!/usr/bin/perl

use strict;
use warnings;

use Config::General;
use lib "$ENV{CATALYST_HOME}/lib";
use AccessSystem::Schema;
use feature 'state', 'say';

if(!$ENV{CATALYST_HOME}) {
    die "Please set the CATALYST_HOME environment variable and try again\n";
}

# Read config to get db connection info:
my %config = Config::General->new("$ENV{CATALYST_HOME}/accesssystem_api_local.conf")->getall;
my $schema = AccessSystem::Schema->connect(
    $config{'Model::AccessDB'}{connect_info}{dsn},
    $config{'Model::AccessDB'}{connect_info}{user},
    $config{'Model::AccessDB'}{connect_info}{password},
    );


my $people = $schema->resultset('Person');

while(my $person = $people->next) {
    if($person->is_valid) {
        my $door = $person->allowed->find(
            {
                'tool.name' => 'The Door',
                    pending_acceptance => 1,
            },
            {
                join => 'tool'
            });
        if(!$door) {
            say $person->name .' is not pending';
            next;
        }
        $door->update({pending_acceptance => 0});
        say $person->name . ' Door fixed';
    } else {
        say $person->name . ' not valid';
    }
}

