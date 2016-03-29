package AccessSystem::Schema::Result::AccessibleThing;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components(qw/UUIDColumns/);

__PACKAGE__->table('accessible_things');

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
    },
);

__PACKAGE__->uuid_columns(qw/id/);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint('name' => ['name']);

__PACKAGE__->has_many('allowed_people', 'AccessSystem::Schema::Result::Allowed', 'accessible_thing_id');

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
