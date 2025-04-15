package AccessSystem::Schema::Result::RequiredTool;

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 NAME

AccessSystem::Schema::Result::RequiredTool

=head1 DESCRIPTION

M2M Tool dependency map

=head1 ATTRIBUTES

=head2 required_id

UUID of required tool

=head2 tool_id

UUID of parent tool

=cut

__PACKAGE__->table('required_tools');

__PACKAGE__->add_columns(
    required_id => {
        data_type => 'varchar',
        size => 40,
    },
    tool_id => {
        data_type => 'varchar',
        size => 40,
    },
);

__PACKAGE__->set_primary_key('required_id', 'tool_id');

__PACKAGE__->belongs_to('tool', 'AccessSystem::Schema::Result::Tool', 'tool_id');
__PACKAGE__->belongs_to('required', 'AccessSystem::Schema::Result::Tool', 'tool_id');

1;
