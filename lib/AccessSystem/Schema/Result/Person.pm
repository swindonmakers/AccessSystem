package AccessSystem::Schema::Result::Person;

use strict;
use warnings;

use DateTime;

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
    github_user => {
        data_type => 'varchar',
        size => 255,
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
    member_of_other_hackspace => {
        data_type => 'boolean',
        default_value => 0,
        is_nullable => 0,
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
__PACKAGE__->has_many('payments', 'AccessSystem::Schema::Result::Dues', 'person_id');
__PACKAGE__->has_many('allowed', 'AccessSystem::Schema::Result::Allowed', 'person_id');
__PACKAGE__->has_many('tokens', 'AccessSystem::Schema::Result::AccessToken', 'person_id');
__PACKAGE__->has_many('usage', 'AccessSystem::Schema::Result::UsageLog', 'person_id');
__PACKAGE__->has_many('login_tokens', 'AccessSystem::Schema::Result::PersonLoginTokens', 'person_id');
__PACKAGE__->has_many('children', 'AccessSystem::Schema::Result::Person', 'parent_id');
__PACKAGE__->has_many('transactions', 'AccessSystem::Schema::Result::Transactions', 'person_id');
__PACKAGE__->belongs_to('parent', 'AccessSystem::Schema::Result::Person', 'parent_id', { 'join_type' => 'left'} );

# FIXME: Magic number 
sub is_valid {
    my ($self, $date) = @_;
#    my $overlap_days = 14;
    #   $date ||= DateTime->today()->add(days => $overlap_days);
    $date = DateTime->today();

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
## add 5 for each child beyond first one
## divide by 2 for concessions (applies also to children!?)
## returns whole pence

sub normal_dues {
    my ($self) = @_;

    return 0 if $self->parent;

    my $dues = 2500;
    if($self->member_of_other_hackspace) {
        $dues = 500;
    }

    # Children's data no longer collected (or paid for)
    # if($self->children_rs->search({ end_date => { '!=' => undef } })->count > 1) {
    #     $dues += 500 * ($self->children_rs->count-1);
    # }

    if($self->concessionary_rate) {
        $dues /= 2;
    }

    ## Men's shed special:
    if($self->concessionary_rate_override &&
       $self->concessionary_rate_override eq 'mensshed') {
        $dues = 1000;
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

    # Children don't actually pay dues, they increase the dues of
    # their parents.  Because of that, and because we are nice like
    # that, we give anybody who has at least one concessionary child a
    # concession, which lowers their rate, including what they pay for that child (if anything).
#    if($self->children_rs->search({
#                                   end_date => { '!=' => undef },
#                                   concessionary_rate_override => { '!=' => undef },
    #                                  })->count) {
    my $children = $self->children_rs;
    while (my $child = $children->next) {
        if ($child->concessionary_rate) {
            print STDERR "concession child\n";
            return 1;
        }
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
        { added_on => $dt_parser->format_datetime($transaction->{dtposted}) });
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

    if($self->balance_p < $self->dues) {
        warn "Member " . $self->bank_ref . " balance not enough for another month.\n";
        return;
    }

    my $now = DateTime->now;
    # Figure out what sort of payment this is, if valid_until is
    # empty, then its a first payment or renewal payment - use the
    # payment date.
    # Else use the valid_until date, unless member had already expired!

    # Check for first payment / renewed payment, queue up email:
    if(!$valid_date) {
        # first payment ever
        $self->create_communication('new_payment.tt');
    }
    if($valid_date && $valid_date < $now) {
        # renewed payments
        $self->create_communication('renewed_payment.tt');
    }
    # Only add $OVERLAP  extra days if a first or renewal payment - these
    # ensure member remains valid if standing order is not an
    # exact month due to weekends and bank holidays
    my %extra_days = ();
    if(!$valid_date || $valid_date < $now ) {
        $valid_date = $now;
        %extra_days = ( days => $OVERLAP_DAYS );
    }

    # # Calculate expiration date for this payment (10% off if year at once)
    # my $expires_on;
    # if($transaction->{trnamt} * 100 == $self->dues) {
    #     $expires_on = $valid_until->clone->add(months => 1, %extra_days);
    # } elsif($transaction->{trnamt} * 100 == ($self->dues * 12 - ( $self->dues * 12 * 0.1 ))
    #         || $transaction->{trnamt} * 100 == $self->dues * 12) {
    #     $expires_on = $valid_until->clone->add(years => 1, %extra_days);
    # } elsif($transaction->{trnamt} * 100 % $self->dues == 0) {
    #     my $months = $transaction->{trnamt} * 100 / $self->dues;
    #     $expires_on = $valid_until->clone->add(months => $months, %extra_days);
    # } else {
    #     warn "Can't work out how many months to pay for " . $self->name ." with $transaction->{trnamt}\n";
    #     return;
    # }

    my $expires_on = $valid_date->clone->add(months => 1, %extra_days);

    die "Expires date is before now!? (for " .  $self->bank_ref if $expires_on < $now;
    warn "About to create add payment on: $now for " . $self->bank_ref, ", expiring: $expires_on.\n";
    $schema->txn_do( sub {
        $self->create_related('transactions', {
            added_on => $now,
            reason => "Membership payment for " . $now->month_name . " " . $now->year,
            amount_p => -1*$self->dues,
        });
        $self->create_related('payments', {
            paid_on_date => $now,
            expires_on_date => $expires_on,
            amount_p => $self->dues,
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
    } elsif($self->balance_p < $amount) {
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

sub create_communication {
    my ($self, $template) = @_;

    ## Eventtually! this should store the template name in the comms
    ## table, and the comms sending part should construct the text?!

    my ($type) = $template =~ /^(\w+)/; # template with no .tt
    if($type eq 'new_payment') {
        $self->communications_rs->create({
            sent_on => undef,
            type => $type,
            status => 'unsent',
            content => "
Dear " . $self->name . ",

Your initial payment has been received by the Swindon Makerspace, your
membership is now activated. You can now access the Makerspace.

If you do not yet have a door token, visit the Makerspace on a
Wednesday evening and ask to be assigned one. To organise a different
date email us at info\@swindon-makerspace.org or (better) join our
group Telegram chat: https://t.me/joinchat/A5Xbrj7rku0D-F3p8wAgtQ .

Don't forget that you'll need inductions before you use some of the machines.

Regards,

Swindon Makerspace
"
                                         });
    }
}

1;
