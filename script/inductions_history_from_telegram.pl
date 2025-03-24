#!/usr/bin/perl
use strictures 2;

BEGIN {
    $ENV{CATALYST_HOME} ||= '/usr/src/extern/hackspace/AccessSystem';
}

use Config::General;
use lib "$ENV{CATALYST_HOME}/lib";
use AccessSystem::Schema;
use feature 'state', 'say';
use JSON;
use Data::Printer;

if(!$ENV{CATALYST_HOME}) {
    die "Please set the CATALYST_HOME environment variable and try again\n";
}

# Read config to get db connection info:
my %config = Config::General->new("$ENV{CATALYST_HOME}/accesssystem_api_local.conf")->getall;
my $schema = AccessSystem::Schema->connect(
    $config{'Model::AccessDB'}{connect_info}{dsn},
    $config{'Model::AccessDB'}{connect_info}{user},
    $config{'Model::AccessDB'}{connect_info}{password},
);

my $json_fn = 'inductions_export.json';
my $json;
{
    local $/ = undef;
    local @ARGV = $json_fn;
    $json = <>;
}

$json = decode_json($json) or die "Couldn't parse $json_fn as json";

my $message_id_to_sender;
my $prev_inductor;

for my $message (@{$json->{messages}}) {
    next unless defined $message->{from};

    $message_id_to_sender->{$message->{id}} = $message->{from_id};

    my $text = join '', map { $_->{text} } @{$message->{text_entities}};

    # Ok, inducted adam smith on Sander (they should have a confirmation message)
    if ($text =~ m/^Ok, inducted (.*?) on (.*?) \(they should have/) {
        next unless $message->{from} eq 'Swindon MakerSpace Access Bot';

        my $inductee_name = $1;
        my $tool_name = $2;

        next unless $inductee_name =~ m/James Mastros|Jess Robinson/;

        say "'$inductee_name' on '$tool_name'";

        my $inductee = $schema->resultset('Person')->find_person($inductee_name);
        if (not $inductee) {
            say STDERR "Cannot find person row for '$inductee_name'?";
            exit;
        }

        my $inductor_tg_id;

        if (exists $message->{reply_to_message_id}) {
            if (!$message_id_to_sender->{$message->{reply_to_message_id}}) {
                die "This is a reply, but the message it is a reply to does not exist?";
            }

            $inductor_tg_id = $message_id_to_sender->{$message->{reply_to_message_id}}
        } else {
            # Sadly, making this a reply was only implemented fairly recently, so we have to do some degree of guessing here.
            # We assume that there's not enough lag between a /induct command and the response that multiple inductors have tried
            # to induct somebody before the first one gets a reply.
            $inductor_tg_id = $prev_inductor;
        }
        $inductor_tg_id =~ s/user//;

        say "...by $inductor_tg_id";

        my $inductor = $schema->resultset('Person')->find({ telegram_chatid => $inductor_tg_id });
        if (!$inductor) {
            die "Cannot find Person for tg id $inductor_tg_id";
        }

        my $tool = $schema->resultset('Tool')->find({ name => $tool_name });
        if (!$tool) {
            say "Couldn't find Tool for name '$tool_name', skipping";
            next;
        }

        my $allowed = $schema->resultset('Allowed')->find({ tool_id => $tool->id, person_id => $inductee->id });
        if (!$allowed) {
            say "Cannot find Allowed row for ", $inductee->name, " on ", $tool->name;
            next;
        }

        $allowed->update({ inducted_by_id => $inductor->id });
    }

    if ($text =~ m!^/induct!) {
        $prev_inductor = $message->{from_id};
    }
}
