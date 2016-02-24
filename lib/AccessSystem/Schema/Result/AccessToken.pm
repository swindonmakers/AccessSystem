package AccessSystem::Schema::Result::AccessToken;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table('access_tokens');
__PACKAGE__->add_columns(
    id => {
        data_type => 'varchar',
        size => 255,
    },
    person_id => {
        data_type => 'integer',
    },
    type => {
        data_type => 'varchar',
        size => 20,
    }
);

__PACKAGE__->set_primary_key('person_id', 'type');
__PACKAGE__->belongs_to('person', 'AccessSystem::Schema::Result::Person', 'person_id');

1;
