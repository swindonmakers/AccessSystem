package AccessSystem::TelegramBot;

use feature 'signatures';

use Mojo::Base 'Telegram::Bot::Brain';
use Telegram::Bot::Object::InlineKeyboardMarkup;
use Telegram::Bot::Object::InlineKeyboardButton;
use Config::General;
use LWP::Simple;
use LWP::UserAgent;
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

sub find_tool ($self, $name) {
    my $tools_rs = $self->db->resultset('Tool')->search_rs({name => $name});
    if ($tools_rs->count == 1) {
        return ('success', $tools_rs->first);
    }
    $tools_rs = $self->db->resultset('Tool')->search_rs({ name => { '-ilike' => "${name}%"}});
    if ($tools_rs->count == 1) {
        return ('success', $tools_rs->first);
    }
    ## found more than one?
    if ($tools_rs->count > 1) {
        
    } else {
        return ('fail', []);
    }

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

Create an "allowed" link between a member and a tool

=cut

sub induct_member ($self, $message) {
    return unless $self->authorize($message);

    #                        /induct James Mastros on Point of Sale
    if ($message->text =~ m{^/induct\s([\w\s]+)\son\s([\w\d\s]+)$}) {
        my ($name, $tool_name) = ($1, $2);
        my $member = $self->member($message);
        my ($status, $result) = $self->find_tool($tool_name);
        if (!$tool) {
            return $message->reply("I can't find a tool named $tool_name");
        }
        if ($tool && $member) {
            if (!$member->allowed->find({ tool_id => $tool->id, is_admin => 1})) {
                return $message->reply("You're not allowed to induct people on the $tool_name");
            }
            my $person = $self->db->resultset('Person')->find({name => $name});
            if (!$person) {
                return $message->reply("I can't find a person named $name");
            }
            if (!$person->is_valid) {
                return $message->reply("I found $name but they aren't a paid-up member");
            }
            $person->create_related('allowed', { tool_id => $tool->id });
            return $message->reply("Ok, inducted $name on $tool_name");
        }   
    }
    return $message->reply("Try /induct <person name> on <tool name> or /help");
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
    my $keyboard_prices = [ map { sprintf("%s - %2.f", $_, $prices->{$_}) => $_ } (keys %$prices)]
    my $inline = $self->generic_keyboard($keyboard_prices, , 2, ['Pay', 'Cancel']);
    return $message->_brain->sendMessage({
        chat_id => $message->chat->id,
        text    => "Current selection: ". join(", ", @products) . sprintf("\nTotal: %.2f", $total /100),
        reply_markup => Telegram::Bot::Object::InlineKeyboardMarkup->new({
            inline_keyboard => $inline,
        })
    });
}

sub payment_keyboard ($self, $prices) {
    my @products = sort keys %$prices;
    my @inline_keyb = ();
    for (my $i = 0; $i <= $#products; $i += 2) {
        push @inline_keyb, [
            Telegram::Bot::Object::InlineKeyboardButton->new({
                text => $products[$i],
                callback_data => "pay|$products[$i]",
            }),
            ($i+1 <= $#products ?
             Telegram::Bot::Object::InlineKeyboardButton->new({
                 text => $products[$i+1],
                 callback_data => "pay|$products[$i+1]",
             })
             : ()),
        ];
    }
    push @inline_keyb, [
        Telegram::Bot::Object::InlineKeyboardButton->new({
            text => 'Pay',
            callback_data => "pay|paying",
        }),
        Telegram::Bot::Object::InlineKeyboardButton->new({
            text => 'Cancel',
            callback_data => "pay|cancel",
        }),
    ];

    return \@inline_keyb;
}

# generic_keyboard('pay', {'foo 0.40' => 'foo', 'bar 1.00' => 'bar'}, 2, ['Pay', 'Cancel'])
sub generic_keyboard ($self, $method, $values, $colcount, $endbuttons) {
    my @items = sort keys %$values;
    my @inline_keyb = ();
    
    for (my $i = 0; $i <= $#items; $i += $colcount) {
        push @inline_keyb, [ map {
            Telegram::Bot::Object::InlineKeyboardButton->new(
                {
                    text => $items[$i+$_],
                    callback_data => $values{$items[$i+$_]},
                }) } (0..$colcount-1)
            ];
    }
    push @inline_keyb, [ map { 
        Telegram::Bot::Object::InlineKeyboardButton->new(
            {
                text => $_,
                callback_data => sprintf("$method|%s", $lc($_)),
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
