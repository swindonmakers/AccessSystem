#!/usr/bin/perl

use strict;
use warnings;

use Config::General;
use lib "$ENV{CATALYST_HOME}/lib";
use AccessSystem::Schema;

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
# Find date of most recently imported payments

my @machines = ('Horizontal Bandsaw',
                'Chinese Lathe',
                'Colchester Lathe',
                'Brigeport Mill',
                'MIG Welder',
                'TIG Welder',
                'Plasma Cutter',
                'Proxxon',
                'Shapoko',
                'Sand Blaster',
                'Bench Grinder',
                'HPC Laser',
                'FDM Printers',
                'Resin Printer',
                'T-Shirt & Mug Press',
                'Industrial Sewing Machine',
                'Table Saw',
                'Mitre Saw',
                'Planer / Thicknesser',
                'Wood Lathe',
                'Big Pillar Drill',
                'Vertical Bandsaw',
                'Pillar Drill',
                'Band Saw',
                'Sander',
                'Fret Saw',
                'Mortiser',
                'Router Table');
@machines = map { $schema->resultset('Tool')->find_or_create({ name => $_, requires_induction => 1 }) } (@machines);
while(my $line = <>) {
    chomp($line);
    my ($name, @values) = split(/,/, $line);
    my $person = $schema->resultset('Person')->find_person($name);
    if (!$person) {
        next;
    }
    foreach my $tool (@machines) {
        my $val = shift(@values);
        my $is_admin = $val =~ /(inductor|owner)/i ? 1 : 0;
        $person->find_or_create_related('allowed', { tool_id => $tool->id, is_admin => $is_admin });
    }
}
