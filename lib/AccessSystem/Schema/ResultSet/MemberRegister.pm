package AccessSystem::Schema::ResultSet::MemberRegister;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

=head2 new_entry_including_dues

Add person to member register, adding start/end date for all of their
payment gaps.

=cut

sub new_entry_including_dues {
    my ($self, $person) = @_;

    # This is only for fresh members
    # What does this do if someone changed their name!?
    return if $self->search({ name => $person->name })->count;
    # No point if no dues/validity
    return if !$person->is_valid && !$person->valid_until;
    
    my $now = DateTime->now();
    my $payments_rs = $person->payments->search({}, { order_by => { '-asc' => 'paid_on_date' } });
    my $row = $payments_rs->next;
    my $end = $row->expires_on_date;
    my $current_entry;
    while(my $next_row = $payments_rs->next) {
        if($next_row->paid_on_date < $end) {
            $end = $next_row->expires_on_date;
            next;
        }

        # next_row is a new membership, so create row for this one:
        $current_entry = $self->create({
            name => $person->name,
            address => $person->address,
            started_date => $row->paid_on_date->ymd,
            ended_date => $end->ymd,
            updated_date => $now,
            updated_reason => 'Created from old dues data',
        });
        $row = $next_row;
        $end = $next_row->expires_on_date;
    }

    # Create entry for the last set of payments:
    $current_entry = $self->create({
        name => $person->name,
        address => $person->address,
        started_date => $row->paid_on_date->ymd,
        ( $end > $now ? () : (ended_date => $end->ymd) ),
        updated_date => $now,
        updated_reason => ( $end > $now ? 'Current member' : 'Created from old dues data' ),
    });

    return $current_entry;
}

sub on_date {
    my ($self, $at) = @_;

    return $self->search_rs({
        ( $at 
          ? ( 'me.started_date' => { '<=' =>  $at }, -or => [ { 'me.ended_date' => { '>=' =>  $at }}, { 'me.ended_date' => undef }])
          : ( 'me.ended_date' => undef) ),
    });
}

1;
