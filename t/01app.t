#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Catalyst::Test 'AccessSystem::API';

ok( request('/register')->is_success, 'Request should succeed' );

done_testing();
