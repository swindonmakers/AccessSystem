package AccessSystem::Schema::Result::MessageLog;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components('InflateColumn::DateTime', 'TimeStamp');

__PACKAGE__->table('message_log');
__PACKAGE__->add_columns(
    tool_id => {
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

__PACKAGE__->set_primary_key('tool_id', 'written_date');
__PACKAGE__->belongs_to('tool', 'AccessSystem::Schema::Result::Tool', 'tool_id');
__PACKAGE__->has_one('message_log_view', 'AccessSystem::Schema::Result::MessageLog', { 'foreign.tool_id' => 'self.tool_id', 'foreign.written_date' => 'self.written_date' });

1;

