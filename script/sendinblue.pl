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

#my %config = Config::General->new("$ENV{CATALYST_HOME}/accesssystem_api.conf")->getall;
my %localconfig = Config::General->new("$ENV{CATALYST_HOME}/accesssystem_api_local.conf")->getall;
my $schema = AccessSystem::Schema->connect(
    $localconfig{'Model::AccessDB'}{connect_info}{dsn},
    $localconfig{'Model::AccessDB'}{connect_info}{user},
    $localconfig{'Model::AccessDB'}{connect_info}{password},
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
print "Found " . scalar @$contacts . " people in Contacts\n";

my %contacts_check = map { $_->{email} && lc $_->{email} => 1 } @$contacts;

# Compare to db people:
my $db_people = $schema->resultset('Person')->search_rs({} );
print "Found " . $db_people->count . " people in Database\n";

my @updates = ();
my @checked_emails = ();

# gather: people in list:
my $add_valid = [];
my $rem_valid = [];
my $add_news_events = [];
my $rem_news_events = [];

# Bulk update all with "all people" list, update/delete from single lists for the rest?

foreach my $person (@$contacts) {
    my $db_person = $db_people->search(\['LOWER(email) = ?', lc($person->{email})]); #
#     my $db_person = $db_people->search({ '-and' => [
# 					     end_date => undef,
# 					     \['LOWER(email) = ?', lc($person->{email})], # 
# 				       ]});
# # email => { '-ilike' => $person->{email} }, end_date => undef });
    # if ($person->{email} =~ /hunter/) {
    #     $DB::single=1;
    # }
    if ($db_person->count == 1) {
        $db_person = $db_person->first;
        # delete $person->{listIds};
        # if (($person->{attributes}{NAME} ne $db_person->name
        #      || ($person->{attributes}{OPT_IN} != $db_person->opt_in)
        #      || (($person->{attributes}{JOINED} || '') ne $db_person->created_date->date) 
        #      || ($db_person->valid_until && $person->{attributes}{PAID_UP_UNTIL} ne $db_person->real_expiry($localconfig{overlap_days})->date))) {
            #change list prefs:
            # turned on opt-in, add events+newsletter
            if ($db_person->opt_in && !grep { $_ == $newsletter_id} @{$person->{listIds}}) {
                push @$add_news_events, $person->{email};
            }
            # turned off opt-in, remove em again
            if (!$db_person->opt_in && grep { $_ == $newsletter_id} @{$person->{listIds}}) {
                push @$rem_news_events, $person->{email};
            }
            # no longer a paid-up member
            print STDERR $db_person->name, Data::Dumper::Dumper($person->{listIds});
            if ((!$db_person->valid_until || $db_person->real_expiry($localconfig{overlap_days}) < DateTime->now) && grep { $_ == $valid_all_id} @{$person->{listIds}}) {
                push @$rem_valid, $person->{email};
                # print STDERR $db_person->name, "List Ids changed ", Data::Dumper::Dumper($person->{listIds});
                # push @{$person->{unlinkListIds}}, $valid_all_id;
            }
            # is a paid-up member again
            if (($db_person->valid_until && $db_person->real_expiry($localconfig{overlap_days}) >= DateTime->now) && !grep { $_ == $valid_all_id} @{$person->{listIds}}) {
                push @$add_valid, $person->{email};
                # print STDERR $db_person->name, "List Ids changed again?", Data::Dumper::Dumper($person->{listIds});
            }

        if (!$db_person->end_date &&
            ($person->{attributes}{NAME} ne $db_person->name
             || ($person->{attributes}{OPT_IN} != $db_person->opt_in)
             || (($person->{attributes}{JOINED} || '') ne $db_person->created_date->date)
             || ($db_person->valid_until && $person->{attributes}{PAID_UP_UNTIL} ne $db_person->real_expiry($localconfig{overlap_days})->date))) {
            $person->{attributes}{NAME} = $db_person->name;
            $person->{attributes}{JOINED} = $db_person->created_date->date;
            $person->{attributes}{OPT_IN} = $db_person->opt_in ? JSON::true : JSON::false;
            if ($db_person->real_expiry($localconfig{overlap_days})) {
                $person->{attributes}{PAID_UP_UNTIL} = $db_person->real_expiry($localconfig{overlap_days})->date;
            }
            push @updates, $person;
        }
    } else {
        # If can't find the email in our db then presumably they changed their
        # Email, remove from any lists
        foreach my $lId (@{$person->{listIds}}) {
            if ($lId == $valid_all_id) {
                push @$rem_valid, $person->{email};
            }
            # if ($lId == $events_id) {
            #     push @$rem_news_events, $person->{email};
            # }
        }
    }
    push @checked_emails, $person->{email};
}
# All changed members:
print "Updating " . scalar @updates . " people statuses in Sendinblue\n";
# print STDERR Dumper(\@updates);
if (@updates) {
    $sb->import_contacts(\@updates, [$all_people_id]);
}
# remove from news_events/valid:
if (@$rem_news_events) {
    $sb->delete_from_list($events_id, $rem_news_events);
    $sb->delete_from_list($newsletter_id, $rem_news_events);
}
if (@$rem_valid) {
    $sb->delete_from_list($valid_all_id, $rem_valid);
}
# add to news,events,valid:
if (@$add_news_events) {
    $sb->add_to_list($events_id, $add_news_events);
    $sb->add_to_list($newsletter_id, $add_news_events);
}
if (@$add_valid) {
    $sb->add_to_list($valid_all_id, $add_valid);
}

# New members:
#my @not_in = map { lc($_) } @checked_emails;
# Don't add any contacts that are already in the system
my @not_in = keys %contacts_check;
my $new_members = $db_people->search({ email => { '-not_in' => \@not_in }, end_date => undef });
print "Adding " . $new_members->count . " new members into Sendinblue\n";

while (my $person = $new_members->next) {
    # not_in is case sensitive, sigh
    next if $contacts_check{lc $person->email};
    $sb->add_contact({
        email => $person->email,
        listIds => [ $all_people_id, ($person->opt_in ? ($events_id, $newsletter_id) : ()), ( $person->valid_until && $person->valid_until >= DateTime->now ? ($valid_all_id) : ()) ],
        attributes => {
            NAME => $person->name,
            OPT_IN => ($person->opt_in ? JSON::true : JSON::false),
            JOINED => $person->created_date->date,
            ( $person->valid_until ? (PAID_UP_UNTIL => $person->valid_until->date) : () ),
        },
    });
}

# deleted people:
# Need to rethink this as can't remove Newsletter only members.. wait, Newsletter only folks will not be in "All People"?
# my @gone_people = grep { !$db_people->find({email => $_->{email}}) } @people;

my $ended_people = $db_people->search({ end_date => { '!=' => undef }});; 
my @gone_people = grep { $ended_people->search({email => lc($_->{email})})->count >= 1} @people;

print "Would remove " . scalar @gone_people . " members who left from Sendinblue\n";
# print STDERR Dumper(\@gone_people);
foreach my $person (@gone_people) {
    $sb->delete_contact($person);
}

