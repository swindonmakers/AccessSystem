package AccessSystem::TelegramBot;

use feature 'signatures';

use Mojo::Base 'Telegram::Bot::Brain';
use Telegram::Bot::Object::InlineKeyboardMarkup;
use Telegram::Bot::Object::InlineKeyboardButton;
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
        my %mainconf = Config::General->new("$ENV{BOT_HOME}/accesssystem_api.conf")->getall();
        my $db_info = $mainconf{'Model::AccessDB'}{connect_info};
        $self->_db(AccessSystem::Schema->connect($db_info->{dsn}, $db_info->{user}, $db_info->{password}));
    }
    return $self->_db();
};

has waiting_on_response => sub { return {}; };

sub init {
    my $self = shift;
    $self->add_listener(\&read_message);
}

sub member ($self, $message) {
    return $self->db->resultset('Person')->find({ telegram_chatid => $message->from->id });
}

sub read_message {
    my ($self, $message) = @_;
    my %methods = (
        memberstats => qr{^/memberstats},
        identify    => qr{^/identify},
        doorcode    => qr{^/doorcode},
        tools       => qr{^/tools$},
        add_tool    => qr{^/add_tool},
        help        => qr{^/(help|start)},
        );

    print STDERR ref $message;
    if (ref $message eq 'Telegram::Bot::Object::Message') {
        foreach my $method (keys %methods) {
            if ($message->text =~ /$methods{$method}/) {
                return $self->$method($message);
            }
        }
    } elsif (ref $message eq 'Telegram::Bot::Object::CallbackQuery') {
        print STDERR "Calling resolve\n";
        return $self->resolve_callback($message);
    }
    $message->reply(qq<I don't know that command, sorry.>);
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
    
    if ($message->text =~ m!/doorcode!) {
	my $member = $self->member($message);
        if ($member && $member->is_valid) {
            $message->reply("Use NNNN on the keypad by either external door of BSS House to get in at night.");
        } elsif ($member) {
            $message->reply("I know who you are, but you don't seem to be paid up, sorry");
        } else {
            $message->reply("I don't know who you are.  Please use /identify and then try again");
        }
    }
}

=head2 tools

Output a list of tool names.

=cut

sub tools ($self, $message) {
    my $tools = $self->db->resultset('Tool');
    $tools->result_class('DBIx::Class::ResultClass::HashRefInflator');

    my $tool_str = join("\n", map { $_->{name} . ($_->{requires_induction} ? ' (induction)' : '') } ($tools->all));
    $message->reply($tool_str);
}

=head2 add_tool

Add a new makerspace tool (especially if it requires induction)

=cut

sub add_tool ($self, $message) {
    print "Add tool\n";
    if ($message->text =~ m{/add_tool ([\w\d ]+)$}) {
        my $name = $1;
        print "Name: $name\n";
        # Each user can only have one response they're waiting on at a time?
        $self->waiting_on_response()->{$message->from->id} = {
            'action' => 'add_tool',
                'name' => $name
        };
        $message->_brain->sendMessage({
            chat_id => $message->chat->id,
            text => "Adding $1 ... \nDoes it need induction?",
            reply_markup => Telegram::Bot::Object::InlineKeyboardMarkup->new({
                inline_keyboard => [[
                    Telegram::Bot::Object::InlineKeyboardButton->new({
                        text => 'Yes',
                        callback_data => "add_tool|$name|Yes",
                    }),
                    Telegram::Bot::Object::InlineKeyboardButton->new({
                        text => 'No',
                        callback_data => "add_tool|$name|No",
                    }),
                ]]
            })
        });
    }
}

sub resolve_callback ($self, $callback) {
    my $waiting = $self->waiting_on_response->{$callback->from->id};
    if (!$waiting) {
        $callback->_brain->sendMessage({'chat_id' => $callback->message->chat->id, text => 'Confusion in the bot-brain, what are you responding to?'});
        return $callback->answer('Arghhh');
    }
    my @args = split(/\|/, $callback->data);
    if ($waiting->{action} eq $args[0] && $waiting->{name} eq $args[1]) {
        delete $self->waiting_on_response->{$callback->from->id};
        my $tool = $self->db->resultset('Tool')->update_or_create({
            name => $args[1],
            requires_induction => $args[2] eq 'Yes' ? 1 : 0,
            # team?
        });
        if (!$tool) {
            return $callback->answer('Failed');
        }
        return $callback->answer('Created');
    }
    return $callback->answer('Confused!');
}


sub help {
    my ($self, $message) = @_;
    if ($message->text =~ m!^/(help|start)!) {
        $message->reply("I know /identify <your email address>, /memberstats, /doorcode");
    }
}
1;
