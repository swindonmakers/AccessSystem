package AccessSystem::Schema::Result::Person;

use strict;
use warnings;

use DateTime;
use Template;

use base 'DBIx::Class::Core';

=head1 NAME

AccessSystem::Schema::Result::Person

=head1 DESCRIPTION

Database class representing makerspace members or their children.

=head1 FIELDS

=head2 id

Numeric identifier.

=head2 parent_id

Defaults to NULL, contains the id of the parent row if this is a child.

=head2 name

Full name of the member

=head2 email

Email of the member, NULLs allowed.

=head2 opt_in

Defaults to False. True if the member allows non-makerspace related emails.

=head2 analytics_use

Defaults to False. True if the member allows use of their name/identifying data in GM reports et al.

=head2 dob

Date of birth of the member - compulsory

=head2 address

Free form address field for the member.

=head2 github_user

Nullable. Github username of the member if available.

=head2 google_id

Nullable. Google id/email of the member if available.

=head2 concessionary_rate_override

String describing why the user is eligable for the concessionary rate.

=head2 payment_override

Default NULL. Amount the user is paying monthly, if it is not the default amount.

=head2 member_of_another_hackspace

Defaults to False. True if the member is paying "other hackspace" rate.

=head2 created_date

Date the member was created

=head2 end_date

Nullable. Set if the member has officially left.

=cut

__PACKAGE__->load_components('InflateColumn::DateTime', 'TimeStamp');

__PACKAGE__->table('people');
__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
    },
    parent_id => {
        data_type => 'integer',
        is_nullable => 1,
    },
    name => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 0,
    },
    email => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 1,
    },
    opt_in => {
        data_type => 'boolean',
        default_value => 0,
        is_nullable => 0,
    },
    dob => {
        data_type => 'varchar',
        size => '7',
        is_nullable => 0,
    },
    address => {
        data_type => 'varchar',
        size => 1024,
        is_nullable => 0,
    },
    how_found_us => {
        data_type => 'varchar',
        size => 50,
        is_nullable => 1,
    },
    github_user => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 1,
    },
    telegram_username => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 1,
    },
    telegram_chatid => {
        data_type => 'bigint',
        is_nullable => 1,
    },
    google_id => {
        data_type => 'varchar',
        size => 255,
        is_nullable => 1,
    },
    concessionary_rate_override => {
        data_type => 'varchar',
        size => 255,
        default_value => '',
        is_nullable => 1,
    },
    payment_override => {
        data_type => 'float',
        is_nullable => 1,
    },
    tier_id => {
        data_type => 'integer',
        default_value => 0,
        is_nullable => 0,
    },
    door_colour => {
        data_type => 'varchar',
        size => '20',
        default_value => 'green',
        is_nullable => 0,
        default_if_empty => 1,
    },
    voucher_code => {
        data_type => 'varchar',
        size => 50,
        is_nullable => 1,
    },
    voucher_start => {
        data_type => 'datetime',
        is_nullable => 1,
    },
    created_date => {
        data_type => 'datetime',
        set_on_create => 1,
        is_nullable => 0,
    },
    end_date => {
        data_type => 'datetime',
        is_nullable => 1,
    },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->add_unique_constraint('telegram_id' => ['telegram_chatid']);

__PACKAGE__->inflate_column('dob', {
  inflate => sub {
    my ($raw_value_from_db, $result_object) = @_;
    my $date_str = length($raw_value_from_db) == 7 
        ? $raw_value_from_db . '-28'
        : $raw_value_from_db;
    if(length($date_str) > 7) {
        $date_str = substr($date_str, 0, 10);
    }
    return $result_object->result_source->storage->datetime_parser->parse_date($date_str);
  },
  deflate => sub {
    my ($inflated_value_from_user, $result_object) = @_;
    my $date_str = sprintf("%04d-%02d", $inflated_value_from_user->year,
                           $inflated_value_from_user->month);
  },
});

# __PACKAGE__->add_unique_constraint('email' => ['email']);

__PACKAGE__->has_many('communications', 'AccessSystem::Schema::Result::Communication', 'person_id');
__PACKAGE__->has_many('confirmations', 'AccessSystem::Schema::Result::Confirm', 'person_id');
__PACKAGE__->has_many('payments', 'AccessSystem::Schema::Result::Dues', 'person_id');
__PACKAGE__->has_many('allowed', 'AccessSystem::Schema::Result::Allowed', 'person_id');
__PACKAGE__->has_many('tokens', 'AccessSystem::Schema::Result::AccessToken', 'person_id');
__PACKAGE__->has_many('usage', 'AccessSystem::Schema::Result::UsageLog', 'person_id');
__PACKAGE__->has_many('login_tokens', 'AccessSystem::Schema::Result::PersonLoginTokens', 'person_id');
__PACKAGE__->has_many('children', 'AccessSystem::Schema::Result::Person', 'parent_id');
__PACKAGE__->has_many('transactions', 'AccessSystem::Schema::Result::Transactions', 'person_id');
__PACKAGE__->has_many('vehicles', 'AccessSystem::Schema::Result::Vehicle', 'person_id');
__PACKAGE__->belongs_to('parent', 'AccessSystem::Schema::Result::Person', 'parent_id', { 'join_type' => 'left'} );
__PACKAGE__->belongs_to('tier', 'AccessSystem::Schema::Result::Tier', 'tier_id');

## HFH is a bit of a pita
sub insert {
    my $self = shift;
    foreach my $col ($self->columns) {
        my $info = $self->column_info($col);
        if ($info->{default_if_empty} and not $self->get_column($col)) { 
            # $self->store_column($col => \'DEFAULT') #'
            $self->set_column($col => $info->{default_value});
        }
    }
    return $self->next::method(@_);
}

sub update {
    my $self = shift;
    foreach my $col ($self->columns) {
        my $info = $self->column_info($col);
        if ($info->{default_if_empty} and not $self->get_column($col)) {
            # $self->store_column($col => \'DEFAULT') #'
            $self->set_column($col => $info->{default_value});
        }
    }
    return $self->next::method(@_);
}


sub is_valid {
    my ($self, $date) = @_;
    $date = DateTime->now();

    my $dtf = $self->result_source->schema->storage->datetime_parser;
    my $date_str = $dtf->format_datetime($date);

    my $is_paid;

    if(!$self->parent) {
        $is_paid = $self->payments_rs->search({
            paid_on_date => { '<=' => $date_str },
            expires_on_date => { '>=' => $date_str },
                                          })->count;
    } else {
        return $self->parent->is_valid;
    }

    return $is_paid > 0;
}

sub last_payment {
    my ($self) = @_;

    ## Fail if there are none at all?
    my $last = $self->payments_rs->search(
        {},
        {
            order_by => [{ '-desc' => 'paid_on_date' }],
            rows => 1,
        })->single;

    return $last;
}

sub bank_ref {
    my ($self) = @_;

    return sprintf("SM%04d", $self->id);
}

## basic = 25/mo
## reduced to 5/mo if member is marked as a member of another hack/makerspace
## divide by 2 for concessions (applies also to children!?)
## returns whole pence

sub normal_dues {
    my ($self) = @_;

    return 0 if $self->parent;

    my $dues = $self->tier ? $self->tier->price : 2500;

    if($self->tier && $self->tier->concessions_allowed && $self->concessionary_rate) {
        $dues /= 2;
    }

    # minimum amount! cant be student+member of another, and pay only 2.50!
    if($dues < 500) {
        $dues = 500;
    }

    return $dues;
}

sub dues {
    my ($self) = @_;

    my $dues = $self->normal_dues;

    if($self->payment_override && $self->payment_override > $dues) {
        $dues = $self->payment_override;
    }

    # voucher code gives 20% off first 3 months
    if($self->voucher_code && $self->voucher_start
       && $self->voucher_start->add(months => 3) > DateTime->now()) {
        $dues = $dues * 0.8;
    }

    return $dues;
}

=head2 valid_until

Returns the expiry_date of the most recent payment made by/for this member.

=cut

sub valid_until {
    my ($self) = @_;

    my $dtf = $self->result_source->schema->storage->datetime_parser;
    my $valid_until = $self->payments_rs->search(
        {},
        {
            columns => [ { 'valid_until' => { 'max' => 'expires_on_date' } }],
            group_by => ['person_id'],
        })->first;
    if($valid_until) {
        return $dtf->parse_datetime($valid_until->get_column('valid_until'));
    }

    return undef;
}

=head2 real_expiry

Returns the actual expiry date - the valid_until date minus $OVERLAP days.

=cut

sub real_expiry {
    my ($self, $overlap) = @_;

    my $valid_until = $self->valid_until;
    return if !$valid_until;
    return $valid_until->subtract(days => $overlap);
}

=head2 concessionary_rate

True if either a manual concessionary rate is set, or the member is
older than 65.

=cut

sub concessionary_rate {
    my ($self) = @_;

    if ($self->concessionary_rate_override) {
        return 1;
    }

    return 0 if !$self->dob;

    # FIXME: This is a bit iffy, since it checks your current age, and not the age when the payment was made, or ... something.
    # $age is a DateTime::Duration
    my $age = DateTime->now - $self->dob;

    # It's a nice round number, anyway.
    if ($age->years >= 65) {
        return 1;
    }

    return 0;
}

=head2 usage_by_date

Sort the user's login info by date (newest first).

Used on the profile page.

=cut

sub usage_by_date {
    my ($self) = @_;

    return $self->usage_rs->search({ }, { order_by => { '-desc' => 'accessed_date' } });
}

=head2 payments_by_date

=cut

sub payments_by_date {
    my ($self) = @_;

    return $self->payments_rs->search({ }, { order_by => {'-desc' => 'expires_on_date' } } );
}

=head2 transactions_by_date

=cut

sub transactions_by_date {
    my ($self) = @_;

    return $self->transactions_rs->search({ }, { order_by => {'-desc' => 'added_on' } } );
}

=head2 import_transaction

Check if a new transaction containing this person's ID as a ref (SMXXid)
is a valid transaction for this person, if so, add it. Returns undef if
the add failed.

Transaction consists of: dtposted => DateTime of the transaction, trnamt => $value_in_GBP, name => $ref_on_payment

=cut

sub import_transaction {
    my ($self, $transaction) = @_;
    my $schema = $self->result_source->schema;

    # Have we imported this already?
    my $dt_parser = $schema->storage->datetime_parser;
    warn "$transaction->{dtposted}\n";
    my $trans_search = $self->search_related('transactions')->search(
        { added_on => $dt_parser->format_datetime($transaction->{dtposted}),
        amount_p => $transaction->{trnamt} * 100 });
    if($trans_search->count) {
        warn "Already imported transaction $transaction->{name} $transaction->{dtposted}\n";
        return 1;
    }

    warn "About to create transaction for ", $self->name, "\n";
    $self->create_related('transactions',
                          {
                              added_on => $transaction->{dtposted},
                              reason   => "Imported from OFX/Barclays on " . DateTime->now->iso8601(),
                              amount_p => $transaction->{trnamt} * 100,
                          });
    return 1;
}

=head2 create_payment

Check if we are nearing the end of this member's paid membership,
return true if not.

Check if this member has enough in their balance (transactions) to pay
for another month, if so, create a payment row. Return undef if we
can't find one.

If the balance is >= 12*$monthly*0.1, then make a year payment.

=cut

sub create_payment {
    my ($self, $OVERLAP_DAYS) = @_;
    my $schema = $self->result_source->schema;

    ## minor(?) side effects:

    # if no valid date (havent paid yet), and created date longer than
    # a week? ago, then email member to see why they havent yet

    # if no valid date yet, but we now make a payment (first ever),
    # email member to notify them

    my $valid_date = $self->valid_until;
    if($valid_date && $valid_date->clone->subtract(days => $OVERLAP_DAYS) > DateTime->now) {
        warn "Member " . $self->bank_ref . " not about to expire.\n";
        return 1;
    }

    my $now = DateTime->now;
    # Figure out what sort of payment this is, if valid_until is
    # empty, then its a first payment or renewal payment - use the
    # payment date.
    # Else use the valid_until date, unless member had already expired!

    # Check for first payment / renewed payment, queue up email:
    if(!$valid_date) {
        # first payment ever
        # this is the start of their voucher
        if($self->voucher_code) {
            $self->update({ voucher_start => DateTime->now()});
        }
    }
    # work this out after voucher setting cos it changes the dues
    if($self->balance_p < $self->dues) {
        warn "Member " . $self->bank_ref . " balance not enough for another month.\n";
        # Remind when actually expired, 5 days into the overlap
        if($valid_date &&
           $valid_date->clone()->subtract(days => 5) < $now
            && $valid_date >= $now->clone()->subtract(months => 1)) {
            # has (or is about to) expire
            # this will only send once!
            my $last = $self->last_payment;
            my $expiry = $self->real_expiry($OVERLAP_DAYS);
            my $paid_date = sprintf("%s, %d %s %d",
                                    $last->paid_on_date->day_abbr,
                                    $last->paid_on_date->day,
                                    $last->paid_on_date->month_name,
                                    $last->paid_on_date->year);
            my $expires_date = sprintf("%s, %d %s %d",
                                       $expiry->day_abbr,
                                       $expiry->day,
                                       $expiry->month_name,
                                       $expiry->year);
            # create new reminder email (only if previously cancelled
            # by new payment)
            $self->create_communication(
                'Swindon Makerspace membership check',
                'reminder_email',
                { paid_date => $paid_date, expires_date => $expires_date },
                );
        }
        return;
    }
    if (!$valid_date) {
        $self->create_communication('Your Swindon Makerspace membership has started', 'first_payment');
    }

    if($valid_date && $valid_date < $now) {
        # renewed payments
        $self->create_communication('Your Swindon Makerspace membership has restarted', 'rejoin_payment');
        # rejoined, so remove any "reminder" email, so that if they
        # subsequently stop paying again, they get a new reminder (!)
        my $r_email = $self->communications_rs->find({type => 'reminder_email'});
        $r_email->delete if $r_email;
    }
    # Only add $OVERLAP  extra days if a first or renewal payment - these
    # ensure member remains valid if standing order is not an
    # exact month due to weekends and bank holidays
    my %extra_days = ();
    if(!$valid_date || $valid_date < $now ) {
        $valid_date = $now;
        %extra_days = ( days => $OVERLAP_DAYS );
    }

    my $payment_size = $self->dues;
    $self->update_door_access();
    my $expires_on = $valid_date->clone->add(months => 1, %extra_days);
    if($self->balance_p >= $self->dues * 12 * 0.9) {
        # Special case, they paid for a year in advance (we assume!)
        $expires_on = $valid_date->clone->add(years => 1, %extra_days);
        $payment_size = $self->dues * 12 * 0.9;
    }

    die "Expires date is before now!? (for " .  $self->bank_ref if $expires_on < $now;
    warn "About to create add payment on: $now for " . $self->bank_ref, ", expiring: $expires_on.\n";
    $schema->txn_do( sub {
        $self->create_related('transactions', {
            added_on => $now,
            reason => "Membership payment for " . $now->month_name . " " . $now->year,
            amount_p => -1*$payment_size,
        });
        $self->create_related('payments', {
            paid_on_date => $now,
            expires_on_date => $expires_on,
            amount_p => $payment_size,
        });
    });
    return 1;
}

=head2 balance_p

Total of all member's transactions, in pence.

=cut

sub balance_p {
    my ($self) = @_;

    return $self->transactions_rs->get_column('amount_p')->sum() || 0;
}

=head2 add_debit

Add debit transaction with checks

=cut

sub add_debit {
    my ($self, $amount, $reason) = @_;

    if(length($reason) > 255) {
        $reason = substr($reason, 0, 255);
    }
    if($amount =~/\D/) {
        return (0, 'Amount must be a positive integer of pence');
    } elsif($self->balance_p + 400 < $amount) {
        return (0, 'Not enough money for that transaction');
    } else {
        my $tr = $self->create_related('transactions', {
            reason   => $reason,
            amount_p => -1*$amount,
        });

        return (1, 'Success', $self->balance_p);
    }
}

sub recent_transactions {
    my ($self, $count) = @_;
    $count ||= 10;

    return $self->transactions_rs->search(
        {},
        {
            rows => $count,
            order_by => [{ -desc => 'added_on' }],
        }
        );
                                          
}

sub create_all_induction_email {
    my ($self, $base_url, $force) = @_;

    my @links = ();
    my $allowed_rs = $self->allowed->search_rs({
        pending_acceptance => "true",
    });

    my $h_and_s = 0;
    while(my $allowed = $allowed_rs->next) {
        my $token = Data::GUID->new->as_string();
        my $confirm = $self->confirmations->create({
            token => $token,
            storage => {
                tool_id => $allowed->tool_id,
                person_id => $allowed->person_id,
            },
        });
        my $url = $base_url . 'confirm_induction?token=' . $token;
        
        push @links, { link => $url, tool => $allowed->tool->name, lone_worker_allowed => $allowed->tool->lone_working_allowed };
        $h_and_s = 1 if $allowed->tool->name =~ /^Health and/;
    }

    if(!@links) {
        # None found to send, exit:
        return;
    }
    my $comm = $self->create_communication(
        'Swindon Makerspace Induction(s)',
        'inducted_on_all',
        {
            links => \@links,
            h_and_s => $h_and_s,
        },
        $force
    );

    return $comm;
}

sub create_induction_email {
    my ($self, $allowed, $base_url) = @_;

    my $token = Data::GUID->new->as_string();
    my $confirm = $self->confirmations->create({
        token => $token,
        storage => {
            tool_id => $allowed->tool_id,
            person_id => $allowed->person_id,
        },
    });

    my $url = $base_url . 'confirm_induction?token=' . $token;
    my $t_name = $allowed->tool->name;
    $t_name =~ s/\W/_/g;
    $t_name = lc($t_name);
    my $comm = $self->create_communication(
        'Swindon Makerspace Induction Confirmation',
        'inducted_on|' . $t_name,
        {
            tool_name => $allowed->tool->name,
            link => $url,
            lone_working_allowed => ($allowed->tool->lone_working_allowed ? 1 : 0)
        },
    );

    return ($comm, $confirm);
}

sub create_communication {
    my ($self, $subject, $type, $tt_vars, $force) = @_;
    $force ||= 0;
    $type =~ s/\.tt$//;

    my $check_exists = $self->communications_rs->search_rs({
        type => $type,
    });
    if($check_exists->count == 1) {
        if(!$force) {
            return $check_exists->first;
        }
        $check_exists->delete;
    }

    # templates in $ENV{CATALYST_HOME}/root/src/emails/<type>/<type>.txt / .html
    if (!$ENV{CATALYST_HOME}) {
        die "CATALYST_HOME env var does not exist!";
    }
    my $tt_path_base = "$ENV{CATALYST_HOME}/root/src/emails";

    my $comm_hash = {
        created_on => undef,
        type => $type,
        status => 'unsent',
        subject => $subject,
    };


    $tt_vars->{member} = $self;

    my $tt = Template->new(
        INCLUDE_PATH => $tt_path_base,
        STRICT => 1
        );
    if (!$tt) {
        print STDERR "tt error: $Template::ERRROR";
        return undef;
    }


    my $tt_type_no_pipe = $type;
    $tt_type_no_pipe =~ s/\|.*//;
    my $tt_type_defang = $type;
    $tt_type_defang =~ s/\W/_/g;

    my $tt_type;
    my $any_parts;
    # Look for eg: inducted_on_health_and_safety_policy then inducted_on
    foreach $tt_type ($tt_type_defang, $tt_type_no_pipe) {
        next if($comm_hash->{plain_text});
        if (-e "${tt_path_base}/$tt_type/$tt_type.txt") {
            my $raw = "";
            my $process = $tt->process("$tt_type/$tt_type.txt", {member => $self, %$tt_vars}, \$raw);
            if (!$process) {
                print STDERR $tt->error;
                return undef;
            }
            $comm_hash->{plain_text} = $raw;
            $any_parts++;
        }
        next if($comm_hash->{html});
        if (-e "${tt_path_base}/$tt_type/$tt_type.html") {
            # print STDERR "Found ${tt_path_base}/$type/$type.html\n";
            my $raw = "";
            my $process = $tt->process("$tt_type/$tt_type.html", {member => $self, %$tt_vars}, \$raw);
            if (!$process) {
                print STDERR $tt->error;
                return undef;
            }
            # print STDERR "Raw: $raw\n";
            $comm_hash->{html} = $raw;
            $any_parts++;
        }
    }

    if (!$any_parts) {
        print STDERR "When sending communication type $type, neither ${tt_path_base}/$tt_type/$tt_type.txt nor ${tt_path_base}/$tt_type/$tt_type.html exist";
        return undef;
    }

    return $self->communications_rs->create($comm_hash);
}


sub door_colour_to_code {
    my ($self) = @_;

    if ($self->tier && $self->tier->name eq 'Sponsor') {
        my %codes = (
            white    => 0x00,
            green    => 0x01,
            purple   => 0x02,
            blue     => 0x03,
            pink     => 0x04,
            orange   => 0x05,
            rainbow  => 0x11,
            rainbow2 => 0x12,
            );   
        return $codes{$self->door_colour};
    }
    return undef;
}

sub update_door_access {
    my ($self) = @_;

    # This entry should exist, but covid policy may have removed it..
    my $door = $self->result_source->schema->the_door();
    my $door_allowed = $self->allowed->find_or_create({ tool_id => $door->id });
    $door_allowed->update({ pending_acceptance => 'false', accepted_on => DateTime->now()});
}

1;
