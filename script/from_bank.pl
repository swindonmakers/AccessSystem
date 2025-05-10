#!/usr/bin/env perl

use DateTime;

$ENV{BARCLAYSCRAPE} ||= '/usr/src/extern/barclayscrape';
$ENV{ACCESS_HOME} ||= '/usr/src/extern/hackspace/AccessSystem';
my $today = DateTime->now()->ymd();
system("$ENV{BARCLAYSCRAPE}/barclayscrape.js --otp $ENV{CODE} get_ofx $ENV{ACCESS_HOME}");
system("cp 20845883789160.ofx $ENV{ACCESS_HOME}/ofx/$today.ofx");
system("scp -P 2222 $ENV{ACCESS_HOME}/ofx/$today.ofx castaway\@inside.swindon-makerspace.org:/opt/AccessSystem/ofx/");
system('ssh -p 2222 castaway@inside.swindon-makerspace.org "cd /opt/AccessSystem; CATALYST_HOME=/opt/AccessSystem carton exec perl -Ilib /opt/AccessSystem/script/update_payments.pl"');
system('ssh -p 2222 castaway@inside.swindon-makerspace.org "cd /opt/AccessSystem; CATALYST_HOME=/opt/AccessSystem carton exec perl -Ilib /opt/AccessSystem/script/membership_payments.pl"');
system('ssh -p 2222 castaway@inside.swindon-makerspace.org "cd /opt/AccessSystem; CATALYST_HOME=/opt/AccessSystem carton exec perl -Ilib /opt/AccessSystem/script/send_communications.pl"');

