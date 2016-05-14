package AccessSystem::Schema::Result::MessageLog;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components('InflateColumn::DateTime', 'TimeStamp');

__PACKAGE__->table('message_log');
__PACKAGE__->add_columns(
    accessible_thing_id => {
        data_type => 'varchar',
        size => 40,
    },
    message => {
        data_type => 'varchar',
        size => 2048,
    },
    from_ip => {
        data_type => 'varchar',
        size => 15,        
    },
    written_date => {
        data_type => 'datetime',
        set_on_create => 1,
    },
);

__PACKAGE__->set_primary_key('accessible_thing_id', 'written_date');
__PACKAGE__->belongs_to('accessible_thing', 'AccessSystem::Schema::Result::AccessibleThing', 'accessible_thing_id');

1;

