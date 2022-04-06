#!usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use LWP::UserAgent;
use JSON;
use Config::General;
use List::Util qw/any/;

use lib "$ENV{CATALYST_HOME}/lib";
use AccessSystem::Schema;
use Sendinblue::API;

my %config = Config::General->new("$ENV{CATALYST_HOME}/accesssystem_api.conf")->getall;
my %localconfig = Config::General->new("$ENV{CATALYST_HOME}/accesssystem_api_local.conf")->getall;
my $schema = AccessSystem::Schema->connect(
    $config{'Model::AccessDB'}{connect_info}{dsn},
    $config{'Model::AccessDB'}{connect_info}{user},
    $config{'Model::AccessDB'}{connect_info}{password},
    );
my $sb_key = $localconfig{Sendinblue}{'api-key'};
my $sb = Sendinblue::API->new({api_key => $sb_key});
my $group_all = 'All People';
my $valid_all = 'Paid Up Members'; #membership related things (elections, closed etc)
my $events_etc = 'Events & Workshops';
my $newsletter = 'Newsletter'; #opted-in + non/never members

# lists
# current thoughts:
# 1. membership details / issues with your membership, etc
# 2. space details / space is open/closed/on fire, elections
# 3. updates on activities members can/should join in, eg courses, events
# 4. everything else - not directly space/member related

my $lists = $sb->get_lists();
my ($all_people_id) = map { $_->{id} } grep { $_->{name} eq $group_all } (@$lists);
my ($valid_all_id) = map { $_->{id} } grep { $_->{name} eq $valid_all } (@$lists);
my ($events_id) = map { $_->{id} } grep { $_->{name} eq $events_etc } (@$lists);
my ($newsletter_id) = map { $_->{id} } grep { $_->{name} eq $newsletter } (@$lists);

my $contacts = $sb->get_contacts();

# Filter just in case we have others:
my @people = grep { any {$_ == $all_people_id} (@{$_->{listIds}}) } (@$contacts);
print "Found " . scalar @people . " people in All People\n";

# Compare to db people:
my $db_people = $schema->resultset('Person')->search_rs({}, { prefetch => 1});
print "Found " . $db_people->count . " people in Database\n";

my @updates = ();
my @checked_emails = ();

foreach my $person (@people) {
    my $db_person = $db_people->find({ email => $person->{email} });
    if ($person->{attributes}{NAME} != $db_person->name
        || ($person->{attributes}{OPT_IN} eq 'Yes' && !$db_person->opt_in)
        || ($person->{attributes}{OPT_IN} eq 'No' && $db_person->opt_in)
        || $person->{attributes}{PAID_UP_UNTIL} != $db_person->valid_until->date) {
        #change list prefs:
        # turned on opt-in, add events+newsletter
        if ($person->{attributes}{OPT_IN} eq 'No' && $db_person->opt_in) {
            push @{ $person->{listIds} }, $events_id, $newsletter_id;
        }
        # turned off opt-in, remove em again
        if ($person->{attributes}{OPT_IN} eq 'Yes' && !$db_person->opt_in) {
            $person->{listIds} = [ grep { $_ != $events_id && $_ != $newsletter_id } (@{ $person->{listIds} }) ];
        }
        # no longer a paid-up member
        if ($db_person->valid_until < DateTime->now) {
            $person->{listIds} = [ grep { $_ != $valid_all_id } (@{ $person->{listIds} }) ];
        }
        # is a paid-up member again
        if ($db_person->valid_until >= DateTime->now) {
            push @{ $person->{listIds} }, $valid_all_id;
        }

        $person->{attributes}{NAME} = $db_person->name;
        $person->{attributes}{OPT_IN} = $db_person->opt_in ? 'Yes':'No';
        $person->{attributes}{PAID_UP_UNTIL} = $db_person->valid_until->date;

        push @updates, $person;
    }
    push @checked_emails, $person->{email};
}
# All changed members:
print "Updating " . scalar @updates . " people statuses in Sendinblue\n";
$sb->update_contacts(\@people);

# New members:
my $new_members = $db_people->search({ email => { '-not_in' => \@checked_emails } });
print "Adding " . $new_members->count . " new members into Sendinblue\n";
while (my $person = $new_members->next) {
    $sb->add_contact({
        email => $person->email,
        listIds => [ $all_people_id, ($person->opt_in ? ($events_id, $newsletter_id) : ()), ( $person->valid_until < DateTime->now ? () : ($valid_all_id)) ],
        attributes => {
            NAME => $person->name,
            OPT_IN => ($person->opt_in ? 'Yes':'No'),
            PAID_UP_UNTIL => $person->valid_until->date,
        },
    });
}

# deleted people:
# Need to rethink this as can't remove Newsletter only members.. wait, Newsletter only folks will not be in "All People"?
# my @gone_people = grep { !$db_people->find({email => $_->{email}}) } @people;

my @gone_people = grep { my $p = $db_people->find({email => $_->{email}}); $p && $p->end_date } @people;
print "Removing " . scalar @gone_people . " members who left from Sendinblue\n";

foreach my $person (@gone_people) {
    $sb->delete_contact($person);
}

# $resp = $ua->post('https://api.sendinblue.com/v3/contacts',
#                   Content => encode_json({
#                       'email' => 'fred@bloggs.com',
#                           'attributes' => {
#                               'NAME' => 'Fred',
#                                   'OPT_IN' => 'Yes',
#                                   'JOINED' => '2020-01-01',
#                                   'PAID_UP_UNTIL' => '2023-06-01',
#                       },
#                           'ListIds' => [ $all_people ],
#                   }),
#                   'Accept' => 'application/json', 'api-key' =>' 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', 'Content-Type' => 'application/json');
# $result = decode_json($resp->decoded_content);
# print Dumper($result);

# $resp = $ua->delete('https://api.sendinblue.com/v3/contacts/1947', 'Accept' => 'application/json', 'api-key' =>' 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');
# $result = decode_json($resp->decoded_content);
# print Dumper($result);
