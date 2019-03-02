#!/usr/bin/perl
use warnings;
use strict;
use Daemon::Control;
#use local::lib '/usr/src/perl/libs/access_system/perl5/';
my $path = "/opt/AccessSystem";

exit Daemon::Control->new(
    name        => "AccessSystem-API",
    lsb_start   => '$syslog $remote_fs',
    lsb_stop    => '$syslog',
    lsb_sdesc   => 'AccessSystem API',
    lsb_desc    => 'AccessSystem API controls the AccessSystem API daemon.',
    path        => "$path/script/accesssystem_api_daemon.pl",
    directory   => "$path",
#    init_config => "$path etc/environment",
    user        => 'castaway',
    group       => 'castaway',
    program     => "carton exec $path/script/accesssystem_api_server.pl",
 
    pid_file    => '/tmp/accesssystem_api.pid',
    stderr_file => '/tmp/accesssystem_api.out',
    stdout_file => '/tmp/accesssystem_crud.out',
 
    fork        => 2,
 
    )->run;
