package AccessSystem::Schema::Result::MemberRegister;

use strict;
use warnings;

use DateTime;

use base 'DBIx::Class::Core';

=head1 NAME

AccessSystem::Schema::Result::MemberRegister

=head1 DESCRIPTION

All membership register data; must store data for 10 years (even after
member has deleted themselves from the main register / Person
table). Note that this table may contain the same persons multiple
times, they are deemed to have stopped being a member when payment
ceases, and restarted when payment restarts.

=head1 FIELDS

=head2 name

Person's name, as entered on the register form

=head2 address

Person's residential or contact address, as entered on the register form.

=head2 started_date

Date the person became a member

=head2 ended_date

Date the person ceased to be a member

=head2 updated_date

Date the row was last updated/edited

=head2 updated_reason

Description of why the row was updated.

=cut

__PACKAGE__->load_components('InflateColumn::DateTime', 'TimeStamp');

__PACKAGE__->table('membership_register');
__PACKAGE__->add_columns(
    name => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 0,
    },
    address => {
        data_type => 'varchar',
        size => 1024,
        is_nullable => 0,
    },
    started_date => {
        data_type => 'date',
        set_on_create => 1,
        is_nullable => 0,
    },
    ended_date => {
        data_type => 'date',
        is_nullable => 1,
    },
    updated_date => {
        data_type => 'datetime',
        is_nullable => 1,
    },
    updated_reason => {
        data_type => 'varchar',
        size => 1024,
        is_nullable => 0,
    },
);

__PACKAGE__->set_primary_key(qw/name started_date/);

1;
