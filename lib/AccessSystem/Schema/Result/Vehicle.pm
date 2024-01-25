package AccessSystem::Schema::Result::Vehicle;

use strict;
use warnings;

use DateTime;

use base 'DBIx::Class::Core';

=head1 NAME

AccessSystem::Schema::Result::PersonVehicle

=head1 DESCRIPTION

Database class representing member vehicles (we blame BSS house for
wanting reg data)

=head1 FIELDS

=head2 person_id

Numeric identifier of the member

=head2 plate_reg

Reg plate of the vehicle, all caps no non-letters

=head2 added_on

Date it was created (just for sorting / checking if valid purposes)

=cut

__PACKAGE__->load_components('InflateColumn::DateTime', 'TimeStamp');

__PACKAGE__->table('vehicles');
__PACKAGE__->add_columns(
    person_id => {
        data_type => 'integer',
    },
    plate_reg => {
        data_type => 'varchar',
        size => 7,
    },
    added_on => {
        data_type => 'datetime',
        set_on_create => 1,
    },
    );
__PACKAGE__->set_primary_key('person_id', 'plate_reg');


__PACKAGE__->belongs_to('person', 'AccessSystem::Schema::Result::Person', 'person_id');

1;
