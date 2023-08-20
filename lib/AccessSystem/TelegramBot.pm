package AccessSystem::TelegramBot;
no warnings 'experimental::signatures';
use feature 'signatures';

use Mojo::Base 'Telegram::Bot::Brain';
use Telegram::Bot::Object::InlineKeyboardMarkup;
use Telegram::Bot::Object::InlineKeyboardButton;
use Config::General;
use Data::Dumper;
use LWP::Simple;
use LWP::UserAgent;
use Text::Fuzzy;
use JSON 'decode_json';
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
        $self->_mainconfig({Config::General->new("$ENV{BOT_HOME}/accesssystem_api_local.conf")->getall()});
    }

    if (wantarray) {
        return %{$self->_mainconfig};
    } else {
        return $self->_mainconfig;
    }
};

has bot_name => '';
has me => undef;
has 'base_url' => sub ($self) {
    return $self->mainconfig->{base_url};
};

has chat_rights => sub { return {}; };

has waiting_on_response => sub { return {}; };

sub init {
    my $self = shift;
    $self->add_listener(\&read_message);
}

sub member ($self, $message) {
    return $self->db->resultset('Person')->find({ telegram_chatid => $message->from->id });
}

=head1 authorize
   
   return unless $self->authorize($message);

Check if the sender of the C<$message> is a currently valid member.

   return unless $self->authorize($message, 'invalid_ok');

Check if we know who this is, but allow the command to continue if they aren't paid up.

   'private'

Only allowed via private message.

=cut

sub authorize ($self, $message, @tags) {
    my $member = $self->member($message);
    my %tags = map {$_ => 1} @tags;

    if (!$member) {
        $message->reply("I don't know who you are.  Please use /identify <your email address> and then try again.");
        return undef;
    }

    return $member if $tags{invalid_ok};

    if (!$member->is_valid) {
        $message->reply("I know who you are, but your membership has expired, as of ".$member->valid_until."."
        . "  If you need payment details again, please use the /bankinfo command.  "
        );
        return undef;
    }
    if ($message->chat->type ne 'private' && $tags{private}) {
        $message->reply("This command should be done in a private chat");
        return undef;
    }

    return $member;
}

=head1 find_tool

Given a bunch of text representing a tool, either return a tool row object, or reply to the message with a keyboard for them to pick it next time.

=cut

sub find_tool ($self, $name, $method, $args = undef) {
    my ($tool, $tools_rs) = $self->db->resultset('Tool')->find_tool($name);
    if ($tool) {
        return ('success', $tool);
    }

    if ($tools_rs->count == 0) {
        $tools_rs = $self->db->resultset('Tool');
    }

    my $fuzzy = Text::Fuzzy->new(lc $name);
    $fuzzy->transpositions_ok(1);
    my @possibles = map { 
        +{row => $_, 
            dist => $fuzzy->distance(lc $_->name), 
            name => $_->name
        } } $tools_rs->all;
    @possibles = sort {$a->{dist} <=> $b->{dist} or $a->{name} cmp $b->{name}} @possibles;

    my $keyboard_items = {};
    my $keyboard_order = [];
    print STDERR "in find_tool: \n";
    for (@possibles[0..5]) {
        last if !$_;
        my $text = "$_->{name} -- $_->{dist}";
        $keyboard_items->{$text} = "tool|$_->{name}";
        push @$keyboard_order, $text;
    }

    return ('keyboard', $self->generic_keyboard($method, $keyboard_items, 2, ['Cancel'], $keyboard_order));

}

sub read_message ($self, $message) {
    my %methods = (
        memberstats   => {
            match => qr{^/memberstats},
            help  => '/memberstats',
        },
        identify      => {
            match => qr{^/identify},
            help  => '/identify <your email address>',
        },
        doorcode      => {
            match => qr{^/doorcode},
            help  => '/doorcode',
        },
        bankinfo      => {
            match => qr{^/bankinfo},
            help  => '',
        },
        tools         => {
            match => qr{^/tools},
            help  => '/tools',
        },
        add_tool      => {
            match => qr{^/add_tool},
            help  => '/add_tool <tool>',
        },
        find_member => {
            match => qr{^/whois\b},,
            help  => '/whois <name>',
        },
        induct_member => {
            match => qr{^/induct\b},,
            help  => '/induct <name> on <tool>',
        },
        inducted_on   => {
            match => qr{^/inducted_on\b},
            help  => '/inducted_on <tool>',
        },
        inductions    => {
            match => qr{^/inductions\b},
            help  => '/inductions <member name>',
        },
        make_inductor => {
            match => qr{^/make_inductor\b},
            help  => '/make_inductor <member name> on <tool name>',
        },
        balance       => {
            match => qr{^/balance\b},
            help  => '/balance\b',
        },
        prices        => {
            match => qr{^/prices\b},
            help  => '/prices',
        },
        pay           => {
            match => qr{^/pay\b},
            help  => '/pay',
        },
        );

    if (ref($message) eq 'Telegram::Bot::Object::Message' && $message->text) {
        print STDERR $message->text, "\n" if ($message->text =~ q{^/});
        if ($message->text =~ qr{^/(help|start)}) {
            return $message->reply(join("\n", "I know: ", map {$methods{$_}->{help}} (sort keys %methods) ));
        }
        foreach my $method (keys %methods) {
            if ($message->text && $message->text =~ /$methods{$method}{match}/) {
                my $message_text = $message->text;
                my $replace = '\@' . $self->bot_name;
                $message_text =~ s/$replace//;
                return $self->$method($message_text, $message);
            }
        }
    } elsif (ref($message) eq 'Telegram::Bot::Object::Message' && $message->new_chat_members) {
        $self->check_if_ban($message);
    } elsif (ref($message) eq 'Telegram::Bot::Object::CallbackQuery') {
        # print STDERR "Calling resolve\n";
        return $self->resolve_callback($message);
    } elsif (ref($message) eq 'Telegram::Bot::Object::ChatJoinRequest') {
        # print STDERR "Calling resolve\n";
        print STDERR Data::Dumper::Dumper($message);
        return $self->respond_to_join_request($message);
    }
    # This turns out to be just annoying..
    # if ($message->text =~ m{^/}) {
    #     $message->reply(qq<I don't know that command, sorry.>);
    # }
}

sub bankinfo ($self, $text, $message) {
    return unless $self->authorize($message, 'invalid_ok');

    my $member = $self->member($message);

    my $dues = sprintf('%.2f', $member->dues / 100);
    my $bank_ref = $member->bank_ref;

    my $new_text = <<"END";
Monthly fee: $dues/month
To: Swindon Makerspace
Bank: Barclays
Sort Code: 20-84-58
Account: 83789160
Ref: $bank_ref
END

    $message->reply($new_text);
}

sub memberstats ($self, $text, $message) {
    my $data = $self->db->resultset('Person')->membership_stats;
    print STDERR Data::Dumper::Dumper($data);
    
    my $msg_text = '<pre>' . $data->{msg_text}. '</pre>';

    $message->reply($msg_text, { parse_mode => 'html'});

    return;
}

sub identify ($self, $text, $message) {
    if($text =~ m{^/identify ([ -~]+\@[ -~]+)$}) {
        my $email = $1;
        # print STDERR "Email: $email\n";
        my $members = $self->db->resultset('Person')->search_rs({
            '-and' => [
                end_date => undef,
                \ ['LOWER(email) = ?', lc($email)],
                ]});
        if($members->count == 1) {
            if (!$members->first->telegram_chatid) {
                my $url = $self->base_url . 'confirm_telegram?chatid=' . $message->from->id . '&email=' . lc($email) . '&username=' . $message->from->username;
                # print STDERR "Calling: $url\n";
                my $ua = LWP::UserAgent->new();
                my $resp = $ua->get($url);
                if (!$resp->is_success) {
                    print STDERR "Failed: ", $resp->status_line, " ", $resp->content, "\n";
                    $message->reply("I attempted to email you but.. that didn't work, go poke Jess R about that");
                } else {
                    $message->reply("You should receive an email to confirm your membership/telegram mashup");
                }
            } else {
                $message->reply("It appears you're already identified, if it's not working regardless, poke Jess R");
            }
        } else {
            $message->reply("I can't find a member with that email address, try again or check " . $self->base_url . "profile");
        }
    } else {
        $message->reply("That didn't look like an email address, try again?");
    }
}

sub doorcode ($self, $text, $message) {
    return unless $self->authorize($message);

    my $doorcode = $self->mainconfig->{code_a};

    $message->reply("Use $doorcode on the keypad by either external door of BSS House to get in at night.");
}

=head2 tools

Output a list of tool names.

=cut

sub tools ($self, $text, $message) {
    my $tools = $self->db->resultset('Tool');
    $tools->result_class('DBIx::Class::ResultClass::HashRefInflator');
    if ($text =~ m{/tools ([\w\d\s]+)}) {
        (undef, $tools) = $tools->find_tool($1, undef, 'DBIx::Class::ResultClass::HashRefInflator');
    }

    my $tool_str = join("\n",
                        map {
                            $_->{name} . ($_->{requires_induction}
                                            ? ' (induction)'
                                            : '')
                        }
                        grep { $_->{name} !~ /oneall_login_callback/ }
                        ($tools->all));
    $tool_str ||= '<None found>';
    $message->reply($tool_str);
}

=head2 add_tool

Add a new makerspace tool (especially if it requires induction)

=cut

sub add_tool ($self, $text, $message, $args = undef) {
    return unless $self->authorize($message);

    if (!$args) {
        if ($text =~ m{/add_tool ([\w\d ]+)$}) {
            my $name = $1;
            print "Name: $name\n";
            # Each user can only have one response they're waiting on at a time?
            $self->waiting_on_response()->{$message->from->id} = {
                'action' => 'add_tool',
                    'name' => $name,
                    'text' => $text,
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
        } else {
            return $message->reply("Try /add_tool <name of tool, letters, numbers and whitespace allowed>");
        }
    } else {
        # Done with callbacks, create
        delete $self->waiting_on_response->{$message->from->id};
        my $tool = $self->db->resultset('Tool')->update_or_create({
            name => $args->[1],
            requires_induction => $args->[2] eq 'Yes' ? 1 : 0,
            team => '',
        });
        if (!$tool) {
            return $message->answer('Failed');
        }
        return $message->answer('Created');
    }
}

=head2 find_member (whois)

Simple member lookup (are they a member?)

=cut

sub find_member ($self, $text, $message, $args = undef) {
    return unless $self->authorize($message);

    my ($person, $people_rs, $p_status, $person_or_keyb);
    my $member = $self->member($message);
    return if !$member;
    #                                  /induct James Mastros on Point of Sale
    if (!$args && $text =~ m{^/whois\s(['\w\s]+)$}) {
        my ($name) = ($1);

        ($person_or_keyb, $people_rs) = $self->db->resultset('Person')->find_person($name);
        $p_status = $person_or_keyb ? 'success' : undef;
        if (!$p_status && !$people_rs->count) {
            return $message->reply("Didn't find a member with that name");
        }
        if (!$p_status && $people_rs->count > 1) {
            return $message->reply("I found " . $people_rs->count . " members starting with that");
        }
        if ($p_status eq 'success') {
            $person = $person_or_keyb;
            $self->waiting_on_response->{$message->from->id}{person} = $person;
        }
    }
    if ($person) {
        ## Found em, dump some info
        my $p_data = $person->name . " (" . $person->tier->name . " tier)";
        if (!$person->is_valid) {
            return $message->reply("I found $p_data but they aren't a paid-up member, they last were: " . ($person->valid_until ? $person->valid_until->ymd : 'never'));
        }
        return $message->reply("I found $p_data they are paid up until " . $person->valid_until->ymd);
    }
    return $message->reply("Try /whois <person name>");
}

=head2 induct_member

Create an "allowed" link between a member and a tool.

The "member name" and "tool name" supplied by the original message do
not need to be exact names as in the database. To enable them to be
partial matches, we call L</find_tool> which will either return us the
correct tool object, or an inline keyboard for the user to pick.

After the keyboard has been selected from, we call induct_member again
with the results ($args) and attempt to complete.

=cut

sub induct_member ($self, $text, $message, $args = undef) {
    return unless $self->authorize($message);

    my ($tool, $person, $p_status, $person_or_keyb, $t_status, $tool_or_keyb);
    my $member = $self->member($message);
    return if !$member;
    #                                  /induct James Mastros on Point of Sale
    if (!$args && $text =~ m{^/induct\s(['\w\s]+)\son\s([\w\d\s]+)$}) {
        my ($name, $tool_name) = ($1, $2);

        ($person_or_keyb, undef) = $self->db->resultset('Person')->find_person($name);
        $p_status = $person_or_keyb ? 'success' : undef;
        if (!$p_status) {
            return $message->reply("Didn't find a member with that name");
        }
        ($t_status, $tool_or_keyb) = $self->find_tool($tool_name, 'induct_member');
        if ($p_status eq 'success') {
            $person = $person_or_keyb;
            $self->waiting_on_response->{$message->from->id}{person} = $person;
        }
        if ($t_status eq 'success') {
            $tool = $tool_or_keyb;
            $self->waiting_on_response->{$message->from->id}{tool} = $tool;
        }
    }
    if ($args) {
        ## We've (maybe) figured out which person/tool the user meant?
        ## check callback / waiting data to see if we have both yet
        my $waiting = $self->waiting_on_response->{$message->from->id};
        ## for find_tool / find_person args are induct_member|tool|<name>
        if ($args->[1] eq 'tool') {
            $tool = $self->db->resultset('Tool')->find({name => $args->[2]});
            $waiting->{tool} = $tool;
        } elsif ($args->[1] eq 'person') {
            $person = $self->db->resultset('Person')->find({name => $args->[2]});
            $waiting->{person} = $person;
        }
        $tool ||= $waiting->{tool};
        $person ||= $waiting->{person};
    }
    if ($tool && $person) {
        ## we're done here, actually try and do the induction
        # should we do this check before the find_person loop?
        if (!$member->allowed->find({ tool_id => $tool->id, is_admin => 1})) {
            return $message->reply("You're not allowed to induct people on the " . $tool->name);
        }
        # do this in find_person?
        if (!$person->is_valid) {
            return $message->reply("I found " . $person->name ." but they aren't a paid-up member");
        }
        my $p_allowed = $person->find_or_create_related('allowed', { tool_id => $tool->id, is_admin => 0 });
        $p_allowed->discard_changes();
        # send a confirmation email or telegram msg
        if ($p_allowed->pending_acceptance) {
            $self->confirm_induction($message, $p_allowed);
            return $message->reply("Ok, inducted " . $person->name ." on " . $tool->name . ' (they should have a confirmation message)');
        } else {
            print "No need to confirm, already accepted\n";
            return $message->reply('It looks like ' . $person->name . ' is already inducted on that and accepted it');
        }
    }

    ## repeat this for person when we've done find_person:
    if ($t_status eq 'keyboard') {
        ## didnt find an exact match, user gets to pick:
        my $waiting = $self->waiting_on_response->{$message->from->id} || {};
        $waiting->{action} = 'induct_member';
        $waiting->{type} = 'tool';
        $waiting->{text} = $text;
        $self->waiting_on_response->{$message->from->id} = $waiting;

        return $message->_brain->sendMessage(
            {
                chat_id => $message->chat->id,
                text    => "No exact match for tool, pick one:",
                reply_markup => Telegram::Bot::Object::InlineKeyboardMarkup->new(
                    {
                        inline_keyboard => $tool_or_keyb,
                    })
            });
    }
    return $message->reply("Try /induct <person name> on <tool name> or /help");
}

=head inductees

Who is inducted on this thing?

=cut

sub inducted_on ($self, $text, $message, $args = undef) {
    return unless $self->authorize($message);

    my ($tool, $t_status, $tool_or_keyb);
    my $waiting = $self->waiting_on_response->{$message->from->id} || {};
    if (!$args && $text =~ m{^/inducted_on\s([\w\s\d]+)$}) {
        my $tool_name = $1;
        ($t_status, $tool_or_keyb) = $self->find_tool($tool_name, 'inducted_on',
            {
                prefetch=> {'allowed_people' => 'person'},
            });
        if ($t_status eq 'success') {
            $tool = $tool_or_keyb;
        }
    }
    if ($args) {
        if ($args->[1] eq 'tool') {
            $tool = $self->db->resultset('Tool')->find({name => $args->[2]});
            $waiting->{tool} = $tool;
        }
        $tool ||= $waiting->{tool};
    }
    if ($tool) {
        my $str = join("\n", map {
            (
             $_->person->is_valid ?
             ($_->person->name . ($_->is_admin ? ' (inductor)' : ''))
             : ())
                       }
            ($tool->allowed_people->search(
                 {}, {
                     order_by => [
                         { '-desc' => 'me.is_admin'},
                         {'-asc' => 'person.name'}],
                     prefetch => 'person'} )
            )
        );
        if (!$str) {
            $str = 'Nobody !?';
        }
        return $message->reply("Inducted on " . $tool->name . ":\n$str");
    }

    if ($t_status eq 'keyboard') {
        ## didnt find an exact match, user gets to pick:
        $waiting->{action} = 'inducted_on';
        $waiting->{type} = 'tool';
        $waiting->{text} = $text;
        $self->waiting_on_response->{$message->from->id} = $waiting;

        return $message->_brain->sendMessage(
            {
                chat_id => $message->chat->id,
                text    => "No exact match for tool, pick one:",
                reply_markup => Telegram::Bot::Object::InlineKeyboardMarkup->new(
                    {
                        inline_keyboard => $tool_or_keyb,
                    })
            });
    }
}

=head2 inductions

What can this person use?

=cut

sub inductions ($self, $text, $message) {
    return unless my $member = $self->authorize($message);

    if ($text =~ m{^/inductions(?:\s(['\w\s]+))?$}) {
        my $name = $1;
        if (!$name) {
            $name = $member->name;
        }
        my ($person, $p_rs) = $self->db->resultset('Person')->find_person($name,
            { prefetch => {'allowed' => 'tool'}});
        if (!$person) {
            return $message->reply("I can't find a person named $name");
        }

        my $str = join("\n", map { $_->tool->name . ($_->pending ? ' (pending)' : ''). ($_->is_admin ? ' (inductor)' : '') } ($person->allowed));
        if (!$str) {
            $str = 'Nothing !?';
        }
        return $message->reply("Inductions for " . $person->name . ":\n$str");        
    }
}

=head2 make_inductor

=cut

sub make_inductor ($self, $text, $message, $args = undef) {
    return unless $self->authorize($message);

    my ($tool, $person, $p_status, $person_or_keyb, $t_status, $tool_or_keyb);

    # Requestor is a valid member of the makerspace (paid up)
    my $member = $self->member($message);
    return if !$member;

    # Something's very wrong if we have no Door .. 
    my $door = $self->db->resultset('Tool')->find({ name => 'The Door' });
    return if !$door;

    ## Must be an admin, or existing inductor
    my $allowed = $member->allowed->find({ tool_id => $door->id });
    return if !$allowed;
    # if (!$allowed->is_admin) {
    #     return $message->reply("You're not allowed to do that");
    # }

    if (!$args && $text =~ m{^/make_inductor\s(['\w\s]+)\son\s([\w\s\d]+)$}) {
        my ($name, $tool_name) = ($1, $2);

        # Find the target person:
        ($person_or_keyb, undef) = $self->db->resultset('Person')->find_person($name);
        $p_status = $person_or_keyb ? 'success' : undef;
        if (!$p_status) {
            return $message->reply("Didn't find a member with that name");
        }
        # Find the tool (or return a status which will display buttons)
        ($t_status, $tool_or_keyb) = $self->find_tool($tool_name, 'make_inductor');
        if ($p_status eq 'success') {
            $person = $person_or_keyb;
            $self->waiting_on_response->{$message->from->id}{person} = $person;
        }
        if ($t_status eq 'success') {
            $tool = $tool_or_keyb;
            $self->waiting_on_response->{$message->from->id}{tool} = $tool;
        }

    }
    # args is the response from a button display, extract and set tool/person
    if ($args) {
        ## We've (maybe) figured out which person/tool the user meant?
        ## check callback / waiting data to see if we have both yet
        my $waiting = $self->waiting_on_response->{$message->from->id};

        ## for find_tool / find_person args are induct_member|tool|<name>
        if ($args->[1] eq 'tool') {
            $tool = $self->db->resultset('Tool')->find({name => $args->[2]});
            $waiting->{tool} = $tool;
        } elsif ($args->[1] eq 'person') {
            $person = $self->db->resultset('Person')->find({name => $args->[2]});
            $waiting->{person} = $person;
        }
        $tool ||= $waiting->{tool};
        $person ||= $waiting->{person};
    }
    if ($tool && $person) {
        ## got all the details, actually try and do the induction
        if (!$person->is_valid) {
            return $message->reply("I found " . $person->name ." but they aren't a paid-up member");
        }
        my $member_inductor = $member->allowed->find({ tool_id => $tool->id });
        if (!$allowed->is_admin && ($member_inductor && !$member_inductor->is_admin)) {
            # member is not a director, and not an inductor on the tool
            return $message->reply("You're not allowed to do that");
        }
        my $inducted = $person->find_or_create_related('allowed', { tool_id => $tool->id, is_admin => 1 });
        $inducted->update({ is_admin => 1 });
        return $message->reply("Ok, made " . $person->name ." an inductor on " . $tool->name);
    }

    # we didn't find an exact tool, display buttons to pick from instead
    # (the buttons callback will re-run this whole method with $args set)
    if ($t_status eq 'keyboard') {
        my $waiting = $self->waiting_on_response->{$message->from->id} || {};
        $waiting->{action} = 'make_inductor';
        $waiting->{type} = 'tool';
        $waiting->{text} = 'text';
        $self->waiting_on_response->{$message->from->id} = $waiting;

        return $message->_brain->sendMessage(
            {
                chat_id => $message->chat->id,
                text    => "No exact match for tool, pick one:",
                reply_markup => Telegram::Bot::Object::InlineKeyboardMarkup->new(
                    {
                        inline_keyboard => $tool_or_keyb,
                    })
            });
    }
    return $message->reply("Try /make_inductor <person name> on <tool name> or /help");
}

=head2 balance

Amount this member has in their makerspace account.

=cut

sub balance ($self, $text, $message) {
    my $member = $self->authorize($message, 'private');
    return if !$member;

    my $balance = $member->balance_p / 100;
    return $message->reply("Your balance: " . sprintf("%.2f", $balance));
}

=head2 prices

=cut

sub prices ($self, $text, $message) {
    return unless $self->authorize($message, 'invalid_ok');

    my $ua = LWP::UserAgent->new();
    my $resp = $ua->get($self->base_url . "assets/json/prices.json");
    if (!$resp->is_success) {
        print STDERR "Failed fetching prices ", $resp->status_line, "\n";
        return $message->reply("Missing price list, poke the directors?");
    }
    my $prices = decode_json($resp->decoded_content)->{prices};
    
    my $reply = '`';
    foreach my $p (keys %{ $prices }) {
        $reply .= sprintf("%-25s £%.2fp\n", $p, $prices->{$p}/100);
    }
    $reply .= '`';

    return $message->_brain->sendMessage({
        chat_id => $message->chat->id,
        text => $reply,
        parse_mode => 'MarkdownV2',
    });
}

=head2 pay

Members to pay for items bought from the space, from their balance.

Display "keyboard" of products, keep doing so, collecting products
picked + total value, until "review" is chosen, then display chosen
items + total to finish.

=cut

sub pay ($self, $text, $message, $args = undef) {
#    my $member = $self->authorize($message, 'invalid_ok');
    my $member = $self->authorize($message, 'private');
    if (!$member) {
        return;
    }

    # current prices
    my $ua = LWP::UserAgent->new();
    my $resp = $ua->get($self->base_url . "assets/json/prices.json");
    if (!$resp->is_success) {
        print STDERR "Failed fetching prices ", $resp->status_line, "\n";
        return $message->reply("Missing price list, poke the directors?");
    }
    my $prices = decode_json($resp->decoded_content)->{prices};
    my $total = 0;
    my @products = ();
    # been around once, collect the data and add the new choice
    if ($args) {
        my $waiting = $self->waiting_on_response->{$message->from->id};
        if (exists $prices->{$args->[1]}) {
            $total = $waiting->{total} + $prices->{$args->[1]};
            @products = (@{ $waiting->{products} }, $args->[1]);
            $self->waiting_on_response->{$message->from->id}{total} = $total;
            $self->waiting_on_response->{$message->from->id}{products} = \@products;
            # its a callbackquery
            $message = $message->message;
        } elsif ($args->[1] eq 'cancel') {
            ## ended selections - cancel whole thing
            delete $self->waiting_on_response->{$message->from->id};
            return $message->answer('Canceled');
        } elsif ($args->[1] eq 'pay') {
            ## ended selections create transaction
            delete $self->waiting_on_response->{$message->from->id};
            my ($status, $msg) = $member->add_debit($waiting->{total},
                                                    join(",",@{$waiting->{products}}));
            return $message->answer($msg);
        }
    } else {
        $self->waiting_on_response->{$message->from->id} = {
            action => 'pay',
            total => $total,
            products => \@products,
        };
    }
    ## keyboard of prices
    #    my $inline = $self->payment_keyboard($prices);
    my $keyboard_prices = { map { sprintf("%s - %.2f", $_, $prices->{$_}/100) => $_ } (keys %$prices)};
    my $inline = $self->generic_keyboard('pay', $keyboard_prices, 2, ['Pay', 'Cancel']);
    return $message->_brain->sendMessage({
        chat_id => $message->chat->id,
        text    => "Current selection: ". join(", ", @products) . sprintf("\nTotal: %.2f", $total /100),
        reply_markup => Telegram::Bot::Object::InlineKeyboardMarkup->new({
            inline_keyboard => $inline,
        })
    });
}



=head1 generic_keyboard

Send a "keyboard" of buttons to the user, so they can make one choice.

Arguments:

    "method" (string) = name of the method for the callback to pass data to
    "values" (hashref) = key/value pairs, button text as the key, callback data as the value
    "colcount" (integer) = number of columns of buttons on the keyboard
    "endbuttons" (arrayref) = names for non-data buttons, lc versions will be used for the callback
    "order" (arrayref, optional) = list of keys from "values", in the order they should be displayed.  Results are ill-defined if not all keys in the "values" hashref are in the "order" hashref.  If not provided, the items will be alphabetized.

=cut

# generic_keyboard('pay', {'foo 0.40' => 'foo', 'bar 1.00' => 'bar'}, 2, ['Pay', 'Cancel'])
sub generic_keyboard ($self, $method, $values, $colcount, $endbuttons, $order=undef) {
    my @items;
    if (defined $order) {
        @items = @$order;
    } else {
        @items = sort keys %$values;
    }
    my @inline_keyb = ([]);

    # print STDERR Data::Dumper::Dumper($values);
    print STDERR Data::Dumper::Dumper(\@items);
    for my $item (@items) {
#        print STDERR "generic_keyboard item=$item, method=$method, data=$values->{$item}";
        push @{$inline_keyb[-1]}, Telegram::Bot::Object::InlineKeyboardButton->new(
            {
                text => $item,
                callback_data => "$method|$values->{$item}",
            }
        );
        # start new row.
        if (@{$inline_keyb[-1]} == $colcount) {
            push @inline_keyb, [];
        }
    }

    # endbuttons always gets it's own row.
    push @inline_keyb, [ map { 
        Telegram::Bot::Object::InlineKeyboardButton->new(
            {
                text => $_,
                callback_data => sprintf("$method|%s", lc($_)),
            }) } (@$endbuttons)
        ];

    return \@inline_keyb;
}

sub resolve_callback ($self, $callback) {
    my $waiting = $self->waiting_on_response->{$callback->from->id};
    # Remove keyboard from message now that we're dealing with it!
    my $msg = $callback->_brain->editMessageText({'chat_id' => $callback->message->chat->id, 'message_id' => $callback->message->message_id, text => $callback->message->text . ' (done and keyboard removed)', reply_markup => Telegram::Bot::Object::InlineKeyboardMarkup->new({inline_keyboard => []}) });
    if (!$msg) {
        die "Failed to remove inline keyboard\n";
    }

    ## This shouldnt happen once the keyboard is gone .. (it might if someone else clicks who isnt the expected user!)
    if (!$waiting) {
        $callback->_brain->sendMessage({'chat_id' => $callback->message->chat->id, text => 'Confusion in the bot-brain, what are you responding to?'});
        return $callback->_brain->answerCallbackQuery({callback_query_id => $callback->id, text => 'Arghhh!', cache_time => 36000});
    }
    my @args = split(/\|/, $callback->data);
    print STDERR Data::Dumper::Dumper(\@args);
    print STDERR $self->can("$args[0]") ? "I can\n" : "I can't\n";
    if ($waiting->{action} eq $args[0]) {
        if (!exists $waiting->{text}) {
            warn 'Missing msg text in waiting for ' . $args[0];
        }
        my $msg_text = $waiting->{text} || '';
        my @w_args = @{ $waiting->{args} || [] };
        my $method = $args[0];
        return $self->$method($msg_text, $callback, @w_args, \@args);
    }
    return $callback->answer('Confused!');
}

# We'll only get these in groups where the Bot is an admin that has
# invite permissions.
# And the link is set to "requires admin approval!"
sub respond_to_join_request ($self, $chatjoinrequest) {
    # Approve if is currently a valid member
    # Decline otherwise
    # IIRC this doesn't ban people, mebbe should implement some sorta
    # timeout if they retry?

    my $member = $self->member($chatjoinrequest);
    if (!$member) {
        # Not a member, or not identified
        $chatjoinrequest->_brain->sendMessage({
            chat_id => $chatjoinrequest->user_chat_id,
            text    => $chatjoinrequest->chat->title . " is for paid-up members of the Swindon Makerspace only. If you are a paid-up member, PM me /identify <email address>, to prove who you are."
        });
        print STDERR "Declining: ", $chatjoinrequest->from->id, " (Not member)\n";
        return $chatjoinrequest->decline();
    }
    if(!$member->is_valid) {
        $chatjoinrequest->_brain->sendMessage({
            chat_id => $chatjoinrequest->user_chat_id,
            text    => $chatjoinrequest->chat->title . " is for paid-up members of the Swindon Makerspace only. If you want to rejoin PM me /bankinfo to get our bank details"
        }); 
        print STDERR "Declining: ", $chatjoinrequest->from->id, " (Not valid)\n";
        return $chatjoinrequest->decline();
    }

    print STDERR "Approving: ", $chatjoinrequest->from->id, "\n";
    $chatjoinrequest->approve();
}

# Message with no "text", "from" is a new chat member (if it has new_chat_members)
sub check_if_ban ($self, $message) {
    # Only do this check if we're an admin:
    if (!exists $self->chat_rights->{$message->chat->id}) {
        $self->chat_rights->{$message->chat->id} = $message->_brain->getChatMember($message->chat->id, $self->me->id);
        #print STDERR "Chat rights :", Dumper($self->chat_rights);
    }
    if (exists $self->chat_rights->{$message->chat->id} &&
        $self->chat_rights->{$message->chat->id}->status eq 'administrator') {
        my $member = $self->member($message);
        if (!$member) {
            # Not a member, or not identified
            $message->_brain->banChatMember({
                chat_id => $message->chat->id,
                user_id => $message->from->id,
                until_date => time()+60,
                                            });
            return $message->reply(
                $message->chat->title . " is for paid-up members of the Swindon Makerspace only. If you are a paid-up member, PM me /identify <email address>, to prove who you are."
                );
            print STDERR "Join from: ", $message->from->username, " (Not member)\n";
        }
        if(!$member->is_valid) {
            $message->_brain->banChatMember({
                chat_id => $message->chat->id,
                user_id => $message->from->id,
                until_date => time()+60,
                                            });
            return $message->reply(
                $message->chat->title . " is for paid-up members of the Swindon Makerspace only. If you want to rejoin PM me /bankinfo to get our bank details"
                );
            print STDERR "Join from: ", $message->from->username, " (Not valid)\n";
        }
    }
    print STDERR "Joined: ", $message->from->username, "\n";
}

sub confirm_induction ($self, $message, $allowed, $args = undef) {
    # if inductee has identified with telegram? if so send an inline keyboard
    if (!$args) {
        print "No args\n";
        # In-chat msg stuff is a tad buggy (ours that is)
        # my $in_chat = $allowed->person->telegram_chatid
        #     ? $message->_brain->getChatMember($message->chat->id, $allowed->person->telegram_chatid)
        #     : undef;
        # if ($message->chat->type ne 'private'
        #     && $in_chat
        #     && $in_chat->status =~ /^creator|adminstrator|member|restricted$/) {
        #     ## Not a direct message and target is in the chat..
        #     print "Found person in this chat\n";
        #     $self->waiting_on_response()->{$allowed->person->telegram_chatid} = {
        #         'action' => 'confirm_induction',
        #         'text' => $message->text,
        #             'args' => [ $allowed ],
        #     };

        #     return $message->_brain->sendMessage({
        #         chat_id => $message->chat->id,
        #         text    => '@' . $allowed->person->telegram_username . ' Please confirm that you understand the safety induction for using the ' . $allowed->tool->name . ' and take responsibility for your actions while using it.',
        #         reply_markup => Telegram::Bot::Object::InlineKeyboardMarkup->new({
        #             inline_keyboard => [[
        #                 Telegram::Bot::Object::InlineKeyboardButton->new({
        #                     text => 'I confirm',
        #                     callback_data => "confirm_induction|Yes",
        #                 }),
        #                 Telegram::Bot::Object::InlineKeyboardButton->new({
        #                     text => 'I have not been inducted',
        #                     callback_data => "confirm_induction|No",
        #                 }),
        #             ]]
        #         })
        #     });
        # } else {
            # send an email
            print "Didn't find them in this chat!?\n";
            my $url = $self->base_url . 'send_induction_acceptance?tool=' . $allowed->tool->id . '&person='.$allowed->person->id;
            print "Send email using: $url\n";
            my $ua = LWP::UserAgent->new();
            my $resp = $ua->get($url);
            if (!$resp->is_success) {
                print STDERR "Failed: ", $resp->status_line, " ", $resp->content, "\n";
                $message->reply("I attempted to send an email but.. that didn't work, go poke Jess R about that");
            } else {
                $message->reply('Email sent to ' . $allowed->person->name);
            }
        # }
    } else {
        # args (result of a telegram confirmation)
        delete $self->waiting_on_response->{$message->from->id};
        if ($args->[1] eq 'Yes') {
            $allowed->update({ pending_acceptance => 'false', accepted_on => DateTime->now() });
            return $message->answer('Ok, confirmed');
        } else {
            $allowed->delete();
            return $message->answer('Ok, induction deleted');
        }
    }
}

1;
