package AccessBot;

use feature 'signatures';

use Mojo::Base 'Telegram::Bot::Brain';
use Config::General;
use LWP::Simple;
use lib 'lib';
use AccessSystem::Schema;

has _token => undef;
has token => sub {
    my ($self) = @_;
    if (!$self->_token) {
        my %conf = Config::General->new("$ENV{BOT_HOME}/keys.conf")->getall();
        $self->_token($conf{'Telegram::Bot'}{'api'});
    };
    return $self->_token();
};

has _db => undef;
has 'db' => sub {
    my ($self) = @_;
    if(!$self->_db) {
        my %mainconf = Config::General->new("$ENV{BOT_HOME}/accesssystem_api.conf")->getall();
        my $db_info = $mainconf{'Model::AccessDB'}{connect_info};
        $self->_db(AccessSystem::Schema->connect($db_info->{dsn}, $db_info->{user}, $db_info->{password}));
    }
    return $self->_db();
};

sub init {
    my $self = shift;
    $self->add_listener(\&read_message);
}

sub member ($self, $message) {
    return $self->db->resultset('Person')->find({ telegram_chatid => $message->from->id });
}

sub read_message {
    my ($self,$message) = @_;
    if($message->text =~ m{^/memberstats}) {
        my $data = $self->db->resultset('Person')->membership_stats;
        my $msg_text = "
Current members: " . ($data->{valid_members}{count} || 0) . " - (" . join(', ', map { "$_: " . ($data->{valid_members}{$_} || 0) } (qw/full concession otherspace adult child/)) . "),
Ex members: " . ($data->{ex_members}{count} || 0) . " - (" . join(', ', map { "$_: " . ($data->{ex_members}{$_} || 0) } (qw/full concession otherspace/)) . "),
Overdue members: " . ($data->{overdue_members}{count} || 0) ." - (" . join(', ', map { "$_: " . ($data->{overdue_members}{$_} || 0) } (qw/full concession otherspace/)) . "),
Left this month: " . ($data->{recent_expired}{count} || 0) ." - (" . join(', ', map { "$_: " . ($data->{recent_expired}{$_} || 0) } (qw/full concession otherspace/)) . ")";

        $message->reply($msg_text);

        return;
    }

    if($message->text =~ m{^/identify}) {
        if($message->text =~ m{^/identify ([ -~]+\@[ -~]+)$}) {
            my $email = $1;
            print STDERR "Email: $email\n";
            my $members = $self->db->resultset('Person')->search_rs({
                '-and' => [
                    end_date => undef,
                    \ ['LOWER(email) = ?', lc($email)],
                   ]});
            if($members->count == 1) {
                my $url = 'https://inside.swindon-makerspace.org/confirm_telegram?chatid=' . $message->from->id . '&email=' . lc($email) . '&username=' . $message->from->username;
                print STDERR "Calling: $url\n";
                # my $member = $members->first;
                # if(!$member->telegram_chatid) {
                #     $member->update({ telegram_chatid => $message->from->id, telegram_username => $message->from->username });
                #     $message->reply('Set your telegram chatid to ' . $message->from->id);
                # } else {
                #     $message->reply('Your telegram chatid is already set! Ask a director to unset it');
                # }
                $message->reply("You should have an email to confirm your membership/telegram mashup");
            } else {
                $message->reply("I can't find a member with that email address, try again or check https://inside.swindon-makerspace.org/profile");
            }
        } else {
            $message->reply("That didn't look like an email address, try again?");
        }

       return;
    }

    if ($message->text =~ m!/doorcode!) {
        if ($self->member($message)->is_valid) {
            $message->reply("Use NNNN on the keypad by either external door of BSS House to get in at night.");
        } elsif ($self->member($message)) {
            $message->reply("I know who you are, but you don't seem to be paid up, sorry");
        } else {
            $message->reply("I don't know who you are.  Please use /identify and then try again");
        }

        return;
    }

    if ($message->text =~ m!^/(help|start)!) {
        $message->reply("I know /identify <your email address>, /memberstats, /doorcode");
        return;
    }
    
    $message->reply(qq<I don't know that command, sorry.>);
}
1;
    
package main;

my $bot = AccessBot->new();
 
my $me = $bot->getMe();
use Data::Dumper;
say "Result from getMe call:";
say Dumper($me->as_hashref);

$bot->think();
