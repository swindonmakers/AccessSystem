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
    created_on => {
        data_type => 'datetime',
        set_on_create => 1,
        default_value => \'CURRENT_TIMESTAMP'
    },
    sent_on => {
        data_type => 'datetime',
        is_nullable => 1,
    },
    type => {
        data_type => 'varchar',
        size => 50,
    },
    status => {
        data_type => 'varchar', #enum ideally but lazy
        size => 10,
        default_value => 'unsent',
    },
    subject => {
        data_type => 'varchar',
        size => 1024,
        default_value => 'Communication from Swindon Makerspace',
    },
    # was 'content'
    plain_text => {
        data_type => 'varchar',
        size => 10240,
    },
    html => {
        data_type => 'varchar',
        size => 10240,
        is_nullable => 1,
    },
    );
__PACKAGE__->set_primary_key('person_id', 'type');

__PACKAGE__->belongs_to('person', 'AccessSystem::Schema::Result::Person', 'person_id' );

1;
