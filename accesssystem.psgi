use strict;
use warnings;

use AccessSystem;

my $app = AccessSystem->apply_default_middlewares(AccessSystem->psgi_app);
$app;

