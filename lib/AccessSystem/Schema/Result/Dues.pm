package AccessSystem::Schema::Result::Dues;

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 NAME

AccessSystem::Schema::Result::Dues

=head1 DESCRIPTION

Dues table

Tracks transactions / membership payments - each row reflects a
payment, and states whe it was made, when it expires (the import code
will magically figure this out, based on the number of current
childred attached and whether is_concession is set), the amount
(mainly for tracking purposes), and the person.

We trust that the import code has checked that the amount paid is
correct. (!)

See also L<AccessSystem::Schema::Result::Person/is_valid>.

=cut

__PACKAGE__->load_components('InflateColumn::DateTime');

__PACKAGE__->table('dues');
__PACKAGE__->add_columns(
    person_id => {
        data_type => 'integer',
    },
    paid_on_date => {
        data_type => 'datetime',
    },
    expires_on_date => {
        data_type => 'datetime',
    },
    amount_p => {
        data_type => 'integer',
    },
);

__PACKAGE__->set_primary_key('person_id', 'paid_on_date');
__PACKAGE__->belongs_to('person', 'AccessSystem::Schema::Result::Person', 'person_id');

1;
