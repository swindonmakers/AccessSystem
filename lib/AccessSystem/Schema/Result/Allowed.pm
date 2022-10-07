package AccessSystem::Schema::Result::Allowed;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components(qw/InflateColumn::DateTime TimeStamp UUIDColumns/);

__PACKAGE__->table('allowed');

__PACKAGE__->add_columns(
    person_id => {
        data_type => 'integer',
    },
    tool_id => {
        data_type => 'varchar',
        size => 40,
    },
    is_admin => {
        data_type => 'boolean',
    },
    pending_acceptance => {
        data_type => 'boolean',
        default_value => 'true',
    },
    accepted_on => {
        data_type => 'datetime',
        is_nullable => 1,
    },
    added_on => {
        data_type => 'datetime',
        set_on_create => 1,
        is_nullable => 0,
    }
);

__PACKAGE__->uuid_columns(qw/tool_id/);
__PACKAGE__->set_primary_key('person_id', 'tool_id');
__PACKAGE__->belongs_to('person', 'AccessSystem::Schema::Result::Person', 'person_id');
__PACKAGE__->belongs_to('tool', 'AccessSystem::Schema::Result::Tool', 'tool_id');

sub pending {
    my ($self) = @_;

    if ($self->result_source->schema->storage->sqlt_type =~ /sqlite/i) {
        if ($self->pending_acceptance eq 'true') {
            return 1;
        } else {
            return 0;
        }
    }
    return $self->pending_acceptance;
}

1;

