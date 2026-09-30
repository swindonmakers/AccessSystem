#!/usr/bin/env perl

use DateTime;

$ENV{BARCLAYSCRAPE} ||= '/usr/src/extern/barclayscrape';
$ENV{ACCESS_HOME} ||= '/usr/src/extern/hackspace/AccessSystem';
my $today = DateTime->now()->ymd();
if(-e '20845883789160.ofx') {
    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
        $atime,$mtime,$ctime,$blksize,$blocks)
        = stat('20845883789160.ofx');
    my $dt = DateTime->from_epoch(epoch => $atime);
    if($dt->add(days => 1) < DateTime->now()) {
        system('rm 20845883789160.ofx');
    }
}
chdir($ENV{BARCLAYSCRAPE});
system("node barclayscrape.js --no-headless get_ofx $ENV{ACCESS_HOME}");
chdir($ENV{ACCESS_HOME});
if(-e '20845883789160.ofx') {
    system("cp 20845883789160.ofx $ENV{ACCESS_HOME}/ofx/$today.ofx");
    system("scp -P 2222 $ENV{ACCESS_HOME}/ofx/$today.ofx castaway\@inside.swindon-makerspace.org:/opt/AccessSystem/ofx/");
    system('ssh -p 2222 castaway@inside.swindon-makerspace.org "cd /opt/AccessSystem; CATALYST_HOME=/opt/AccessSystem carton exec perl -Ilib /opt/AccessSystem/script/update_payments.pl"');
    system('ssh -p 2222 castaway@inside.swindon-makerspace.org "cd /opt/AccessSystem; CATALYST_HOME=/opt/AccessSystem carton exec perl -Ilib /opt/AccessSystem/script/membership_payments.pl"');
    system('ssh -p 2222 castaway@inside.swindon-makerspace.org "cd /opt/AccessSystem; CATALYST_HOME=/opt/AccessSystem carton exec perl -Ilib /opt/AccessSystem/script/update_piserver.pl"');
} else {
    print "NO NEW BANK DATA!\n";
    system('ssh -p 2222 castaway@inside.swindon-makerspace.org "cd /opt/AccessSystem; CATALYST_HOME=/opt/AccessSystem carton exec perl -Ilib /opt/AccessSystem/script/membership_payments.pl --no_bank_transactions"');
}
system('ssh -p 2222 castaway@inside.swindon-makerspace.org "cd /opt/AccessSystem; CATALYST_HOME=/opt/AccessSystem carton exec perl -Ilib /opt/AccessSystem/script/send_communications.pl"');
    
