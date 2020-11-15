package AccessSystem::Schema::Result::ToolStatus;

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 NAME

AccessSystem::Schema::Result::ToolStatus

=head1 DESCRIPTION

Status (and past statuses) of our tools

=head1 ATTRIBUTES

=head2 id

=head2 tool_id

=head2 when

=head2 who_id

=head2 status (enum)

=head2 description

=cut

__PACKAGE__->load_components(qw/InflateColumn::DateTime TimeStamp/);

__PACKAGE__->table('tool_status');

__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
    },
    tool_id => {
        data_type => 'integer',
    },
    entered_at => {
        data_type => 'datetime',
        set_on_create => 1,
    },
    who_id => {
        data_type => 'integer',
    },
    status => {
        data_type => 'varchar',
        size => 20,
    },
    description => {
        data_type => 'varchar',
        size => 1024,
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to('tool', 'AccessSystem::Schema::Result::Tool', 'tool_id');
__PACKAGE__->belongs_to('who', 'AccessSystem::Schema::Result::Person', 'who_id');

1;
