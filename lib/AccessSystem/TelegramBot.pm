package AccessSystem::TelegramBot;

use feature 'signatures';

use Mojo::Base 'Telegram::Bot::Brain';
use Config::General;
use LWP::Simple;
use LWP::UserAgent;
use lib "$ENV{BOT_HOME}/lib";
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
        my $db_info = $self->mainconfig->{'Model::AccessDB'}{connect_info};
        $self->_db(AccessSystem::Schema->connect($db_info->{dsn}, $db_info->{user}, $db_info->{password}));
    }
    return $self->_db();
};

has _mainconfig => undef;
has 'mainconfig' => sub ($self) {
    if (!$self->_mainconfig) {
        $self->_mainconfig(Config::General->new("$ENV{BOT_HOME}/accesssystem_api.conf")->getall());
    }

    if (wantarray) {
        return %{$self->_mainconfig};
    } else {
        return $self->_mainconfig;
    }
};

sub init {
    my $self = shift;
    $self->add_listener(\&read_message);
}

sub member ($self, $message) {
    return $self->db->resultset('Person')->find({ telegram_chatid => $message->from->id });
}

sub authorize ($self, $message) {
    my $member = $self->member($message);

    if (!$member) {
        $message->reply("I don't know who you are.  Please use /identify and then try again.");
        return undef;
    }

    if (!$member->is_valid) {
        $message->reply("I know who you are, but your membership has expired, as of ".$member->valid_until."."
        # . "  If you need payment details again, please use the /bankinfo command.  ");
        );
        return undef;
    }

    return 1;
}

sub read_message {
    my ($self, $message) = @_;
    my %methods = (
        memberstats => qr{^/memberstats},
        identify    => qr{^/identify},
        doorcode    => qr{^/doorcode},
        # bankinfo    => qr{^/bankinfo},
        help        => qr{^/(help|start)},
        );

    foreach my $method (keys %methods) {
        if ($message->text =~ /$methods{$method}/) {
            return $self->$method($message);
        }
    }
    $message->reply(qq<I don't know that command, sorry.  Try /help ?>);
}

sub memberstats {
    my ($self, $message) = @_;
    
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
}

sub identify {
    my ($self, $message) = @_;
    
    if($message->text =~ m{^/identify}) {
        if($message->text =~ m{^/identify ([ -~]+\@[ -~]+)$}) {
            my $email = $1;
            # print STDERR "Email: $email\n";
            my $members = $self->db->resultset('Person')->search_rs({
                '-and' => [
                    end_date => undef,
                    \ ['LOWER(email) = ?', lc($email)],
                   ]});
            if($members->count == 1) {
                my $url = 'http://localhost:3000/confirm_telegram?chatid=' . $message->from->id . '&email=' . lc($email) . '&username=' . $message->from->username;
                # print STDERR "Calling: $url\n";
                my $ua = LWP::UserAgent->new();
                my $resp = $ua->get($url);
                if (!$resp->is_success) {
                    print STDERR "Failed: ", $resp->status_line, " ", $resp->content, "\n";

                }
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
}

sub doorcode {
    my ($self, $message) = @_;
    
    return unless $self->authorize($message);

    my $doorcode = $self->mainconfig->{code_a};

    $message->reply("Use $doorcode on the keypad by either external door of BSS House to get in at night.");
}

sub help {
    my ($self, $message) = @_;
    if ($message->text =~ m!^/(help|start)!) {
        $message->reply("I know /identify <your email address>, /memberstats, /doorcode");
        return;
    }
}
1;
