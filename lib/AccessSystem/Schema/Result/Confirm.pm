package AccessSystem::Schema::Result::Confirm;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table('confirmations');
__PACKAGE__->load_components('InflateColumn::Serializer');
__PACKAGE__->add_columns(
    person_id => {
        data_type => 'integer',
    },
    token => {
        data_type => 'varchar',
        size => 36,
    },
    storage => {
        data_type => 'varchar',
        size => 1024,
        'serializer_class'   => 'JSON',
    },
);

__PACKAGE__->set_primary_key('token');
__PACKAGE__->belongs_to('person', 'AccessSystem::Schema::Result::Person', 'person_id');

1;

