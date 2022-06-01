package AccessSystem::TelegramBot;
no warnings 'experimental';
use feature 'signatures';

use Mojo::Base 'Telegram::Bot::Brain';
use Telegram::Bot::Object::InlineKeyboardMarkup;
use Telegram::Bot::Object::InlineKeyboardButton;
use Config::General;
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
        $self->_mainconfig({Config::General->new("$ENV{BOT_HOME}/accesssystem_api.conf")->getall()});
    }

    if (wantarray) {
        return %{$self->_mainconfig};
    } else {
        return $self->_mainconfig;
    }
};

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

sub find_tool ($self, $name, $method) {
    my $tools_rs = $self->db->resultset('Tool')->search_rs({name => $name});
    if ($tools_rs->count == 1) {
        return ('success', $tools_rs->first);
    }
    $tools_rs = $self->db->resultset('Tool')->search_rs({ name => { '-like' => "%${name}%"}});
    if ($tools_rs->count == 1) {
        return ('success', $tools_rs->first);
    }

    $tools_rs = $self->db->resultset('Tool');

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
    for (@possibles) {
        my $text = "$_->{name} -- $_->{dist}";
        $keyboard_items->{$text} = "tool|$_->{name}";
        push @$keyboard_order, $text;
    }

    return ('keyboard', $self->generic_keyboard($method, $keyboard_items, 2, ['Cancel'], $keyboard_order));

}

sub read_message ($self, $message) {
    my %methods = (
        memberstats   => qr{^/memberstats},
        identify      => qr{^/identify},
        doorcode      => qr{^/doorcode},
        bankinfo      => qr{^/bankinfo},
        tools         => qr{^/tools},
        add_tool      => qr{^/add_tool},
        induct_member => qr{^/induct\b},
        inducted_on   => qr{^/inducted_on\b},
        inductions    => qr{^/inductions\b},
        balance       => qr{^/balance},
        prices        => qr{^/prices},
        pay           => qr{^/pay},
        help          => qr{^/(help|start)},
        );

    if (ref $message eq 'Telegram::Bot::Object::Message') {
        print STDERR $message->text, "\n";
        foreach my $method (keys %methods) {
            if ($message->text =~ /$methods{$method}/) {
                return $self->$method($message);
            }
        }
    } elsif (ref $message eq 'Telegram::Bot::Object::CallbackQuery') {
        # print STDERR "Calling resolve\n";
        return $self->resolve_callback($message);
    }
    if ($message->text =~ m{^/}) {
        $message->reply(qq<I don't know that command, sorry.>);
    }
}

sub bankinfo ($self, $message) {
    return unless $self->authorize($message, 'invalid_ok');

    my $member = $self->member($message);

    my $dues = sprintf('%.2f', $member->dues / 100);
    my $bank_ref = $member->bank_ref;

    my $text = <<"END";
Monthly fee: $dues/month</li>
To: Swindon Makerspace
Bank: Barclays
Sort Code: 20-84-58
Account: 83789160
Ref: $bank_ref
END

    $message->reply($text);
}

sub memberstats ($self, $message) {
    my $data = $self->db->resultset('Person')->membership_stats;
    my $msg_text = "
Current members: " . ($data->{valid_members}{count} || 0) . " - (" . join(', ', map { "$_: " . ($data->{valid_members}{$_} || 0) } (qw/full concession otherspace adult child/)) . "),
Ex members: " . ($data->{ex_members}{count} || 0) . " - (" . join(', ', map { "$_: " . ($data->{ex_members}{$_} || 0) } (qw/full concession otherspace/)) . "),
Overdue members: " . ($data->{overdue_members}{count} || 0) ." - (" . join(', ', map { "$_: " . ($data->{overdue_members}{$_} || 0) } (qw/full concession otherspace/)) . "),
Left this month: " . ($data->{recent_expired}{count} || 0) ." - (" . join(', ', map { "$_: " . ($data->{recent_expired}{$_} || 0) } (qw/full concession otherspace/)) . ")";

    $message->reply($msg_text);

    return;
}

sub identify ($self, $message) {
    if($message->text =~ m{^/identify ([ -~]+\@[ -~]+)$}) {
        my $email = $1;
        # print STDERR "Email: $email\n";
        my $members = $self->db->resultset('Person')->search_rs({
            '-and' => [
                end_date => undef,
                \ ['LOWER(email) = ?', lc($email)],
                ]});
        if($members->count == 1) {
            my $url = 'https://inside.swindon-makerspace.org/confirm_telegram?chatid=' . $message->from->id . '&email=' . lc($email) . '&username=' . $message->from->username;
            # print STDERR "Calling: $url\n";
            my $ua = LWP::UserAgent->new();
            my $resp = $ua->get($url);
            if (!$resp->is_success) {
                print STDERR "Failed: ", $resp->status_line, " ", $resp->content, "\n";

            }
            $message->reply("You should receive an email to confirm your membership/telegram mashup");
        } else {
            $message->reply("I can't find a member with that email address, try again or check https://inside.swindon-makerspace.org/profile");
        }
    } else {
        $message->reply("That didn't look like an email address, try again?");
    }
}

sub doorcode ($self, $message) {
    return unless $self->authorize($message);

    my $doorcode = $self->mainconfig->{code_a};

    $message->reply("Use $doorcode on the keypad by either external door of BSS House to get in at night.");
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

sub add_tool ($self, $message, $args = undef) {
    return unless $self->authorize($message);

    if (!$args) {
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

=head2 induct_member

Create an "allowed" link between a member and a tool.

The "member name" and "tool name" supplied by the original message do
not need to be exact names as in the database. To enable them to be
partial matches, we call L</find_tool> which will either return us the
correct tool object, or an inline keyboard for the user to pick.

After the keyboard has been selected from, we call induct_member again
with the results ($args) and attempt to complete.

=cut

sub induct_member ($self, $message, $args = undef) {
    return unless $self->authorize($message);

    #                        /induct James Mastros on Point of Sale
    my ($tool, $person, $p_status, $person_or_keyb, $t_status, $tool_or_keyb);
    my $member = $self->member($message);
    return if !$member;
    ## callback answers only display as brief pops or (with show_alert
    ## => 1) as modal confirm boxes, kinda ugly - need a method for
    ## "use $callback->message->reply and then send empty answer.
    my $reply = ref $message =~ /Callback/ ? 'answer' : 'reply';
    print STDERR ref $message;
    print STDERR " $reply\n";
    if (!$args && $message->text =~ m{^/induct\s([\w\s]+)\son\s([\w\d\s]+)$}) {
        my ($name, $tool_name) = ($1, $2);

        ($p_status, $person_or_keyb) = ('success', $self->db->resultset('Person')->find({name => $name}));
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
            return $message->$reply("You're not allowed to induct people on the " . $tool->name);
        }
        # do this in find_person?
        if (!$person->is_valid) {
            return $message->$reply("I found " . $person->name ." but they aren't a paid-up member");
        }
        $person->find_or_create_related('allowed', { tool_id => $tool->id, is_admin => 0 });
        return $message->reply("Ok, inducted " . $person->name ." on " . $tool->name);
    }

    ## repeat this for person when we've done find_person:
    if ($t_status eq 'keyboard') {
        ## didnt find an exact match, user gets to pick:
        my $waiting = $self->waiting_on_response->{$message->from->id} || {};
        $waiting->{action} = 'induct_member';
        $waiting->{type} = 'tool';
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
    return $message->$reply("Try /induct <person name> on <tool name> or /help");
}

=head inductees

Who is inducted on this thing?

=cut

sub inducted_on ($self, $message) {
    return unless $self->authorize($message);

    if ($message->text =~ m{^/inducted_on\s([\w\s\d]+)$}) {
        my $tool_name = $1;
        my $tool = $self->db->resultset('Tool')->find(
            {
                name => $tool_name,
            },
            {
                prefetch=> {'allowed_people' => 'person'},
            });
        if (!$tool) {
            return $message->reply("I can't find a tool named $tool_name");
        }
        my $str = join("\n", map { $_->person->name } ($tool->allowed_people));
        if (!$str) {
            $str = 'Nobody !?';
        }
        return $message->reply("Inducted on $tool_name:\n$str");
    }
}

=head2 inductions

What can this person use?

=cut

sub inductions ($self, $message) {
    return unless $self->authorize($message);

    if ($message->text =~ m{^/inductions\s([\w\s]+)$}) {
        my $name = $1;
        my $person = $self->db->resultset('Person')->find(
            { name => $name },
            { prefetch => {'allowed' => 'tool'}});
        if (!$person) {
            return $message->reply("I can't find a person named $name");
        }

        my $str = join("\n", map { $_->tool->name } ($person->allowed));
        if (!$str) {
            $str = 'Nothing !?';
        }
        return $message->reply("Inductions for $name:\n$str");        
    }
}

=head2 balance

Amount this member has in their makerspace account.

=cut

sub balance ($self, $message) {
    my $member = $self->authorize($message, 'private');
    return if !$member;

    my $balance = $member->balance_p / 100;
    return $message->reply("Your balance: " . sprintf("%.2f", $balance));
}

=head2 prices

=cut

sub prices ($self, $message) {
    return unless $self->authorize($message, 'invalid_ok');

    my $ua = LWP::UserAgent->new();
    my $resp = $ua->get("https://inside.swindon-makerspace.org/assets/json/prices.json");
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

sub pay ($self, $message, $args = undef) {
#    my $member = $self->authorize($message, 'invalid_ok');
    my $member = $self->authorize($message, 'private');
    if (!$member) {
        return;
    }

    # current prices
    my $ua = LWP::UserAgent->new();
    my $resp = $ua->get("https://inside.swindon-makerspace.org/assets/json/prices.json");
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
    if (!$waiting) {
        $callback->_brain->sendMessage({'chat_id' => $callback->message->chat->id, text => 'Confusion in the bot-brain, what are you responding to?'});
        return $callback->_brain->answerCallbackQuery({callback_query_id => $callback->id, text => 'Arghhh!', cache_time => 36000});
    }
    my @args = split(/\|/, $callback->data);
    print STDERR Data::Dumper::Dumper(\@args);
    print STDERR $self->can('$args[0]') ? "I can\n" : "I can't\n";
    if ($waiting->{action} eq $args[0]) {
        # delete $self->waiting_on_response->{$callback->from->id};
        my $method = $args[0];
        return $self->$method($callback, \@args);
    }
    return $callback->answer('Confused!');
}


sub help {
    my ($self, $message) = @_;
    if ($message->text =~ m!^/(help|start)!) {
        $message->reply(join("\n", "I know /identify <your email address>",
                             "/memberstats", "/doorcode", "/tools", "/add_tool <tool>", "/induct <name> on <tool>", "/inducted_on <tool>", "/inductions <member name>", "/balance", "/prices", "/pay"));
    }
}

1;
