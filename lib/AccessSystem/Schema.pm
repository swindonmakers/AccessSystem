package AccessSystem::Schema;

use strict;
use warnings;

use base 'DBIx::Class::Schema';

our $VERSION = '18.0';

__PACKAGE__->load_namespaces();

sub the_door {
    my ($self) = @_;

    return $self->resultset('Tool')->find({ name => 'The Door'});
}

1;
