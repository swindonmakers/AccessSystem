package AccessSystem::Schema::Result::Person;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components('InflateColumn::DateTime', 'TimeStamp');

__PACKAGE__->table('person');
__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
    },
    name => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 0.
    },
    email => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 0,
    },
    is_member => {
        data_type => 'boolean',
        default_value => \'false',#',
    },
    created_date => {
        data_type => 'datetime',
        set_on_create => 1,
    },
    end_date => {
        data_type => 'datetime',
        is_nullable => 1,
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint('email' => ['email']);

1;
