#!/usr/bin/perl
use warnings;
use strict;

use strict;
use warnings;

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
        order_by => [{ '-desc' => 'posted_on'}],
    }
    );

my $latest;
if($latest_transaction_rs->count == 1) {
    # Do at least the last few days, in case we manually added some
    $latest = $latest_transaction_rs->first->posted_on->clone()->subtract(days => 2);
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

    ## Mr Netting paid to wrong membership ID (twice):
    if($trans->{name} =~ /K WALLBANK/) {
        $trans->{name} = 'K WALLBANK SM00194';
    } elsif($trans->{name} =~ /J SCOTT STO/) {
        $trans->{name} = 'J SCOTT SM0303 STO';
    } elsif($trans->{name} =~ /Henry Russell/) {
        $trans->{name} = 'Henry Russell SM0374';
    } elsif($trans->{name} =~ /CROSSKEY CG I/) {
        $trans->{name} = 'CROSSKEY CG SM0375';
    } elsif($trans->{name} =~ /DJORN\s+FEVRIER/) {
        $trans->{name} = 'JORN FEVRIER SM0301';
    } elsif($trans->{name} =~ /C Hinton BGC/) {
        $trans->{name} = 'C Hinton BGC SM0416';
    }
    $trans->{name} =~ s/sm/SM/ig;
    $trans->{name} =~ s/SN/ SM/gi;
    $trans->{name} =~ s/SMs+(\d+)/SM$1/gi;
    $trans->{name} =~ s/SMo+/SM0/gi;

    print STDERR "Name now: " . $trans->{name} . "\n";
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
        fiddle_payment($trn);
        categorize($trn);
        # next if(fiddle_payment($trn));
        my $dt_parser = $schema->storage->datetime_parser;
        my $posted = $dt_parser->format_datetime($trn->{dtposted});
        my $db_transaction = $schema->resultset('Transactions')->find_or_create(
            {
                fitid => $trn->{fitid},
                posted_on => $posted,
                name => $trn->{name},
                amount_p => $trn->{trnamt} * 100,
                type => $trn->{trntype},
                category => $trn->{category}
            }, { key => 'trn'});

        next if($trn->{trnamt} <= 0);
        next if($trn->{name} !~ /SM\s?(\d+)/i);

        # Is it a payment for/by a known member?
        my $id = $1;
        my $member = $schema->resultset('Person')->find({ id => $id+0 });
        if(!$member) {
            warn "SM$id isn't a known membership id ($trn->{name})\n";
            next;
        }

        # Importing so therefore this is a member payment:
        $trn->{category} = 'Member Payment';
        if(!$member->import_transaction($trn, $db_transaction)) {
            warn "Import failed! See above\n";
        }
    }        
}

sub categorize {
    my ($tx) = @_;

    if ($tx->{name} =~ s/ STO//) {
        $tx->{trntype} = "standing order";
    } elsif ($tx->{name} =~ s/ DDR//) {
        $tx->{trntype} = "direct debit request";
    } elsif ($tx->{name} =~ s/ CLP//) {
        $tx->{trntype} = "contactless";
    }

    if ($tx->{trntype} eq 'directdep' and $tx->{name} =~ m/^SumUp Payments Acc/) {
        $tx->{category} = 'Sumup Payment';
    # } elsif ($tx->{name} =~ m/sm[O\d]+/i) {
    #     $tx->{category} = 'Member Payment';
    #     $tx->{name} = 'REDACTED';
    } elsif ($tx->{name} =~ m/^CLIENTS DEPOSIT SwindonLottery/) {
        $tx->{category} = 'Swindon Lottery';
    } elsif ($tx->{name} =~ m/^INFORMATION COMMIS/) {
        $tx->{category} = 'ICO';
    } elsif ($tx->{name} =~ m/^BIZSPACE LIMITED SWIND010/) {
        $tx->{category} = 'Rent + Electricity';
    } elsif ($tx->{name} =~ m/^H3G /) {
        $tx->{category} = 'Broadband';
    } elsif ($tx->{name} =~ m/ BOOKER /) {
        # Snacks & Drinks & Consumables (bin bags, blue roll etc)
        $tx->{category} = 'Supplies';
    } elsif ($tx->{name} =~ m/^ICELAND /) {
        # Snacks & Drinks (cans)
        $tx->{category} = 'Suuplies';
    } elsif ($tx->{name} =~ m/^pledge /i) {
        $tx->{category} = 'Donation (Pledges)';
    } elsif ($tx->{trnamt} > 0 && $tx->{name} =~ m/^POST OFFICE RAMLEAZE DRIVE /) {
        $tx->{category} = 'Cash paid in';
    }

    # INFORMATION COMMIS ZB167275 DDR, -47 GBP, ICO data controller payment.

    $tx->{category} //= 'unknown';

}
