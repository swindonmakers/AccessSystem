#!/usr/bin/perl

use strict;
use warnings;

# use local::lib '/usr/src/perl/libs/access_system/perl5';
use Config::General;
use DateTime;

use lib "$ENV{CATALYST_HOME}/lib";
use AccessSystem::Schema;

# Read config to get db connection info:
my %config = Config::General->new("$ENV{CATALYST_HOME}/accesssystem_api_local.conf")->getall;
my $schema = AccessSystem::Schema->connect(
    $config{'Model::AccessDB'}{connect_info}{dsn},
    $config{'Model::AccessDB'}{connect_info}{user},
    $config{'Model::AccessDB'}{connect_info}{password},
    );

my @people = ();
foreach my $person ($schema->resultset('Person')->all) {
    next if $person->valid_until;
    next if $person->created_date > DateTime->new(year => 2022,
                                                  month => 2,
                                                  day => 1
        );
    next if $person->tokens->count > 0;
    print $person->name, "\n";
    push @people, $person->id;
}

my $to_delete = $schema->resultset('Person')->search({ id => \@people });
print "Found: " . $to_delete->count, "\n";
#$to_delete->delete;
