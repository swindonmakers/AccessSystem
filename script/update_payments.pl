#!/usr/bin/perl

# use local::lib '/usr/src/perl/libs/accesssystem/perl5';
use Config::General;
use DateTime;

use lib "$ENV{CATALYST_HOME}/lib";
use AccessSystem::Schema;
use OFX::Parse;

=head1 NAME update_payments

=head1 DESCRIPTION

This script checks for B<.ofx> files in the F<ofx/> directory which
should be exported from the Makerspace Barclays account, and named for
the date they were exported. Any files dated newer than the most
recent B<added_on> date in the B<dues> table.

Transactions from the OFX file which contain a ref matching SM\d+ are
checked to see if they have already been imported into the B<transactions>
table, if they have not, and the value matches an existing member id,
it is imported for that member.

=head2 TWEAKS

The fiddle_payment function rejects (returns true) or amends a
transaction row for those instances where we know they are incorrect.

=cut

if(!$ENV{CATALYST_HOME}) {
    die "Please set the CATALYST_HOME environment variable and try again\n";
}

# Read config to get db connection info:
my %config = Config::General->new("$ENV{CATALYST_HOME}/accesssystem_api_local.conf")->getall;
my $schema = AccessSystem::Schema->connect(
    $config{'Model::AccessDB'}{connect_info}{dsn},
    $config{'Model::AccessDB'}{connect_info}{user},
    $config{'Model::AccessDB'}{connect_info}{password},
    );
# Find date of most recently imported payments
my $latest_transaction_rs = $schema->resultset('Transactions')->search(
    {},
    {
        rows => 1,
        order_by => [{ '-desc' => 'added_on'}],
    }
    );

my $latest;
if($latest_transaction_rs->count == 1) {
    # Do at least the last few days, in case we manually added some
    $latest = $latest_transaction_rs->first->added_on->clone()->subtract(days => 2);
} else {
    $latest = DateTime->now->subtract(days => 30);
}

print "Last run was at: $latest\n";
# Find files newer than this date

my @allfiles = glob("$ENV{CATALYST_HOME}/ofx/*.ofx");
foreach my $file (@allfiles) {
    my @stat = stat($file);
    next if $stat[10] <= $latest->epoch;
    import_payments($schema, $file);
}

# Update membership table, based on current validity of members:
$schema->resultset('Person')->update_member_register();

sub fiddle_payment {
    my ($trans) = @_;

    return 1 if $trans->{fitid} eq '+201603140000001';
    return 1 if $trans->{fitid} eq '+201603070000003';

    ## Mr Netting paid to wrong membership ID (twice):
    if($trans->{fitid} eq '+201603080000003') {
        $trans->{name} = 'NETTING S SM0007 BGC';
    } elsif($trans->{fitid} eq '+201603080000002') {
        $trans->{name} = 'NETTING S SM0012 BGC';
    } elsif($trans->{name} =~ /O FUNNELL SM0026 STO/) {
        $trans->{name} = 'O FUNNELL SM0020 STO';
    } elsif($trans->{name} =~ /BRIDGE PS ABC SM0029 FT/) {
        $trans->{name} = 'BRIDGE PS ABC SM0027 FT';
    } elsif($trans->{fitid} eq '+201609150000002') {
        $trans->{name} = "$trans->{name} SM0039";
    } elsif($trans->{fitid} eq '+201705020000006') {
        $trans->{name} = "$trans->{name} SM0068";
    } elsif($trans->{name} =~ /JAMES C SMO122/) {
        $trans->{name} = 'JAMES C SM0122';
    } elsif($trans->{name} =~ /Consulting NT LTD MAKESPACE SM01/) {
        $trans->{name} = 'Consulting NT LTD MAKESPACE SM00129';
    } elsif($trans->{name} =~ / SN0068/) {
        $trans->{name} = 'MR MARK HEWLETT SM0068';
    } elsif($trans->{name} =~ /SWAG /) {
        $trans->{name} = 'FELLOWES DJ SM0136';
    } elsif($trans->{name} =~ /POULIS-JARVI/) {
        $trans->{name} = 'POULIS-JARVI SM0155';
    } elsif($trans->{name} =~ /K WALLBANK/) {
        $trans->{name} = 'K WALLBANK SM00194';
    } elsif($trans->{name} =~ /RENEW SMO188/) {
        $trans->{name} = 'RENEW SM0188';
    } elsif($trans->{name} =~ /MR LAWRENCE A ONSL SM0190/) {
        $trans->{name} = 'MR LAWRENCE A ONSL SM0189';
    } elsif($trans->{name} =~ /MR PETER A COWDY SMO241 STO/) {
	$trans->{name} = 'MR PETER A COWDY SM0241 STO';
    }
    return 0;
}

sub import_payments {
    my ($schema, $filename) = @_;

    # Map to actual members
    # Figure out dates payment is valid for
    # Add to transactions table

    print "import_transaction(sch, $filename)\n";

    # Parse file, find actual payments (SMXXXX)
    my $transactions = OFX::Parse::read_ofx($filename);
    foreach my $trn (@$transactions) {
        next if(fiddle_payment($trn));
        next if($trn->{trnamt} <= 0);
        next if($trn->{name} !~ /SM\s?(\d+)/i);

        # Is it a payment for/by a known member?
        my $id = $1;
        my $member = $schema->resultset('Person')->find({ id => $id+0 });
        if(!$member) {
            warn "SM$id isn't a known membership id ($trn->{name})\n";
            next;
        }

        if(!$member->import_transaction($trn)) {
            warn "Import failed! See above\n";
        }
    }
        
}
