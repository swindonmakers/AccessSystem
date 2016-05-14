package AccessSystem::Schema::Result::UsageLog;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components('InflateColumn::DateTime', 'TimeStamp');

__PACKAGE__->table('usage_log');
__PACKAGE__->add_columns(
    person_id => {
        data_type => 'integer',
        is_nullable => 1,
    },
    accessible_thing_id => {
        data_type => 'varchar',
        size => 40,
    },
    token_id => {
        data_type => 'varchar',
        size => 255,
    },
    status => {
        data_type => 'varchar',
        size => 20,
    },
    accessed_date => {
        data_type => 'datetime',
        set_on_create => 1,
    },
);

__PACKAGE__->set_primary_key('accessible_thing_id', 'accessed_date');
__PACKAGE__->belongs_to('person', 'AccessSystem::Schema::Result::Person', 'person_id', { join_type => 'left'});
## We log the thing id even if its not a known thing id:
__PACKAGE__->belongs_to('accessible_thing', 'AccessSystem::Schema::Result::AccessibleThing', 'accessible_thing_id', { join_type => 'left'});

1;

