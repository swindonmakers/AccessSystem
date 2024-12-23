#!/usr/bin/perl
use warnings;
use strict;
use local::lib '/workspaces/AccessSystem/local/lib/perl5/';
use Daemon::Control;
my $path = "/workspaces/AccessSystem";

exit Daemon::Control->new(
    name        => "AccessSystem-API",
    lsb_start   => '$syslog $remote_fs',
    lsb_stop    => '$syslog',
    lsb_sdesc   => 'AccessSystem API',
    lsb_desc    => 'AccessSystem API controls the AccessSystem API daemon.',
    path        => "$path/script/accesssystem_api_daemon_devcontainer.pl",
    directory   => "$path",
#    init_config => "$path etc/environment",
    user        => 'swmakers',
    group       => 'swmakers',
    program     => "carton exec $path/script/accesssystem_api_server.pl --restart --port 3000 > /proc/1/fd/1 2> /proc/1/fd/2",
 
    pid_file    => '/tmp/accesssystem_api.pid',
    stderr_file => '/proc/1/fd/2',
    stdout_file => '/proc/1/fd/1',
 
    fork        => 2,

    )->run;
