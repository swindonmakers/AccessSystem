package AccessSystem::Schema::Result::AccessibleThing;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table('accessible_things');

__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
    },
    name => {
        data_type => 'varchar',
        size => 255,
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint('name' => ['name']);

1;
