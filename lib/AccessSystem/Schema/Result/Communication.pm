package AccessSystem::Schema::Result::Communication;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components('InflateColumn::DateTime', 'TimeStamp');
__PACKAGE__->table('communications');
__PACKAGE__->add_columns(
    person_id => {
        data_type => 'integer',
    },
    sent_on => {
        data_type => 'datetime',
        set_on_create => 1,
    },
    type => {
        data_type => 'varchar',
        size => 50,
    },
    status => {
        data_type => 'varchar', #enum ideally but lazy
        size => 10,
        default => 'unsent',
    },
    content => {
        data_type => 'varchar',
        size => 10240,
    },
    );
__PACKAGE__->set_primary_key('person_id', 'sent_on');

__PACKAGE__->belongs_to('person', 'AccessSystem::Schema::Result::Person', 'person_id' );

1;
