package AccessSystem::Schema::ResultSet::Person;

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use Try::Tiny;
use DateTime;

use base 'DBIx::Class::ResultSet';

sub find_person {
    my ($self, $input, $args) = @_;

    my $person = $self->find({ 'me.name' => $input }, $args);
    if ($person) {
        return $person;
    }
    my $people = $self->search_rs({ 'me.name' => { '-like' => "$input%" }}, $args);
    if ($people->count == 1) {
        $person = $people->first;
    }
    return $person if $person;
    try {
        # Pg syntax, but not other databases, sigh
        my $pgpeople = $self->search_rs({ 'me.name' => { '-ilike' => "$input%" }}, $args);
        if ($pgpeople->count == 1) {
            $people = $pgpeople;
            $person = $pgpeople->first;
        }
    } catch {
        print "This is not Pg: $_\n";
    };
    return $person if $person;
    
    warn "Add more people-finding magic here: $input failed\n";
    return undef;
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
        return {
            person => $person_rs->first,
        };
    } elsif( $person_rs->count > 1) {
        return {
            error => 'Somehow that returned more than one person! <wibble>',
        };
    } elsif( $person_rs->count == 1 && !$person_rs->first->is_valid) {
        return {
            error => "Member would have access with that token, but their membership has expired",
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
                error => "The token ($token) isn't associated with any user",
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
                error => "That thing string ($thing_guid) doesn't represent any AccessibleThing I've heard of",
            }
        } else {
            return {
                error => "The thing exists, but the Person isn't allowed to access it",
                person => $person,
                thing => $thing_rs->first,
            };
        }
    }

    return { error => 'I have no idea what happened there, but that did\'t work' };

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

sub membership_stats {
    my ($self) = @_;

    my %data = ();
    my $income;
    my $now = DateTime->now()->subtract(days => 1);
    my $four_weeks = $now->clone->subtract('days' => 27);

    while (my $member = $self->next() ) {
        my @flags = ();
        push @flags, 'valid_members' if $member->is_valid;
        push @flags, 'child' if $member->parent;

        if(!$member->parent) {
            push @flags, 'concession' if $member->concessionary_rate;
            push @flags, 'otherspace' if $member->member_of_other_hackspace;
            push @flags, 'full' if !$member->member_of_other_hackspace && ! $member->concessionary_rate;

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
                push @{ $data{$f}{people} }, { %cols{qw/id parent_id name member_of_other_hackspace created_date end_date/}, concessionary_rate => $member->concessionary_rate, valid_until => $v_until->ymd };
            }
            for my $g (@flags) {
                $data{$f}{$g}++;
            }
        }
    }

    $data{income} = $income;

    return \%data;
}

1;
