#!/usr/bin/perl

use strict;
use warnings;

use Config::General;
use lib "$ENV{CATALYST_HOME}/lib";
use AccessSystem::Schema;
use Text::CSV_XS 'csv';
use feature 'state', 'say';

my $csv_filename = shift or die "Please pass the filename of the .csv from the google sheet";

my $create_tools = 0;

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


my $csv_aoa = csv(in => $csv_filename, binary => 1);
# The first line is instructions, ignore it.
shift @$csv_aoa;

# name in spreadsheet => name in database
# => undef means do not import into database at all.
state $machines_translation = {
    'Chinese Mill' => undef,
    'Resin printer' => 'Resin Printer',
    'Laser Cutter' => 'HPC Laser',
    # Future me's problem: disambuigate between inductions and tools.
    'Prusa i3 MK2 3D Printer' => 'FDM Printers',
    'Wanhao 3D Printer' => 'FDM Printers',
    'Shapoko' => undef,
};

my @machines = @{shift @$csv_aoa};
$machines[0] = undef;
for my $n (1..$#machines) {
    $_ = $machines[$n];
    next if not defined $_;

    # Normalize whitespace
    s/\s+/ /g;
    s/^\s+//;
    s/\s$//;

    if (exists $machines_translation->{$_}) {
        $_ = $machines_translation->{$_};
    }
    $machines[$n] = $_;
    next if not defined $_;


    my $tool_row;
    if ($create_tools) {
        $tool_row = $schema->resultset('Tool')->find_or_create({name => $_, requires_induction => 1, team => 'Unknown'});
    } else {
        $tool_row = $schema->resultset('Tool')->find({name => $_});
        if (!$tool_row) {
            say STDERR qq<Cannot find tool named "$_", add to machines_translation or create it?>;
        }
    }

    $machines[$n] = $tool_row;
}

state $people_translation = {};
for my $row (@$csv_aoa) {
    my $person_name = $row->[0];

    $person_name =~ s/\s+/ /g;
    $person_name =~ s/^\s+//;
    $person_name =~ s/\s+$//;

    my $person_row = $schema->resultset('Person')->find_person($person_name);
    if (not $person_row) {
        say STDERR "Cannot find person row for '$person_name'?";
        next;
    }

    for (1..$#machines) {
        my $val = lc $row->[$_];
        my $machine_row = $machines[$_];
        next if !$machine_row;

        if (not $val) {
            next;
        } elsif ($val eq 'x') {
            # Won't overwrite an existing admin premission, which I think is what we want.
            $person_row->find_or_create_related('allowed', { tool_id => $machine_row->id, is_admin => 0 });
        } elsif ($val =~ /^(owner|loan|inductor).*/s) {
            # Some strange bits appear against Damian, thus the .*
            # Won't overwrite an existing not-admin premission, which I'm not sure about.
            my $allowed = $person_row->find_or_create_related('allowed', { tool_id => $machine_row->id, is_admin => 1 });
            $allowed->update({ is_admin => 1 });
        } else {
            die "Unhandled induction val '$val' for $person_name / ".$machine_row->name;
        }
    }
}
