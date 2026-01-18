package AccessSystem::Fixtures;

use strict;
use warnings;

use DateTime;

=head1 NAME

AccessSystem::Fixtures - Test fixture helpers for AccessSystem tests

=head1 SYNOPSIS

    use lib 't/lib';
    use AccessSystem::Fixtures;

    my $schema = AccessSystem::Schema->connect("dbi:SQLite:test.db");
    $schema->deploy();

    # Create membership tiers
    AccessSystem::Fixtures::create_tiers($schema);

    # Create a test person
    my $person = AccessSystem::Fixtures::create_person($schema, 
        name => 'Test User',
        dob => '1990-01',
    );

=head1 DESCRIPTION

Test fixture helpers for unit tests. Provides functions to create
test data in the database.

=cut

my $person_counter = 0;

=head2 create_tiers($schema)

Create the standard membership tiers used for testing.

=cut

sub create_tiers {
    my ($schema) = @_;
    
    my @tiers = (
        {
            id => 1,
            name => 'Other Hackspace',
            description => 'Member of another hackspace/makerspace',
            price => 500,       # £5
            concessions_allowed => 0,
            in_use => 1,
            restrictions => '{}',
        },
        {
            id => 2,
            name => 'Standard',
            description => 'Standard full membership',
            price => 2500,      # £25
            concessions_allowed => 1,
            in_use => 1,
            restrictions => '{}',
        },
        {
            id => 3,
            name => 'Student',
            description => 'Student membership (requires proof)',
            price => 1250,      # £12.50
            concessions_allowed => 0,
            in_use => 1,
            restrictions => '{}',
        },
        {
            id => 4,
            name => 'Weekend',
            description => 'Weekend access only',
            price => 1500,      # £15
            concessions_allowed => 1,
            in_use => 1,
            restrictions => '{"times":[{"from":"6:00:00","to":"7:23:59"}]}',
        },
        {
            id => 5,
            name => "Men's Shed",
            description => "Men's Shed membership",
            price => 1000,      # £10
            concessions_allowed => 0,
            in_use => 1,
            restrictions => '{}',
        },
    );
    
    for my $tier_data (@tiers) {
        $schema->resultset('Tier')->update_or_create($tier_data);
    }
    
    return;
}

=head2 create_person($schema, %args)

Create a test person. Returns the Person result object.

Accepts optional arguments:
  - name: Person name (defaults to 'Test Person N')
  - email: Email address (defaults to 'test{N}@example.com')
  - dob: Date of birth as 'YYYY-MM' (defaults to '1980-01')
  - address: Address (defaults to '123 Test Street')
  - c_rate: Concessionary rate override (e.g., 'student', 'legacy')
  - tier_id: Tier ID (defaults to 2 = Standard)
  - payment: Payment override (in pence)
  - member_of_other_hackspace: Boolean (defaults to 0)

=cut

sub create_person {
    my ($schema, %args) = @_;
    
    $person_counter++;
    
    my $person_data = {
        name => $args{name} // "Test Person $person_counter",
        email => $args{email} // "test$person_counter\@example.com",
        dob => $args{dob} // '1980-01',
        address => $args{address} // '123 Test Street, Testville, TE5 7ST',
        tier_id => $args{tier_id} // 2,  # Default to Standard tier
    };
    
    # Handle concessionary rate override
    if (defined $args{c_rate}) {
        $person_data->{concessionary_rate_override} = $args{c_rate};
    }
    
    # Handle payment override
    if (defined $args{payment}) {
        $person_data->{payment_override} = $args{payment};
    }
    
    my $person = $schema->resultset('Person')->create($person_data);
    
    return $person;
}

=head2 reset_counter()

Reset the person counter. Useful between test files.

=cut

sub reset_counter {
    $person_counter = 0;
    return;
}

1;

__END__

=head1 AUTHOR

AccessSystem test fixtures

=cut
