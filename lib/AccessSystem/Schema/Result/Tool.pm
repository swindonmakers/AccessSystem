package AccessSystem::Schema::Result::Tool;

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 NAME

AccessSystem::Schema::Result::Tool

=head1 DESCRIPTION

A Makerspace tool (or the Door!) - for tracking status, inductions, usage.

=head1 ATTRIBUTES

=head2 id

UUID column of tool id

=head2 name

Unique name of tool

=head2 assigned_ip

IP of tool (or its access hardware) if on the network / required for usage.

NULLable (no IP)

=head2 requires_induction

True/False - does it require the user to have been inducted

=head2 team

Team name (maybe more complex later?)

=cut

__PACKAGE__->load_components(qw/UUIDColumns/);

__PACKAGE__->table('tools');

__PACKAGE__->add_columns(
    id => {
        data_type => 'varchar',
        size => 40,
    },
    name => {
        data_type => 'varchar',
        size => 255,
    },
    assigned_ip => {
        data_type => 'varchar',
        size => 15,
        is_nullable => 1,
    },
    requires_induction => {
        data_type => 'boolean',
#        default_value => 'false', #'
    },
    team => {
        data_type => 'varchar',
        size => 50,
    },
);

__PACKAGE__->uuid_columns(qw/id/);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint('name' => ['name']);

__PACKAGE__->has_many('allowed_people', 'AccessSystem::Schema::Result::Allowed', 'tool_id');
__PACKAGE__->has_many('logs', 'AccessSystem::Schema::Result::MessageLog', 'tool_id');
__PACKAGE__->has_many('statuses', 'AccessSystem::Schema::Result::ToolStatus', 'tool_id');

sub current_status {
    my ($self) = @_;

    ## Must be at least one?
    my $last = $self->statuses_rs->search(
        {},
        {
            order_by => [{ '-desc' => 'when' }],
            rows => 1,
        })->single;

    return $last;
    
}

sub induct_student {
    my ($self, $admin_token, $student_token) = @_;

    my $admin_check = $self->allowed_people_rs->search(
        {
            'is_admin' => 1,
            'tokens.id' => $admin_token,
        },
        {
            join => { person => 'tokens' }
        }
    );

    if(!$admin_check->count || $admin_check->count > 1) {
        return {
            error => 'That teacher token does not belong to a single admin user of the ' . $self->name . ' (or belongs to more than one person, huh?)'
        };
    }

    my $student = $self->result_source->schema->resultset('Person')->find(
        {
            'tokens.id' => $student_token,
        }, 
        {
            join => ['allowed', 'tokens' ],
        }
    );
    if(!$student) {
        return {
            error => "The token ($student_token) isn't associated with any user",
        };
    }
    
    my $added = $self->allowed_people_rs->find_or_create({
        person => $student,
        is_admin => 0,
    });
    return {
        person => $student,
    };
}

1;
