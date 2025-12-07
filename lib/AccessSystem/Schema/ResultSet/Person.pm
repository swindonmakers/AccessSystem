package AccessSystem::Schema::ResultSet::Person;

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use Feature::Compat::Try;
use DateTime;
use SQL::Abstract;
use Date::Holidays::GB::EAW qw/is_holiday/;
#use SQL::Abstract::Plugin::ExtraClauses;
use base 'DBIx::Class::ResultSet';

=head1 NAME

AccessSystem::Schema::ResultSet::Person

=head1 DESCRIPTION

Methods to filter a subset of people out of all the registered ones.

=head1 METHODS

=head2 find_person

Attempt to lookup a person by name, a shortened version of the name
can be providied, if a single matching person exists, we return the
Person row object. If we can't find a single match, we return a
resultset representing the filtered people.

Returns an array: ($person | undef, $people | undef)

=cut

sub find_person {
    my ($self, $input, $args) = @_;

    $input =~ s/^\s+//;
    $input =~ s/\s+$//;
    my $person;
    my $person_rs = $self->search_rs({ 'me.name' => $input }, $args);
    if ($person_rs->count == 1) {
        return $person_rs->first;
    }

    my $people;
    try {
        # Pg syntax, but not other databases, sigh
        my $pgpeople = $self->search_rs({ 'me.name' => { '-ilike' => "%$input%" }}, $args);
        if ($pgpeople->count == 1) {
            $person = $pgpeople->first;
            return ($person, undef);
        }
        return (undef, $pgpeople) if $pgpeople && $pgpeople->count > 0;        
    } catch ($err) {
        print "This is not Pg: $err\n";
    }

    $people = $self->search_rs({ 'me.name' => { '-like' => "$input%" }}, $args);
    if ($people->count == 1) {
        $person = $people->first;
    }
    return ($person, undef) if $person;
    
    warn "Add more people-finding magic here: $input failed\n";
    return (undef, $people);
}

=head2 allowed_to_thing

Check if a person (represented by one of their rfid token ids), is
allowed to use/interact with a tool (represented by the tools guid
id). If they are allowed, returns the Person row object, if not
returns an error message, and a colour code representing the error.

Returns a hashref:

    { person => $person }

or

    { error => 'Membership expired/unpaid', colour => 0x22 }

=cut

sub allowed_to_thing {
    my ($self, $token, $thing_guid) = @_;

    my $person_rs = $self->search(
        {
            'allowed.tool_id' => $thing_guid,
            'tokens.id' => $token,
        }, {
           prefetch => ['allowed' ],
           join => ['allowed', 'tokens'],
        });

    if( $person_rs->count > 1) {
        return {
            error => 'Token reused on accounts. Talk to a director',
            colour => 0x25,
        };
    }
    my $person = $person_rs->first;
    # print STDERR "Accept: ", $person->allowed->first->pending_acceptance, "\n";
    if($person && !$person->allowed->first->pending_acceptance) {
        if($person->is_valid) {
            ## time restrictions for weekenders
            my $person = $person_rs->first;
            if ($person->tier->restrictions->{'times'}) {
                my $now = DateTime->now(time_zone => 'Europe/London');
                my $r_allow = 0;
                foreach my $time (@{ $person->tier->restrictions->{'times'} }) {
                    # 'from' => '6:00:00', 'to' => '7:23:59'
                    my ($f_dow, $f_hour, $f_minute) = split(':', $time->{from});
                    my ($t_dow, $t_hour, $t_minute) = split(':', $time->{to});
                    if ($now->day_of_week >= $f_dow && $now->day_of_week <= $t_dow
                        && $now->hour >= $f_hour && $now->hour <= $t_hour
                        && $now->minute >= $f_minute && $now->minute <= $t_minute
                       ) {
                        $r_allow = 1;
                    }
                }
                # All restrictions lifted on bank hols
                if (!$r_allow) {
                    if (is_holiday(year => $now->year, month => $now->month, day => $now->day)) {
                        $r_allow = 1;
                    }
                }
                if (!$r_allow) {
                    return {
                        error => 'No access for Weekend Member',
                        colour => 0x21,
                    };
                }
            }

            # Check required dep tools:
            my $deps_ok = 1;
            foreach my $dep ( $person->allowed->first->tool->required_dependencies_rs->all ) {
                my $check = $self->allowed_to_thing($token, $dep->required_id);
                if($check->{error}) {
                    $deps_ok = 0;
                    return {
                        error => $check->{error},
                        colour => 0x24,
                       };
                }
            }
            if($deps_ok) {
                # Jan 2025 - new membrership fees - email if underpaying
                my $beep = 0;
                if ($person->send_membership_fee_warning()) {
                    $beep = 1;
                }
                return {
                    person  => $person,
                    beep    => $beep,
                    message => 'Fees have changed. Check email.',
                    thing   => $person->allowed->first->tool,
                };
            }
        } else {
            if ($person->is_donor) {
                # Fetch stored old-tier info
                # force send ?
                $person->create_communication('Makerspace upgrade Donor Tier to Membership', 'donation_access_denied', {}, 1);
                return {
                    person => $person,
                    error => "No access for donors",
                    colour => 0x22,
                };
            }
            return {
                error => "Membership expired/unpaid",
                colour => 0x22,
            };
        }
        # no Person or not accepted
    } elsif($person && $person->allowed->first->pending_acceptance eq 'true') {
        return {
            error => 'Induction not confirmed/Pay up please',
            colour => 0x24,
        };
        # no person, look up token instead
    } else {
        my $has_token = $self->search(
            {
                'tokens.id' => $token,
            }, {
                'join' => 'tokens',
            });
        if(!$has_token->count) {
            return {
                error => "RFID tag ($token) not recognised",
                colour => 0x20,
            };
        } else {
            $person = $has_token->first;
        }
    }

    my $thing_rs = $self->result_source->schema->resultset('Tool')->search(
        {
            'id' => $thing_guid,
        });
    if(!$thing_rs->count) {
        return {
            person => $person,
            error => "Tool ($thing_guid) not recognised",
        }
    } else {
        return {
            error => sprintf("%s not accepted. See email", $thing_rs->first->name),
            person => $person,
            thing => $thing_rs->first,
            colour => 0x24,
        };
    }

    return { error => 'I have no idea what happened there, but that did\'t work', colour => 0x23 };

}

=head2 update_member_register

=cut

sub update_member_register {
    my ($self) = @_;

    my $register = $self->result_source->schema->resultset('MemberRegister');
    while (my $member = $self->next) {
        # Skip if never were valid (havent paid)
        next if !$member->is_valid && !$member->valid_until;
        # No children
        next if $member->parent_id;

        # Existing register for this person, most recent one:
        # If their name has changed, we'll get new entries (tough?)
        my $recent_reg = $register->search(
            {
                name => $member->name
            },
            {
                group_by => ['me.name'],
                columns => ['me.name',{ started_date => { max => 'me.started_date' } }],
                rows => 1,
            },
        );
        my $recent;
        if(!$recent_reg->count) {
            $recent = $register->new_entry_including_dues($member);
        } else {
            $recent = $register->find({ name => $recent_reg->first->name,
                                        started_date => $recent_reg->first->started_date->ymd
                                      });
        }
        # At this point:
        # a) we just created a bunch of rows from an older user that wasnt in the register
        # b) we created one row in register for user thats new
        # c) $recent contains most recent row for user that was previously entered in register
        # d) $recent might be a row with an ended_date, and we may be looking at
        # a user with resumed payments.
        # create another row, if the most recent we found already ended
        # .. and the member is valid?
        if($member->is_valid) {
            if($recent->ended_date) {
                # No entry for this user yet, start one:
                $recent = $register->create({
                    name => $member->name,
                    address => $member->address,
                    started_date => $member->last_payment->paid_on_date->ymd,
                    updated_date => DateTime->now(),
                    updated_reason => 'Resumed membership',
                });
            }
        } elsif(!$recent->ended_date) {
            # the most recent membership hadnt ended, but now we discover that
            # it has, so we close it:
            if ($member->valid_until < $recent->started_date) {
                # This happens when we have 2 ids with duplicate names..
                # try to close the new one with the old one's details !
                warn "Register Update: Duplicate? member " . $member->name . " ended before they started!?\n Valid: " . $member->valid_until->ymd . " Started: " . $recent->started_date->ymd . "\n";
                next;
            }

            $recent->update({
                ended_date => $member->valid_until->ymd,
                updated_date => DateTime->now,
                updated_reason => 'Membership ended',
            });
        } else {
            # Not valid, previously ended - all done
        }
    }
}

sub get_person_from_hash {
    my ($self, $hash) = @_;

    my $ymd = DateTime->now()->ymd();
    foreach my $person ($self->all) {
        print STDERR "Person: ", $person->id, "\n";
        foreach my $token ($person->login_tokens) {
#            print STDERR "Token: ", $token->login_token, "\n";
            print STDERR "Checking: $ymd$token $hash:". md5_hex($ymd . $token->login_token), "\n";
            if(md5_hex($ymd . $token->login_token) eq $hash) {
                return $person;
            }
        }
    }
    return 0;
}

=head2 membership_stats

=cut

# Example response for /memberstats that now includes weekend

# Current Total Members: X
# 24/7 members: X full, X concession
#     Wknd members: X full, X concession
#     Sponsor members: X full, X concession
#   Otherspace: X
#   Child: X (should we list this?)
# Left this month: X (dont break this down as feels like overkill)
#     things in brackets are comments, obviously :)
    
## TODO: Update for new tiers
sub membership_stats {
    my ($self) = @_;

    my %data = ();
    my $income;
    my $now = DateTime->now()->subtract(days => 1);
    my $four_weeks = $now->clone->subtract('days' => 27);

    my $dtf = $self->result_source->schema->storage->datetime_parser;


    while (my $member = $self->next() ) {
        my @flags = ();
        push @flags, 'valid_members' if $member->is_valid;
        push @flags, 'child' if $member->parent;

        if(!$member->parent) {
            push @flags, 'concession' if $member->concessionary_rate;
            push @flags, $member->tier->name;

            push @flags, 'full' if ! $member->concessionary_rate;
#            push @flags, 'full' if $member->tier->name ne 'MemberOfOtherHackspace' && ! $member->concessionary_rate;

            push @flags, 'ex_members' if $member->end_date && !$member->is_valid;
            push @flags, 'overdue_members' if !$member->end_date && !$member->is_valid;

            push @flags, 'adult';
            push @flags, 'count';
        }
        my $v_until = $member->valid_until;
        push @flags, 'recent_expired' if !$member->end_date && $v_until && $v_until < $now && $v_until >= $four_weeks;

        $income += $member->dues if $member->is_valid;

        for my $f (@flags) {
            if($f eq 'recent_expired') {
                my %cols = $member->get_columns;
                push @{ $data{$f}{people} }, { %cols{qw/id parent_id name created_date end_date/}, concessionary_rate => $member->concessionary_rate, valid_until => $v_until->ymd, tier => $member->tier->name };
            }
            for my $g (@flags) {
                for my $h (@flags) {
                    $data{$f}{$g}{$h}++;
                }
            }
        }
    }

    $data{income} = $income;

    # email/telegram text:
    my $msg_text = "
Current Total Members: " . ($data{valid_members}{count}{count} || 0) . "\n";
    foreach my $tier ($self->result_source->schema->resultset('Tier')->all) {
        $msg_text .= sprintf("%-15.15s: % 3s full, % 3s concession\n",
                             $tier->name,
                             $data{full}{valid_members}{$tier->name} || 0,
                             $data{concession}{valid_members}{$tier->name} || 0
            );
    }
    $msg_text .= "Income expected: \x{00A3}" . sprintf("%0.2f", $data{income}/100) . "\n";
    $msg_text .= "Left this month: " . ($data{recent_expired}{count}{count} || 0) ."\n";
    $data{msg_text} = $msg_text;

    $data{recently} = join("\n", map {
        sprintf("%03d: %40s: %20s: %s", 
                $_->{id},
                $_->{name},
                ($_->{concessionary_rate}
                 ? 'concession' 
                 : $_->{tier}
                ),
                $_->{valid_until}) } (@{ $data{recent_expired}{people} }) );

    return \%data;
}

=head2 ex_members

Arguments: Left in the last N months, Left at least N months ago

Filters the people for members whose most recent payment has expired.

=cut

sub ex_members {
    my ($self, $last_months, $cond, $months_ago) = @_;
    
    $last_months ||= 6;

    my $dtf = $self->result_source->schema->storage->datetime_parser;
    my $now = DateTime->now();
    my $n_months = $now->clone->subtract(months => $last_months);

    # Most recent payment for each person
    my $recent_payments_rs = $self->search_rs(
        { },
        {
            '+columns' => [ { 'max_expires' => { max => 'payments.expires_on_date', '-as' => 'max_expires'}}],
            group_by => 'me.id',
            join => 'payments',
        });

    # Filter for "expired in last N months"
    # If "months_ago" supplied, must be at least that long ago
    return $recent_payments_rs->as_subselect_rs->search_rs(
        {
            'me.max_expires' =>
            { '-between' => [ $dtf->format_datetime($n_months),
                              $dtf->format_datetime($months_ago ? $now->clone->subtract(months => $months_ago) : $now)],
            },
                %$cond
        },
        {
            select => ['me.id', 'me.telegram_chatid', 'me.name'],
            as     => ['id', 'telegram_chatid', 'name'],
        });

}

1;
