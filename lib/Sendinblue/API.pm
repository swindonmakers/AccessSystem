package Sendinblue::API;

use strict;
use warnings;

use Data::Dumper;
use LWP::UserAgent;
use JSON;
use URI;
use URI::QueryParam;
use Moo;

has 'api_key' => ( is => 'ro' );
has 'base_url' => ( is => 'ro', default => sub { return 'https://api.sendinblue.com/'; });
has 'api_version' => ( is => 'ro', default => sub { return 'v3'; });
has 'ua' => ( is => 'rw', default => sub { return LWP::UserAgent->new(); });

sub _construct_uri {
    my ($self, $path, $args) = @_;

    my $uri = URI->new($self->base_url);
    $uri->path($self->api_version .'/' . $path);
    if ($args && ref $args eq 'HASH') {
        foreach my $key (keys %$args) {
            $uri->query_param($key, ref $args->{$key} eq 'ARRAY' ? @${$args->{$key}} : $args->{$key});
        }
    }

    return $uri;
}

sub headers {
    my ($self) = @_;

    return {
        'Content-Type' => 'application/json',
        Accept => 'application/json',
        'api-key' => $self->api_key,
    };
}

sub get_lists {
    my ($self) = @_;

    my @lists = ();
    my ($offset, $limit) = (0, 50);
    my $uri = $self->_construct_uri('contacts/lists', { limit => $limit, offset => $offset });
    my $response = $self->ua->get($uri, %{ $self->headers });
    if($response->is_success) {
        my $result = decode_json($response->decoded_content);
        @lists = @{$result->{lists}};
        while (scalar @lists < $result->{count}) {
            $offset += $limit;
            my $uri = $self->_construct_uri('contacts/lists', { limit => $limit, offset => $offset });
            my $response = $self->ua->get($uri, %{ $self->headers });
            for my $list (@{ $response->{lists} }) {
                push @lists, $list;
            }
        }
    } else {
        warn "Error from $uri: " . $response->status_line . "\n" . $response->decoded_content;
    }

    return \@lists;
}

sub get_contacts {
    my ($self) = @_;

    my @contacts = ();
    my ($offset, $limit) = (0, 50);
    my $uri = $self->_construct_uri('contacts', { limit => $limit, offset => $offset });
    my $response = $self->ua->get($uri, %{ $self->headers });
    if($response->is_success) {
        my $result = decode_json($response->decoded_content);
        @contacts = @{$result->{contacts}};
        while (scalar @contacts < $result->{count}) {
            $offset += $limit;
            my $uri = $self->_construct_uri('contacts', { limit => $limit, offset => $offset });
            my $response = $self->ua->get($uri, %{ $self->headers });
	    $result = decode_json($response->decoded_content);
            for my $person (@{ $result->{contacts} }) {
                push @contacts, $person;
            }
        }
    } else {
        warn "Error from $uri: " . $response->status_line . "\n" . $response->decoded_content;
    }

    return \@contacts;
}

sub add_contact {
    my ($self, $contact) = @_;

    my $uri = $self->_construct_uri('contacts');
    my $response = $self->ua->post(
        $uri,
        Content => encode_json($contact),
        %{ $self->headers },
    );

    if($response->is_success) {
        return decode_json $response->decoded_content;
    } else {
        warn "Post $uri failed: " . $response->status_line;
        return {};
    }
    
}

sub update_contacts {
    my ($self, $contacts) = @_;

    return if !@$contacts;
    # no modifiedAt / createdAt
    # only one of email/id/sms
    foreach my $c (@$contacts) {
        delete $c->{modifiedAt};
        delete $c->{createdAt};
        delete $c->{email};
        delete $c->{sms};
    }
    my $uri = $self->_construct_uri('contacts/batch');
    print STDERR Dumper($contacts);
    my @clist = @$contacts;
    my @sublist = @$contacts;
    my $response;
    if (scalar @$contacts > 100) {
        my $total = scalar @$contacts;
        while (@clist) {
            @sublist = splice(@clist, 0, 99);
	
            $response = $self->ua->post(
                $uri,
                Content => encode_json({ contacts => \@sublist}),
                %{ $self->headers },
                );
#            print STDERR "Update Contacts:", Dumper( $response);
            sleep 1;
        }
    } else {
        $response = $self->ua->post(
            $uri,
            Content => encode_json({ contacts => $contacts}),
            %{ $self->headers },
            );
#        print STDERR "Update Contacts:", Dumper( $response);
    }
    if($response->is_success) {
        if ($response->code == 204) {
            return 1;
        } else {
            return decode_json $response->decoded_content;
        }
    } else {
        warn "Post $uri failed: " . $response->status_line;
        return {};
    }
}

sub delete_contact {
    my ($self, $contact) = @_;

    my $uri = $self->_construct_uri('contacts/' . $contact->{id});
    my $response = $self->ua->delete($uri, %{ $self->headers });
    if ($response->is_sucess) {
        return 1;
    } else {
        warn "Delete $uri failed: " . $response->status_line;
        return 0;
    }
}

1;
