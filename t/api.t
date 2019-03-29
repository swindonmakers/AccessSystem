
use strict;
use warnings;

use Test::More;
use JSON::MaybeXS;
BEGIN: {
    $ENV{ MYAPP_CONFIG_LOCAL_SUFFIX } = 'testing';
};

use Catalyst::Test 'AccessSystem::API';

action_ok('/login');

done_testing;


