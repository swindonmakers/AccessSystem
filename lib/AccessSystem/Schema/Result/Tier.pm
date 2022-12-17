package AccessSystem::Schema::Result::Tier;

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 NAME

AccessSystem::Schema::Result::Tier

=head1 DESCRIPTION

Database class membership tier types and associated costs/restrictions

=head1 FIELDS

=head2 id

Numeric identifier.

=head2 name

Short name of the Tier

=head2 description

Long description of the tier

=head2 price

(Minimum) cost of the tier in pence

=head2 concessions_allowed

Does this tier allow concessions (half costs)

=head2 dont_use

This tier can no longer be picked at registration (but we still take money from older signups to it)

=head2 restrictions

Json string of time/door access restrictions in the format:

    {'times': [ .. list of restrictions ]}

Restrictions are from/to day of week, hour, minute pairs, eg:

    {"from":"6:00:00","to":"7:23:59"} - access Saturnday 10:00 to Sunday 23:59

Days of the week map to L<DateTime/day_of_week>, 1=Monday, 7=Sunday. We're doing simple >= / <= comparisons, so don't be clever trying to make from from day 7 to day 2!

Usage code is in L<AccessSystem::Schema::ResultSet::Person/allowed_to_thing>.

=cut

__PACKAGE__->load_components('InflateColumn::Serializer');
__PACKAGE__->table('tiers');
__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
    },
    name => {
        data_type => 'varchar',
        size => 50,
        is_nullable => 0,
    },
    description => {
        data_type => 'varchar',
        size => 2048,
        default_value => '',
    },
    price => {
        data_type => 'integer',
        is_nullable => 0,
    },
    concessions_allowed => {
        data_type => 'boolean',
        default_value => 1,
        is_nullable => 0,
    },
    in_use => {
        data_type => 'boolean',
        default_value => 1,
        is_nullable => 0,
    },
    restrictions => {
        data_type => 'varchar',
        size => 2048,
        'serializer_class'   => 'JSON',
        'serializer_options' => { allow_blessed => 1, convert_blessed => 1, pretty => 1 },
        default_value => '{}',
        is_nullable => 0,
    }
    );

__PACKAGE__->set_primary_key('id');

__PACKAGE__->add_unique_constraint('tier_name' => ['name']);

__PACKAGE__->has_many('people', 'AccessSystem::Schema::Result::Person', 'tier_id');

sub display_name_and_price {
    my ($self) = @_;

    return sprintf("%s (&pound;%.2f/month)", $self->name, $self->price/100);
}

1;

