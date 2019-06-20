#!/usr/bin/perl

# use local::lib '/usr/src/perl/libs/accesssystem/perl5';
use Config::General;
use DateTime;

use lib "$ENV{CATALYST_HOME}/lib";
use AccessSystem::Schema;
use OFX::Parse;

=head1 NAME membership_payments

=head1 DESCRIPTION

This script runs regularly to create payment rows for members, using
the imported transactions from the bank (and other places maybe). New
payment rows are created if the member is about to expire, or hasnt
yet paid, and has enough balance in their account.

=head2 VALIDITY

The amount each member should pay per month is calculated, see
L<AccessSystem::Schema::Result::Person/dues>. A payment from that
member should be a multiple of that value, OR 12 months - 10%.

An expiry date is calculated for the dues row, which is based on, and
extends, the expiry_date of any previous payments, if the member is
currently/still valid.

Possible types of dues row/imported payments:

=over

=item First member payment

is valid from its paid-on date and expires Amount/Monthly months + $OVERLAP_DAYS
days later.

=item Extending payment

is paid when the member still has a valid payment, expires
Amount/Monthly months later.

=item Renewal payment

is paid when the member has expired (due to non payment), begins on
paid-on date, expires Amount/Monthly months + $OVERLAP_DAYS days later.

=back

NB: The "Overlap days" is to allow for underlapping Standing Order payments,
which may be slightly over a month apart due to not happening on
weekends or bank holidays.

=head2 TWEAKS

The fiddle_payment function rejects (returns true) or amends a
transaction row for those instances where we know they are incorrect.

=cut

if(!$ENV{CATALYST_HOME}) {
    die "Please set the CATALYST_HOME environment variable and try again\n";
}

my $OVERLAP_DAYS = 14;

# Read config to get db connection info:
my %config = Config::General->new("$ENV{CATALYST_HOME}/accesssystem_api.conf")->getall;
my $schema = AccessSystem::Schema->connect(
    $config{'Model::AccessDB'}{connect_info}{dsn},
    $config{'Model::AccessDB'}{connect_info}{user},
    $config{'Model::AccessDB'}{connect_info}{password},
    );

my $people_rs = $schema->resultset('Person');
while (my $person = $people_rs->next) {
    next if $person->parent_id;
    $person->create_payment($OVERLAP_DAYS);
}

# Update membership table, based on current validity of members:
# $schema->resultset('Person')->update_member_register();
