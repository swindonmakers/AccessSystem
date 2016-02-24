package AccessSystem::Schema::Result::Dues;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components('DateTime');

__PACKAGE__->table('dues');
__PACKAGE__->add_columns(
    person_id => {
        data_type => 'integer',
    },
    for_month => {
        data_type => 'integer',
        is_nullable => 0,
    }
    is_paid => {
        data_type => 'boolean',
        default_value => \'false', #',
        is_nullable => 0,
    },
    paid_on_date => {
        data_type => 'datetime',
    },
    amount => {
        data_type => 'integer',
    },
);

__PACKAGE__->set_primary_key('person_id', 'for_month');
__PACKAGE__->belongs_to('person', 'AccessSystem::Schema::Result::Person', 'person_id');

1;
