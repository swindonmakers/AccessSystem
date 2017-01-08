#!/usr/bin/perl
use strictures 2;

use AccessSystem::Schema;
use Config::General;

if(!$ENV{CATALYST_HOME}) {
    die "Please set the CATALYST_HOME environment variable and try again\n";
}

# Read config to get db connection info:
my %config = Config::General->new("$ENV{CATALYST_HOME}/accesssystem_api.conf")->getall;
my $schema = AccessSystem::Schema->connect(
    $config{'Model::AccessDB'}{connect_info}{dsn},
    $config{'Model::AccessDB'}{connect_info}{user},
    $config{'Model::AccessDB'}{connect_info}{password},
    );

my $people = $schema->resultset('Person');

while (my $result = $people->next) {
    my $age_years = (DateTime->now - $result->dob)->years;
    printf "SN%03d: %-40s (%s), %4d pence, %d years\n", $result->id, $result->name, $result->concessionary_rate_override || 'empty', $result->dues, $age_years;
}
