package AccessSystem::Schema::Result::Allowed;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components(qw/InflateColumn::DateTime TimeStamp UUIDColumns/);

__PACKAGE__->table('allowed');

__PACKAGE__->add_columns(
    person_id => {
        data_type => 'integer',
    },
    accessible_thing_id => {
        data_type => 'varchar',
        size => 40,
    },
    is_admin => {
        data_type => 'boolean',
    },
    added_on => {
        data_type => 'datetime',
        set_on_create => 1,
        is_nullable => 0,
    }
);

__PACKAGE__->uuid_columns(qw/accessible_thing_id/);
__PACKAGE__->set_primary_key('person_id', 'accessible_thing_id');
__PACKAGE__->belongs_to('person', 'AccessSystem::Schema::Result::Person', 'person_id');
__PACKAGE__->belongs_to('accessible_thing', 'AccessSystem::Schema::Result::AccessibleThing', 'accessible_thing_id');

1;

