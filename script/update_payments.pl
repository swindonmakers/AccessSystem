#!/usr/bin/perl

# use local::lib '/usr/src/perl/libs/accesssystem/perl5';
use Config::General;
use DateTime;

use lib "$ENV{CATALYST_HOME}/lib";
use AccessSystem::Schema;
use OFX::Parse;

if(!$ENV{CATALYST_HOME}) {
    die "Please set the CATALYST_HOME environment variable and try again\n";
}

# Read config to get db connection info:
my %config = Config::General->new("$ENV{CATALYST_HOME}/accesssystem.conf")->getall;
my $schema = AccessSystem::Schema->connect(
    $config{Model::AccessDB}{connect_info}{dsn},
    $config{Model::AccessDB}{connect_info}{user},
    $config{Model::AccessDB}{connect_info}{password},
    );
# Find date of most recently imported payments
my $latest_payment_rs = $schema->resultset('Dues')->search(
    {},
    {
        rows => 1,
	order_by => [{ '-desc' => 'added_on'}],
    }
    );

my $latest;
if($latest_payment_rs->count == 1) {
    $latest = $latest_payment_rs->first->added_on;
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
        return 1;
    }
    return 0;
}

sub import_payments {
    my ($schema, $filename) = @_;

    print "import_payments(sch, $filename)\n";

    # Parse file, find actual payments (SMXXXX)
    my $transactions = OFX::Parse::read_ofx($filename);
    foreach my $trn (@$transactions) {
        next if(fiddle_payment($trn));
        next if($trn->{trnamt} <= 0);
        next if($trn->{name} !~ /SM(\d+)/);

        # Is it a payment for/by a known member?
        my $id = $1;
        my $member = $schema->resultset('Person')->find({ id => $id+0 });
        if(!$member) {
            warn "SM$id isn't a known membership id\n";
            next;
        }

        # Have we imported this already?
        my $dt_parser = $schema->storage->datetime_parser;
        warn "$trn->{dtposted}\n";
        my $pay_search = $member->search_related('payments')->search(
            { paid_on_date => $dt_parser->format_datetime($trn->{dtposted}) });
        if($pay_search->count) {
            warn "Already imported payment for $trn->{name}\n";
            next;
        }

        # Calculate expiration date for this payment
        my $expires_on;
        if($trn->{trnamt} * 100 == $member->dues) {
            $expires_on = $trn->{dtposted}->clone->add(months => 1);
        } elsif($trn->{trnamt} * 100 == ($member->dues * 12 - ( $member->dues * 12 * 0.1 ))
                || $trn->{trnamt} * 100 == $member->dues * 12) {
            $expires_on = $trn->{dtposted}->clone->add(years => 1);
        } elsif($trn->{trnamt} * 100 % $member->dues == 0) {
            my $months = $trn->{trnamt} * 100 / $member->dues;
            $expires_on = $trn->{dtposted}->clone->add(months => $months);
        } else {
            warn "Can't work out how many months to pay for SM$id, with $trn->{trnamt}\n";
            next;
        }
        ## Add leeway for next standing order slot being on a sunday or bank holiday:
        $expires_on->add(days => 3);
        warn "About to create add payment on: $trn->{dtposted} for " . $member->name, "\n";
        $member->create_related('payments',
                                {
                                    paid_on_date => $trn->{dtposted},
                                    expires_on_date => $expires_on,
                                    amount_p => $trn->{trnamt} * 100,
                                });
    }
    
    # Map to actual members
    # Figure out dates payment is valid for
    # Add to dues table
}
