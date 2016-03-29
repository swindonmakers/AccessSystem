package AccessSystem::Schema::ResultSet::Person;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub allowed_to_thing {
    my ($self, $token, $thing_guid) = @_;

    my $person_rs = $self->search(
        {
            'allowed.accessible_thing_id' => $thing_guid,
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
        
        my $thing_rs = $self->result_source->schema->resultset('AccessibleThing')->search(
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
1;
