#!/usr/bin/env perl

use DateTime;

$ENV{BARCLAYSCRAPE} ||= '/usr/src/extern/barclayscrape';
$ENV{ACCESS_HOME} ||= '/usr/src/extern/hackspace/AccessSystem';
my $today = DateTime->now()->ymd();
system("$ENV{BARCLAYSCRAPE}/barclayscrape.js --otp $ENV{CODE} get_ofx $ENV{ACCESS_HOME}");
system("cp 20845883789160.ofx $ENV{ACCESS_HOME}/ofx/$today.ofx");
system("scp $ENV{ACCESS_HOME}/ofx/$today.ofx pi\@inside.swindon-makerspace.org:AccessSystem/ofx/");
system('ssh pi@inside.swindon-makerspace.org "cd /home/pi/AccessSystem; CATALYST_HOME=/home/pi/AccessSystem carton exec perl -Ilib /home/pi/AccessSystem/script/update_payments.pl"');
