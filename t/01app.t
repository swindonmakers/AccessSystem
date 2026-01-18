#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Cwd qw(getcwd);

# Set CATALYST_HOME so config is loaded correctly
$ENV{CATALYST_HOME} = getcwd();

use lib 't/lib';
use AccessSystem::Schema;
use AccessSystem::Fixtures;

# Use the same database that the config specifies
# The test config uses dbi:SQLite:test_db.db
my $testdb = 'test_db.db';
unlink $testdb if -e $testdb;  # Start fresh

# Deploy schema and create fixtures
my $schema = AccessSystem::Schema->connect("dbi:SQLite:$testdb");
$schema->deploy();
AccessSystem::Fixtures::create_tiers($schema);

use Catalyst::Test 'AccessSystem::API';

# Test that the app loads and responds to requests
ok( request('/login')->is_success, 'Request to /login should succeed' );
ok( request('/register')->is_success, 'Request to /register should succeed' );

# Clean up
unlink($testdb);

done_testing();
