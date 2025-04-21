#!/usr/bin/perl
use warnings;
use strict;
use local::lib '/workspaces/AccessSystem/local/lib/perl5/';
use Daemon::Control;
my $path = "/workspaces/AccessSystem";

exit Daemon::Control->new(
    name        => "AccessSystem-CRUD",
    lsb_start   => '$syslog $remote_fs',
    lsb_stop    => '$syslog',
    lsb_sdesc   => 'AccessSystem CRUD',
    lsb_desc    => 'AccessSystem CRUD controls the AccessSystem CRUD daemon.',
    path        => "$path/script/accesssystem_daemon_devcontainer.pl",
    directory   => "$path",
#    init_config => "$path etc/environment",
    user        => 'swmakers',
    group       => 'swmakers',
    program     => "carton exec $path/script/accesssystem_server.pl --restart --port 3001  > /proc/1/fd/1 2> /proc/1/fd/2",
 
    pid_file    => '/tmp/accesssystem_crud.pid',
    stderr_file => '/proc/1/fd/2',
    stdout_file => '/proc/1/fd/1',
 
    fork        => 2,
 
    )->run;
