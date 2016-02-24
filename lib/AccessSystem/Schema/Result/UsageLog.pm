package AccessSystem::Schema::Result::UsageLog;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components('InflateColumn::DateTime', 'TimeStamp');

__PACKAGE__->table('usage_log');
__PACKAGE__->add_columns(
    person_id => {
        data_type => 'integer',
    },
    accessible_thing_id => {
        data_type => 'integer',
    },
    accessed_date => {
        data_type => 'datetime',
        set_on_create => 1,
    },
);

__PACKAGE__->belongs_to('person', 'AccessSystem::Schema::Result::Person', 'person_id');
__PACKAGE__->belongs_to('accessible_thing', 'AccessSystem::Schema::Result::AccessibleThing', 'accessible_thing_id');

1;

