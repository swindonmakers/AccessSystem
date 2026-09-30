#!/usr/bin/env perl

use DateTime;

$ENV{ACCESS_HOME} ||= '/usr/src/extern/hackspace/AccessSystem';
my $today = DateTime->now()->ymd();

if(!-e "$ENV{ACCESS_HOME}/ofx/$today.ofx") {
    print "Not updating piserver\n";
    exit;
}

# Running on AccessServer VM, updating piserver while we have both running
system("scp $ENV{ACCESS_HOME}/ofx/$today.ofx castaway\@192.168.1.124:/opt/AccessSystem/ofx/");
system('ssh castaway@192.168.1.124 "cd /opt/AccessSystem; CATALYST_HOME=/opt/AccessSystem carton exec perl -Ilib /opt/AccessSystem/script/update_payments.pl"');
system('ssh castaway@192.168.1.124 "cd /opt/AccessSystem; CATALYST_HOME=/opt/AccessSystem carton exec perl -Ilib /opt/AccessSystem/script/membership_payments.pl"');
