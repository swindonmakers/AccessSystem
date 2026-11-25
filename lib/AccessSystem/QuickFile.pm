package AccessSystem::QuickFile;

use strict;
use warnings;
use v5.30;
use REST::Client;
use JSON;
use Data::Dumper;
use DateTime;
use Moo;
has debug => ( is => 'rw', default => sub { 0; });

has access_key => (is => 'rw');
has rc_client => (is => 'lazy',
                  default => sub {
                      my ($self) = @_;
                      my $client = REST::Client->new(
                          host => 'https://api-beta.quickfile.co.uk',
                      );
                      $client->addHeader('Authorization', 'Bearer '. $self->access_key);
                      $client->addHeader('Content-Type', 'application/json');
                      $client->setFollow(1);
                      push @{$client->getUseragent->requests_redirectable}, 'POST';
                      push @{$client->getUseragent->requests_redirectable}, 'PATCH';
                      return $client; 
                  });

=head2 get_transactions

Fetch all known "bank" accounts from QuickFile, then extract the one
named "Barclays Current Account". Fetch all transactions for that
account for the last 4 days (unless given other dates). Return an
array of the transactions (having fetched the pages of data if there
are more than 20 entries.

=cut

sub get_transactions {
    my ($self, $start, $end) = @_;

    $start ||= DateTime->now->clone->subtract(days => 4)->ymd;
    $end ||= DateTime->now->ymd;
    # bank_accounts:
    my $accounts = decode_json($self->rc_client->GET('bank_accounts')->responseContent());
    print Dumper($accounts) if $self->debug;
    # Barclays, Directors Loan, Petty Cash, Paypal, Bank Reserve, Credit Card?

    my ($bank_account) = grep { $_->{name} =~ /Barclays Current Account/ } @{$accounts->{data}};

    # https://api-beta.quickfile.co.uk/api-docs/#/Bank/BanksSearch
    my $transactions_res = decode_json($self->rc_client->GET('bank_accounts/' . $bank_account->{id} . "/transactions?order_column=date&order_direction=desc&date_to=$end&date_from=$start&limit=20")->responseContent());

    print Dumper($transactions_res) if $self->debug;
    my $transactions = $transactions_res->{data};
    # In case there are more than one page:
    while($transactions_res->{paging}{next}) {
        $transactions_res = decode_json($self->rc_client->GET($transactions_res->{paging}{next})->responseContent());
    print Dumper($transactions_res) if $self->debug;
        push @{$transactions}, @{$transactions_res->{data}};
    }
    print Dumper($transactions) if $self->debug;

    return $transactions;
}

1;
