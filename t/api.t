
use strict;
use warnings;

use JSON::MaybeXS;
BEGIN: {
    $ENV{ MYAPP_CONFIG_LOCAL_SUFFIX } = 'testing';
};

use Catalyst::Test 'AccessSystem';

my ($res, $ctx) = ctx_request('/admin/login');

