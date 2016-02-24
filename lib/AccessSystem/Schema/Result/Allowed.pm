package AccessSystem::Schema::Result::Allowed;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table('allowed');
__PACKAGE__->add_columns(
    person_id => {
        data_type => 'integer',
    },
    accessible_thing_id => {
        data_type => 'integer',
    },
    is_admin => {
        data_type => 'boolean',
    },
);

__PACKAGE__->set_primary_key('person_id', 'accessible_thing_id');
__PACKAGE__->belongs_to('person', 'AccessSystem::Schema::Result::Person', 'person_id');
__PACKAGE__->belongs_to('accessible_thing', 'AccessSystem::Schema::Result::AccessibleThing', 'accessible_thing_id');

1;

