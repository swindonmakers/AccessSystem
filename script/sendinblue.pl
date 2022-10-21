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

# Compare to db people:
my $db_people = $schema->resultset('Person')->search_rs({} );
print "Found " . $db_people->count . " people in Database\n";

my @updates = ();
my @checked_emails = ();

foreach my $person (@people) {
    my $db_person = $db_people->search({ '-and' => [
					     end_date => undef,
					     \['LOWER(email) = ?', lc($person->{email})], # 
				       ]});
# email => { '-ilike' => $person->{email} }, end_date => undef });
    if ($db_person->count == 1) {
	$db_person = $db_person->first;
	if (($person->{attributes}{NAME} ne $db_person->name
	     || ($person->{attributes}{OPT_IN} != $db_person->opt_in)
	     || (($person->{attributes}{JOINED} || '') ne $db_person->created_date->date)
	     || ($db_person->valid_until && $person->{attributes}{PAID_UP_UNTIL} ne $db_person->valid_until->date))) {
	    #change list prefs:
	    # turned on opt-in, add events+newsletter
	    if (!$person->{attributes}{OPT_IN} && $db_person->opt_in) {
		push @{ $person->{listIds} }, $events_id, $newsletter_id;
	    }
	    # turned off opt-in, remove em again
	    if ($person->{attributes}{OPT_IN} && !$db_person->opt_in) {
		$person->{listIds} = [ grep { $_ != $events_id && $_ != $newsletter_id } (@{ $person->{listIds} }) ];
	    }
	    # no longer a paid-up member
	    if (!$db_person->valid_until || $db_person->valid_until < DateTime->now) {
		$person->{listIds} = [ grep { $_ != $valid_all_id } (@{ $person->{listIds} }) ];
	    }
	    # is a paid-up member again
	    if ($db_person->valid_until && $db_person->valid_until >= DateTime->now) {
		push @{ $person->{listIds} }, $valid_all_id;
	    }

	    $person->{attributes}{NAME} = $db_person->name;
	    $person->{attributes}{JOINED} = $db_person->created_date->date;
	    $person->{attributes}{OPT_IN} = $db_person->opt_in ? JSON::true : JSON::false;
	    if ($db_person->valid_until) {
		$person->{attributes}{PAID_UP_UNTIL} = $db_person->valid_until->date;
	    }

	    push @updates, $person;
	}
    }
    push @checked_emails, $person->{email};
}
# All changed members:
print "Updating " . scalar @updates . " people statuses in Sendinblue\n";
# print STDERR Dumper(\@updates);
$sb->update_contacts(\@updates);

# New members:
my $new_members = $db_people->search({ email => { '-not_in' => [map { lc($_) } @checked_emails] }, end_date => undef });
print "Adding " . $new_members->count . " new members into Sendinblue\n";

while (my $person = $new_members->next) {
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
exit;
foreach my $person (@gone_people) {
    $sb->delete_contact($person);
}

