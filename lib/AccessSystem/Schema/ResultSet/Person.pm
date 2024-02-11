package AccessSystem::Schema::ResultSet::Person;

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use Feature::Compat::Try;
use DateTime;
use SQL::Abstract;
#use SQL::Abstract::Plugin::ExtraClauses;
use base 'DBIx::Class::ResultSet';

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

sub allowed_to_thing {
    my ($self, $token, $thing_guid) = @_;

    my $person_rs = $self->search(
        {
            'allowed.tool_id' => $thing_guid,
            'tokens.id' => $token,
        }, {
            '+columns' => [{ 'trainer' => 'allowed.is_admin'}],
            join => ['allowed', 'tokens' ],
        });
    
    if($person_rs->count == 1 && $person_rs->first->is_valid ) {
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
            if (!$r_allow) {
                return {
                    error => 'No access for Weekend Member',
                    colour => 0x21,
                };
            }
        }
        return {
            person => $person,
        };
    } elsif( $person_rs->count > 1) {
        return {
            error => 'More than 1 account. Talk to a director',
            colour => 0x25,
        };
    } elsif( $person_rs->count == 1 && !$person_rs->first->is_valid) {
        return {
            error => "Membership Expired/Unpaid",
            colour => 0x22,
        };
    } else {
        my $person;
        my $has_token = $self->search(
            {
                'tokens.id' => $token,
            }, {
                'join' => 'tokens',
            });
        if(!$has_token->count) {
            return {
                error => "RFID tag 0x($token) not recognised",
                colour => 0x20,
            };
        } else {
            $person = $has_token->first;
        }
        
        my $thing_rs = $self->result_source->schema->resultset('Tool')->search(
            {
                'id' => $thing_guid,
            });
        if(!$thing_rs->count) {
            return {
                person => $person,
                error => "($thing_guid) not recognised",
            }
        } else {
            return {
                error => "You are not inducted on this tool",
                person => $person,
                thing => $thing_rs->first,
                colour => 0x24,
            };
        }
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

1;
