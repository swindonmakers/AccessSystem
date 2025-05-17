package AccessSystem::API::Controller::Root;
use Moose;
use Time::HiRes 'time';
use namespace::autoclean;
use AccessSystem::Form::Person;
use AccessSystem::Emailer;
use DateTime;
use Data::Dumper;
use LWP::UserAgent;
use MIME::Base64;
use JSON;
use Data::GUID;

BEGIN { extends 'Catalyst::Controller' }

has emailer => (
    is => 'ro',
    default => sub { AccessSystem::Emailer->new()} ,
    );

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=encoding utf-8

=head1 NAME

AccessSystem::API::Controller::Root - Root Controller for AccessSystem::API

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=cut

sub auto {
    my ($self, $c) = @_;
    $ENV{CATALYST_HOME} ||= $c->stash->{home};
}

=head2 index

The root page (/)

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    # Hello World
    $c->response->body( $c->welcome_message );
}

=head2 default

Standard 404 error page

=cut

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

# insert into tools (id, name, assigned_ip) values ('D1CAE50C-0C2C-11E7-84F0-84242E34E104', 'oneall_login_callback', '192.168.1.70');

sub oneall_login_callback : Path('/oneall_login_callback') {
    my ($self, $c) = @_;

    my $conn_token = $c->req->body_params->{connection_token};
    if($conn_token) {
        $c->log->debug("oneall token: $conn_token");
        my $res = $self->verify_token($conn_token, $c->config->{OneAll});
        if(!$res) {
            return $c->res->redirect($c->uri_for('login'));
        }
        my $user_token = $res->{user}{user_token};
        my @emails = map { $_->{value} } @{ $res->{user}{identity}{emails} };

        my $person = $c->model('AccessDB::Person')->search(
            [
             'login_tokens.login_token' => $user_token,
             'me.email' => { '-in' => \@emails },
             'me.google_id' => { '-in' => \@emails },
            ],
            {
                prefetch => ['login_tokens','usage', 'allowed','payments'],
            }
            );
        if($person->count > 1) {
            $person = $person->search({ parent_id => undef });
        }
        if(!$person->count || $person->count > 1) {
            $c->session->{message} = "Failed to match login against existing Makerspace member, ask an admin to check the message log if this is incorrect (tried to match email: $emails[0] )";

            $c->model('AccessDB::MessageLog')->create({
                tool_id => 'D1CAE50C-0C2C-11E7-84F0-84242E34E104',
                message => "Login attempt failed from $emails[0] ($res->{user}{identity}{accounts}[0]{username})",
                from_ip => '192.168.1.70',
                                                      });
            $c->stash->{template} = 'login_fail.tt';
            return;
        }
        $person = $person->first;
        if(!$person->login_tokens->count) {
            $person->login_tokens->create({ login_token => $user_token });
        }
        $c->model('AccessDB::MessageLog')->create({
            tool_id => 'D1CAE50C-0C2C-11E7-84F0-84242E34E104',
            message => "Login attempt succeeded from $emails[0] ($res->{user}{identity}{preferredUsername})",
            from_ip => '192.168.1.70',
        });
        $c->set_authen_cookie( value => { person_id => $person->id },
                               expires => '+3M'
        );

        $c->res->redirect($c->uri_for('profile'));
    }
}

sub login : Path('/login') {
    my ($self, $c) = @_;

    $c->stash(template => 'login.tt');
}

sub logout : Path('/logout') {
    my ($self, $c) = @_;

    $c->unset_authen_cookie();

    return $c->res->redirect($c->uri_for('login'));
}

sub base :Chained('/') :PathPart('') :CaptureArgs(0) {
}

=head2 logged_in

Base path for all pages requiring a member to be logged in. Members
with an end_date set are confirmed as being no longer members and
therefore will not be allowed to use the system.

Expired/Invalid members should be allowed to look at their payment
data pages, and nothing else?

=cut

sub logged_in: Chained('base') :PathPart(''): CaptureArgs(0) {
    my ($self, $c) = @_;

    if(!$c->authen_cookie_value()) {
        $c->log->debug("no cookie, login");
        return $c->res->redirect($c->uri_for('login'));
    }
    $c->stash->{person_id} = $c->authen_cookie_value->{person_id};

    my $person = $c->model('AccessDB::Person')->find({
        id => $c->stash->{person_id},
        end_date => undef,
    });
    if(!$person) {
        $c->log->debug("User was logged in, but has since had an end_date set?");
        return $c->res->redirect($c->uri_for('login'));
    }
    $c->stash->{person} = $person;
}

sub profile : Chained('logged_in') :PathPart('profile'): Args(0) {
    my ($self, $c) = @_;

    my $things_rs = $c->model('AccessDB::Tool');
    $things_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
    my %things;
    foreach my $thing ($things_rs->all) {
        $things{$thing->{id}} = $thing->{name};
    }

    $c->stash->{things} = \%things;
    $c->stash->{current_page} = 'profile';
    $c->stash->{template} = 'profile.tt';
}

sub editme : Chained('logged_in') :PathPart('editme'): Args(0) {
    my ($self, $c) = @_;

    my $form = AccessSystem::Form::Person->new({ctx => $c});
    $c->stash->{person}->payment_override($c->stash->{person}->normal_dues);
    if($form->process(
           item => $c->stash->{person},
           params => $c->req->parameters,
           inactive => ['dob','membership_guide','has_children','more_children','capcha', 'submit'],
           active => ['submit_edit'],
       )) {
        $c->res->redirect($c->uri_for('profile'));
    } else {
        $c->stash(form => $form,
                  current_page => 'profile',
                    template => 'forms/editme.tt');
    }
}

sub download_data: Chained('logged_in') :PathPart('download'): Args(0) {
    my ($self, $c) = @_;

    my $person_data_rs = $c->model('AccessDB::Person')->search(
        { 'me.id' => $c->stash->{person}->id },
        {
            prefetch => ['payments', 'tokens', 'usage', 'allowed', 'transactions']
        }
    );
    $person_data_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');

    $c->response->content_type('application/json');
    $c->res->header('Content-Disposition', qq[attachment; filename="makerspace_data.json"]);
    $c->response->body(encode_json([ $person_data_rs->all ]));
    
}

sub delete_me :Chained('logged_in'): PathPart('deleteme'): Args(0) {
    my ($self, $c) = @_;

    if($c->req->method eq 'POST' && $c->req->param('reallyreally') eq 'yupyup') {
        $c->unset_authen_cookie();
        $c->stash->{person}->delete;
        return $c->response->redirect($c->uri_for('login'));
    } else {
        $c->stash->{template} = 'deleteme.tt';
    }
}

sub delete_token :Chained('logged_in'): PathPart('delete_token'): Args(0) {
    my ($self, $c) = @_;
    my $token = $c->req->params->{token};

    # These are GET reqs (cos lazy, and its a link)
    # Must retain at least one token
    if($c->stash->{person} && $c->stash->{person}->tokens_rs->count > 1) {
        my $token_obj = $c->stash->{person}->tokens_rs->find({ id => $token });
        if($token_obj) {
            $token_obj->delete();
        }
    }
    return $c->response->redirect($c->uri_for('profile'));
}

sub delete_vehicle :Chained('logged_in'): PathPart('delete_vehicle'): Args(0) {
    my ($self, $c) = @_;
    my $vehicle = $c->req->params->{vehicle};

    # These are GET reqs (cos lazy, and its a link)
    my $vehicle_obj = $c->stash->{person}->vehicles_rs->find({ plate_reg => $vehicle });
    if($vehicle_obj) {
        $vehicle_obj->delete();
    }
    return $c->response->redirect($c->uri_for('profile'));
}

sub who : Chained('base') : PathPart('who') : Args(0)  {
    my ($self, $c) = @_;

    $c->res->content_type('text/plain');
    $c->res->body('<No token id>'), return if !$c->req->params->{token};

    my $token = $c->model('AccessDB::AccessToken')->find({ id => $c->req->params->{token} }, { prefetch => 'person' });
    $c->res->body('<No such person>'), return if !$token;

    $c->res->body($token->person->name);
}

## Given an access token, eg RFID id or similar, and a "thing" guid,
## eg "the Main Door", check whether they both exist as ids, and
## whether a person owning said token is allowed to access said thing.

sub verify: Chained('base') :PathPart('verify') :Args(0) {
    my ($self, $c) = @_;

    if($c->req->params->{token} && $c->req->params->{thing}) {
        ## Got two params, check if person has em as access token and allowed thing
        my $result = $c->model('AccessDB::Person')->allowed_to_thing
           ($c->req->params->{token}, $c->req->params->{thing});
        if($result && !$result->{error}) {
            $c->stash(
                json => {
                    person => { name => $result->{person}->name },
                    inductor => $result->{person}->allowed->first->is_admin,
                    access => 1,
                    cache => $result->{person}->tier->restrictions->{'times'} ? 0 : 1,
                    colour => $result->{person}->door_colour_to_code || 0x01,
                }
            );
        } elsif($result) {
            $c->stash(
                json => {
                    access => 0,
                    error  => $result->{error},
                    colour => $result->{colour},
                }
            );
        } else {
            $c->stash(
                json => {
                    access => 0,
                    error  => 'Failed to look up parameters',
                    colour => 0x23,
                }
            );
        }

        ## Log results:
        ## NB: tool_access will update this row with a running_for / time later
        $c->model('AccessDB::UsageLog')->create(
            {
                person_id => $result && $result->{person} && $result->{person}->id || undef,
                tool_id => $c->req->params->{thing},
                token_id => $c->req->params->{token},
                status => ($c->stash->{json}{access} ? 'started' : 'rejected'),
            });
    
    } else {
        $c->stash(
            json => {
                access => 0,
                error  => 'Missing token or thing parameter(s)',
            }
        );
    }

    print STDERR "VERIFY: ", Dumper($c->stash->{json});
    ## can't fwd to our own View::JSON, this one somehow takes over
    ## and fucks it up!
    $c->forward('View::JSON');

    $c->res->body($c->res->body() . "\n");
    $c->res->content_length(length($c->res->body));
}

=head2 msglog

Query Params:

=over

=item thing = GUID of the thing controller doing the checking

=item msg = text of the message to save

=back

=cut

sub msg_log: Chained('base'): PathPart('msglog'): Args() {
    my ($self, $c) = @_;
    
    if($c->req->params->{thing} && $c->req->params->{msg}) {
        my $thing = $c->model('AccessDB::Tool')->find({ id => $c->req->params->{thing} });
        if($thing) {
            $thing->create_related('logs',
                                   { message => $c->req->params->{msg},
                                     from_ip => $c->req->address });
            $c->stash(json => { logged => 1 });
        } else {
            $c->stash(json =>
                      { logged => 0,
                        error => "No such thing!",
                      });
        }        
    } else {
        $c->stash(json => { error => 'Missing thing or msg parameter' });
    }
    
    $c->forward('View::JSON');
}

=head2 tool_access

Update UsageLog/state for a tool

Query Params:

=over

=item token = user's access token id

=item thing = GUID of the thing controller doing the checking

=item msg = description of whats happening

=item state = 1 (on), 0 (off)

=item active_time = number of seconds tool has been active

=back

=cut

sub tool_access: Chained('base'): PathPart('tool_access'): Args() {
    my ($self, $c) = @_;

    # Need person that owns this token:
    my $allowed_to = $c->model('AccessDB::Person')->allowed_to_thing(
        $c->req->params->{token},
        $c->req->params->{thing},
       );
    if ($allowed_to) {
        # existing usagelog, as created by verify
        # will fail/find an old one, if tool was used for less than 5mins
        # time updated every 5 mins, new use sends active_time=0
        my $usage = $c->model('AccessDB::UsageLog')->find({
            'tokens.id' => $c->req->params->{token},
            tool_id => $c->req->params->{thing},
            person_id => $allowed_to->{person}->id,
            status => { '!=' => 'finished' },
            running_for => { '<=' => $c->req->params->{active_time} },
        }, {
            join => {'person' => 'tokens'}
        });
        # might not exist, tool controller caches member tokens for 24hrs
        # aka didnt call verify
        if(!$usage) {
            # No verify, or starting a new job somehow (running_for is lower)
            $usage = $c->model('AccessDB::UsageLog')->create({
                person_id => $allowed_to->{person}->id,
                tool_id => $c->req->params->{thing},
                token_id => $c->req->params->{token},
                status => 'started',
            });
        }
        $usage->update({
            running_for => $c->req->params->{active_time},
            status => ($c->req->params->{state} ? 'running' : 'finished'),
        });
        $c->stash(json => { logged => 1 });
    } else {
        $c->stash(json => { error => 'Person not allowed to use Tool!?'});
    }

    $c->forward('View::JSON');
}

## Thing X (from correct IP Y) says person T inducts person S to use it:

sub induct: Chained('base'): PathPart('induct'): Args() {
    my ($self, $c) = @_;

    if($c->req->params->{token_t} && $c->req->params->{token_s} && $c->req->params->{thing}) {
        my $thing = $c->model('AccessDB::Tool')->find({ id => $c->req->params->{thing} });
#        print STDERR "Thing IP: ", $thing->assigned_ip, "\n";
#        print STDERR "Req   IP: ", $c->req->address, "\n";
        if(!$thing) {
            $c->stash(
                json => {
                    error => 'No such Thing (' . $c->req->params->{thing} . ')',
                }
            );
            $c->forward('View::JSON');
            return;
        } elsif($thing->assigned_ip ne $c->req->address) {
             $c->stash(
                json => {
                    error => 'Cannot induct Thing (' . $c->req->params->{thing} . ') from incorrect IP address',
                }
            );
            $c->forward('View::JSON');
            return;           
        }

        my $result = $thing->induct_student(
            $c->req->params->{token_t}, $c->req->params->{token_s}
            );
        if($result && !$result->{error}) {
            $c->stash(
                json => {
                    allowed => 1,
                    person => { name => $result->{person}->name },
                });
        } else {
            $c->stash(
                json => {
                    allowed => 0,
                    error => $result->{error},
                }
            );
        }
    } else {
        $c->stash(
            json => {
                allowed => 0,
                error  => 'Missing token or thing parameter(s)',
            }
        );
    }

    ## can't fwd to our own View::JSON, this one somehow takes over
    ## and fucks it up!
    $c->forward('View::JSON');
}

sub assign: Chained('base'): PathPart('assign'): Args(0) {
    my ($self, $c) = @_;

    ## Missing a string for the tag description..
    ## Is the "thing" required? not sure we need to tie this to a device:
    ## but if we don't, we can't check if allowed? do we just add an
    ## assigned_by field?
    ## Or let the logger stuff keep track of it..
    if($c->req->params->{admin_token} && $c->req->params->{person_id} && $c->req->params->{thing} && $c->req->params->{token_id}) {
        # Does the admin token exist, and are they allowed to use the tag assigner
        my $person_thing = $c->model('AccessDB::Person')->allowed_to_thing($c->req->params->{admin_token}, $c->req->params->{thing});
        if($person_thing->{person} && $person_thing->{thing}->name =~/TagAssigner/) {
            # check new token isnt already in use:
            if(!$c->model('AccessDB::AccessToken')->find({id => $c->req->params->{token_id}})) {
                # my $p_id = $c->req->params->{person_id}+0;
                my $person = $c->model('AccessDB::Person')->find(
                    {id => $c->req->params->{person_id}});
                if($person) {
                    $c->model('AccessDB::AccessToken')->create({
                        id => $c->req->params->{token_id},
                        person_id => $person->id,
                        type => $c->req->params->{desc} || 'Added by TagAssigner',
                    });
                    my $tok_count = $person->tokens_rs->count;
                    my $name = $person->name;
                    $c->stash(
                        json => {
                            tokens => $tok_count,
                            message => "Done. $name has $tok_count tokens.",
                        });
                } else {
                    $c->stash(
                        json => {
                            tokens => 0,
                            error => 'Nope. Can\'t find that person id.',
                        });
                }
            } else {
                $c->stash(
                    json => {
                        tokens => 0,
                        error => 'Nope. That token is already in use!',
                   });
            }
        } else {
            $c->stash(
                json => {
                    tokens => 0,
                    error => $person_thing->{error},
                   });
        }
        # Does the member/person id exist
    } else {
        $c->stash(
            json => {
                tokens => 0,
                error => 'Missing parameter(s)',
            });
    }
    $c->log->debug(Data::Dumper::Dumper($c->stash->{json}));
    $c->forward('View::JSON');
}

sub record_transaction: Chained('base'): PathPart('transaction'): Args(0) {
    my ($self, $c) = @_;

    ## GUID - using an app linked to a user via a guid
    if($c->req->params->{hash} && $c->req->params->{amount} && $c->req->params->{reason}) {
        $c->model('AccessDB')->schema->txn_do(
            sub {
                ## Member: - using oneall guids?
                my $member = $c->model('AccessDB::Person')->get_person_from_hash($c->req->params->{hash});
                print STDERR "Found person: ", $member->id, "\n";
                if($member) {
                    my @result = $member->add_debit($c->req->params->{amount}, $c->req->params->{reason});
                    $c->stash(
                        json => {
                            success => $result[0],
                            ( $result[0] ? () : ( error => $result[1])),
                            ( $result[2] ? ( balance => $result[2] ) : () ),
                        },
                    );
                }
            }
        );
    }
    
    ## Token - using an iot device with an rfid reader
    elsif($c->req->params->{token} && $c->req->params->{thing} && $c->req->params->{amount} && $c->req->params->{reason}) {
        my $is_allowed = $c->model('AccessDB::Person')->allowed_to_thing
            ($c->req->params->{token}, $c->req->params->{thing});
        my $thing = $c->model('AccessDB::Tool')->find({ id => $c->req->params->{thing} });
        if($is_allowed && !$is_allowed->{error}) {
            my $amount = $c->req->params->{amount};
            my $thing = $is_allowed->{thing};
            if($thing->assigned_ip ne $c->req->address) {
                $c->stash(
                    json => {
                        success => 0,
                        error   => 'Request does not come from correct thing IP',
                    });
            }
            my ($success, $mesg, $bal) = $is_allowed->{person}->add_debit($amount, $c->req->params->{reason});

            $c->stash(
                json => {
                    success => $success,
                    ($success ? (error => $mesg) : ()),
                    ($bal     ? (balance => $bal) : ()),
                });

        } elsif($is_allowed) {
            $c->stash(
                json => {
                    success => 0,
                    error   => $is_allowed->{error},
                }
            );
        } else {
            $c->stash(
                json => {
                    success => 0,
                    error   => 'Failed to look up parameters',
                }
            );
        }
    } else {
        $c->stash(
            json => {
                success => 0,
                error   => 'Missing token or thing or amount or reason parameter(s)',
            }
        );
    }
    print STDERR "TRANSACTION: ", Dumper($c->stash->{json});
    ## can't fwd to our own View::JSON, this one somehow takes over
    ## and fucks it up!
    $c->forward('View::JSON');
    
}

=head2 get_transactions

Get most N recent transactions

=cut

sub get_transactions: Chained('base'): PathPart('get_transactions'): Args(2) {
    my ($self, $c, $count, $userhash) = @_;

    print STDERR "Looking for person: $userhash\n";
    my $member = $c->model('AccessDB::Person')->get_person_from_hash($userhash);
    if(!$member) {
        $c->stash(
            json => [],
        );
    } else {
        my @transactions = map { {
            added_on => $_->added_on->iso8601(),
            reason => $_->reason,
            amount => $_->amount_p,
        }  } ($member->recent_transactions($count)->all);
        
        $c->stash(
            json => {
                transactions => [@transactions],
                balance      => $member->balance_p,
            },
        );
    }
    $c->forward('View::JSON');
    
}

=head2 user_guid_request

Given a user id, send the member with that id an email, containing
their guid. This is for putting into the phone app.

=cut

sub user_guid_request: Chained('base'): PathPart('user_guid_request'): Args(0) {
    my ($self, $c) = @_;
    my $userid = $c->req->params->{userid};
    $userid =~ s/^(?:SM|sm)//;
    my $success = 1;
    my $message = '';
    my $member = $c->model('AccessDB::Person')->find({ id => $userid});

    if(!$userid || $userid =~ /\D/ || !$member) {
        $c->stash(
            json => {
                success => 0,
                error => 'No member matching this reference',
            });
        return $c->forward('JSON');
    } elsif(!$member->valid_until || $member->valid_until < DateTime->now) {
        $c->stash(
            json => {
                success => 0,
                error => 'Member is invalid (not paid recently), did you mistype the ref?',
            });
        return $c->forward('JSON');
    } elsif($member->login_tokens->count == 0) {
        $success = 0;
        $message = 'Member doesn\'t have any logins';
    }
    my $comms = $member->create_communication(
        # subject
        'Swindon Makerspace App Login',
        # type
        'app_login_email',
        # vars
        {
            success => $success,
            login_token => $member->login_tokens->first->login_token,
            link => $c->uri_for('login'),
        }
        );
    $self->emailer->send($comms);
    $c->stash(
        json => {
            success => $success,
        });
    $c->forward($c->view('JSON'));
}

sub confirm_telegram: Chained('base'): PathPart('confirm_telegram'): Args(0) {
    my ($self, $c) = @_;

    my $email = $c->req->params->{email};
    my $telegram_chatid = $c->req->params->{chatid};
    my $telegram_user   = $c->req->params->{username} || '';
    my $members = $c->model('AccessDB::Person')->search_rs({
        '-and' => [
            end_date => undef,
            \ ['LOWER(email) = ?', lc($email)],
            ]});
    my $success = 0;
    my $msg = '';
    if ($members->count == 1) {
        my $token = Data::GUID->new->as_string();
        my $member = $members->first;
        $member->confirmations->create({
            token => $token,
            storage => {
                telegram_chatid => $telegram_chatid,
                telegram_username => $telegram_user,
                },
        });
    my $comms = $member->create_communication(
        # subject
        'Swindon Makerspace Telegram Confirmation',
        # type
        'confirm_telegram',
        # vars
        { 'link' => $c->uri_for('confirm_email', { token => $token }),
              telegram_user => $telegram_user,
              telegram_chatid => $telegram_chatid }
        );

        $self->emailer->send($comms);
        $success = 1;
   } else {
        $msg = "I can't find a member with that email address, or there are more than one of them!";
    }
    $c->stash(
        json => {
            ( $msg ? (error => $msg) : () ),
                success => $success,
        });
    $c->forward($c->view('JSON'));
}

sub confirm_email: Chained('base'): PathPart('confirm_email'): Args(0) {
    my ($self, $c) = @_;

    my $token = $c->req->params->{token};
    my $confirm = $c->model('AccessDB::Confirm')->find({ token => $token });
    if ($confirm) {
        my $user_update = $confirm->storage;
        # telegram_chatid, telegram_username .. or whatever we add later
        $confirm->person->update($user_update);
        $confirm->delete();
    }
    return $c->res->redirect($c->uri_for('post_confirm', { type => 'telegram' }));
}

sub post_confirm: Chained('base'): PathPart('post_confirm'): Arg(0) {
    my ($self, $c) = @_;

    $c->stash->{current_page} = 'post_confirm';
    $c->stash->{type} = $c->req->params->{type};
    $c->stash->{template} = 'post_confirm.tt';
}

sub send_induction_acceptance: Chained('base'): PathPart('send_induction_acceptance'): Args(0) {
    my ($self, $c) = @_;

    my $tool_id = $c->req->params->{tool};
    my $person_id = $c->req->params->{person};
    my $allowed = $c->model('AccessDB::Allowed')->search_rs({
        tool_id => $tool_id,
        person_id => $person_id,
        pending_acceptance => 'true'
    });
    my $success = 0;
    my $msg = '';
    if ($allowed->count == 1) {
        my $allowed_row = $allowed->first;
        my $member = $allowed_row->person;
        my ($comms, $confirm) = $member->create_induction_email($allowed_row, $c->request->base);
        if (!$comms) {
            $success = 0;
            $msg = "Failed to create or find mail!";
        } else {
            $self->emailer->send($comms);
            $success = 1;
        }
   } else {
        $msg = "I can't find a member with that email address, or there are more than one of them!";
    }
    $c->stash(
        json => {
            ( $msg ? (error => $msg) : () ),
                success => $success,
        });
    $c->forward($c->view('JSON'));
    my $token = $c->req->params->{token};
}

sub confirm_induction: Chained('base'): PathPart('confirm_induction'): Args(0) {
    my ($self, $c) = @_;
   
    my $token = $c->req->params->{token};
    my $confirm = $c->model('AccessDB::Confirm')->find({ token => $token });
    if ($confirm) {
        my $induction_update = $confirm->storage;
        $confirm->person->allowed->find({ tool_id => $induction_update->{tool_id}})->update({ pending_acceptance => 'false', accepted_on => DateTime->now()});
        $confirm->delete();
    }
    return $c->res->redirect($c->uri_for('post_confirm', { type => 'induction' }));
}

=head2 get_dues

Returns amount of dues, in pence, which would be payable using current
input values of: date of birth (dob), concession rate
(concessionary_rate_override), and tier (tier) chosen.

Used by the L</register> page to live-update dues values when
prospective members change rates/concession choices.

=cut

sub get_dues: Chained('base'): PathPart('get_dues'): Args(0) {
    my ($self, $c) = @_;

    my $dob = $c->req->params->{dob};
    my $concession = $c->req->params->{concessionary_rate_override} || '';
    my $tier = $c->req->params->{tier} || 3;

    $c->log->debug(Data::Dumper::Dumper($c->req->params));
#    $c->log->debug("Vals: $dob $concession $other_hackspace Result: ", $new_person->dues);
    my $new_person = $c->model('AccessDB::Person')->new_result({});
    $new_person->tier_id($tier);
    $new_person->dob($dob) if $dob;
    $new_person->concessionary_rate_override($concession);

    $c->log->debug("Vals: $dob $concession Result: ", $new_person->dues);
    $c->response->body($new_person->dues / 100);
}

sub register: Chained('base'): PathPart('register'): Args(0) {
    my ($self, $c) = @_;

    my $form = AccessSystem::Form::Person->new({ctx => $c, inactive => ['has_children']});
    my $new_person = $c->model('AccessDB::Person')->new_result({});
    $new_person->tier_id(3);
    $new_person->payment_override($new_person->normal_dues);
    $new_person->door_colour('green');

    if($form->process(
        item => $new_person,
        params => $c->req->parameters
       )) {
        ## If children are included, go on to children adding stage
        if($c->req->params->{has_children}) {
            $c->session(parent_id => $new_person->id);
            return $c->res->redirect($c->uri_for(
                                         $self->action_for('add_child'),
                                     ));
        }

        ## Email new member their payment details!
        $new_person->discard_changes();
        $c->stash->{member} = $new_person;
        $c->forward('finish_new_member');

        ## Then, display details just in case:
        $c->stash( template => 'member_created.tt');
    } else {
        $c->stash(form => $form, 
                  template => 'forms/person.tt');
    }
}

sub add_child: Chained('base') :PathPart('add_child') :Args(0) {
    my ($self, $c) = @_;

    my $parent_id = $c->session->{parent_id} || $c->req->params->{parent_id};
    my $parent = $c->model('AccessDB::Person')->find({ id => $parent_id });
    if(!$parent_id || !$parent) {
        $c->res->code(404);
        $c->res->body('Error, no parent to add child to');
        return;
    }

    ## Children don't need to agree to the membership guide (at least
    ## not via their parents, maybe when they become 18?), and get the
    ## same address as their parents.  They also don't require an
    ## email address (this means we can't have a unique constraint on
    ## email address, not sure that's good anyway.
    
    my $form = AccessSystem::Form::Person->new(
        ctx => $c,
        active => ['more_children'], 
        inactive => ['has_children', 'membership_guide', 'address', 'payment_override']
    );
    my $new_person = $c->model('AccessDB::Person')->new_result({});
    $new_person->parent_id($parent_id);
    $new_person->address($parent->address);
    if($form->process(
           update_field_list => {
               email => { required => 0 },
           },
           item => $new_person,
           params => $c->req->parameters
       )) {

        ## If more children, go round again:
        if($c->req->params->{more_children}) {
            $c->session(parent_id => $parent->id);
            return $c->res->redirect($c->uri_for(
                                         $self->action_for('add_child'),
                                     ));
        }

        ## Email new member their payment details!
        $c->stash->{member} = $parent;
        $c->forward('finish_new_member');

        ## Then, display details just in case:
        $c->stash( template => 'member_created.tt');
        
    } else {
        $c->stash(form => $form,
                  parent => $parent,
                  template => 'forms/person.tt');
    }
}

sub finish_new_member: Private {
    my ($self, $c) = @_;

    # Allow member + all children to access door!
    $c->stash->{member}->create_related(
        'allowed',
        { tool_id => '1A9E3D66-E90F-11E5-83C1-1E346D398B53', is_admin => 0 });
    $_->create_related(
        'allowed',
        { tool_id => '1A9E3D66-E90F-11E5-83C1-1E346D398B53', is_admin => 0 })
        for $c->stash->{member}->children;

    # have read+accepted H&S policy:
    $c->stash->{member}->create_related(
        'allowed',
        { tool_id => '0E899E10-188C-11F0-8E38-5C924532D5BD', is_admin => 0, pending_acceptance => 0 });
    $c->forward('send_membership_email');   
}
    

sub resend_email: Chained('base'): PathPart('resendemail'): Args(1) {
    my ($self, $c, $id) = @_;
    my $member = $c->model('AccessDB::Person')->find({ id => $id });
    if($member) {
        $c->stash(member => $member);
        $c->forward('send_membership_email');
        $c->stash(json => { message => "Attempted to send membership email" });
    } else {
        $c->stash(json => { message => "Can't find member $id" });
    }
    delete $c->stash->{member};
    $c->forward('View::JSON');
}

sub send_membership_email: Private {
    my ($self, $c) = @_;

    my $member = $c->stash->{member};
    my $dues_nice = sprintf("%0.2f", $member->dues/100);
    my $access = $member->tier->times_to_string;
    ## Create the comms:
    my $comms = $member->create_communication(
        'Swindon Makerspace membership info',
        'send_membership_email',
        { dues_nice => $dues_nice, access => $access }
    );
    $self->emailer->send($comms);
}

sub nudge_member: Chained('base'): PathPart('nudge_member'): Args(1) {
    my ($self, $c, $id) = @_;
    my $member = $c->model('AccessDB::Person')->find({ id => $id });
    if($member && !$member->is_valid && !$member->end_date) {
        $c->stash(member => $member);
        $c->forward('send_reminder_email');
        if ($c->stash->{message}) {
            # may have failed / not been sent
            $c->stash(json => { message => $c->stash->{message} });
        } else {
            $c->stash(json => { message => "Attempted to send reminder email" });
        }
    } else {
        $c->stash(json => { message => "Can't find member $id or member is still valid!" });
    }
    delete $c->stash->{member};
    $c->forward('View::JSON');
}

sub send_reminder_email: Private {
    my ($self, $c) = @_;

    my $comms_type = 'reminder_email';
    my $member = $c->stash->{member};
    # don't manually remind people more than once a day!
    my $comms = $member->communications_rs->search_rs(
        { type => $comms_type })->first;
    if($comms
       && $comms->sent_on > DateTime->now->clone->subtract(days => 1)) {
        $c->stash->{message} = 'Already reminded on ' . $comms->sent_on->iso8601();
        return;
    }
    my $last = $member->last_payment;
    my $paid_date = sprintf("%s, %d %s %d",
                            $last->paid_on_date->day_abbr,
                            $last->paid_on_date->day,
                            $last->paid_on_date->month_name,
                            $last->paid_on_date->year);
    my $expires_date = sprintf("%s, %d %s %d",
                            $last->expires_on_date->day_abbr,
                            $last->expires_on_date->day,
                            $last->expires_on_date->month_name,
                            $last->expires_on_date->year);
    ## Store the comms:
    $comms = $member->create_communication(
        'Swindon Makerspace membership check',
        'reminder_email',
        { paid_date => $paid_date, expires_date => $expires_date },
    );
    $self->emailer->send($comms);
}

sub box_reminder: Chained('base'): PathPart('box_reminder'): Args(1) {
    my ($self, $c, $id) = @_;
    my $member = $c->model('AccessDB::Person')->find({ id => $id });
    if($member && !$member->is_valid && !$member->end_date) {
        $c->stash(member => $member);
        $c->forward('send_box_reminder_email');
        $c->stash(json => { message => "Attempted to send box reminder email" });
    } else {
        $c->stash(json => { message => "Can't find member $id or member is still valid!" });
    }
    delete $c->stash->{member};
    $c->forward('View::JSON');
}

sub send_box_reminder_email: Private {
    my ($self, $c) = @_;

    my $member = $c->stash->{member};
    my $dues_nice = sprintf("%0.2f", $member->dues/100);
    my $name = $member->name;
    my $expire_date = DateTime->now()->add(months => 1);
    my $now_plus_one_month = sprintf("%s, %d %s %d",
                                     $expire_date->day_abbr,
                                     $expire_date->day,
                                     $expire_date->month_name,
                                     $expire_date->year
        );
    my $bank_ref = $member->bank_ref;
    ## Store the comms:
    my $comms = $member->create_communication(
        'Your Swindon Makerspace member box',
        'box_reminder_email',
        { dues_nice => $dues_nice, now_plus_one_month => $now_plus_one_month },
    );
    $self->emailer->send($comms);
}

=head2 membership_status_update

Collect and send out details about current membership to
info@swindon-makerspace.org. No display!

=cut

sub membership_status_update : Chained('base') :PathPart('membership_status_update') {
    my ($self, $c) = @_;

    # Number of current / active members
    # Number of recent "leavers" / out of date members

    my $data = $c->model('AccessDB::Person')->membership_stats();

    use Data::Dumper;
    $c->log->debug(Dumper($data));
    $c->stash->{email} = Email::MIME->create({
        header_str => [
            From => 'info@swindon-makerspace.org',
            To => $c->config->{emails}{cc},
            Subject => 'Swindon Makerspace membership status',
           ],
        body => "
Dear Directors,

" . $data->{msg_text} . "\n\n" . $data->{recently} ."

Regards,

The Access System.
",
    });

    $self->emailer->send($c->stash->{email});   
    $c->stash->{json} = $data;
    $c->forward('View::JSON');

}

sub verify_token {
    my ($self, $conn_token, $conf) = @_;

    my $user_token_uri = 'https://'
        . $conf->{domain} . "/connections/${conn_token}.json\n" ;
    my $ua = LWP::UserAgent->new();
    print STDERR "OneAll verify $user_token_uri";
    my $resp = $ua->get($user_token_uri,
                        'Authorization' => 'Basic ' . encode_base64($conf->{public_key} . ':' . $conf->{private_key}));
    if(!$resp->is_success) {
        return 0;
    }
    my $ut_json = $resp->decoded_content;
    
    my $ut_result = JSON::decode_json($ut_json) if $ut_json;
    print STDERR Dumper($ut_result || '');
    if($ut_json && $ut_result->{response}{result}{status}{flag} ne 'error') {
        ## should be "social_login" as its the result of a login call? always?
#                my $trans_type = $ut_result->{response}{result}{data}{plugin}{key};
        return $ut_result->{response}{result}{data};
    } else {
        return 0;
    }   
}

=head2 vehicles

Plain-text list of vehicles, of currently paid-up members, sorted
alphabetically.

=cut

sub vehicles : Chained('logged_in') :PathPart('vehicles') {
    my ($self, $c) = @_;

    my $v_rs = $c->model('AccessDB::Vehicle')->
        search_rs({},
            {
                join => 'person',
                order_by => 'plate_reg'
            });
    my $output_str = '';
    my $now = DateTime->now();
    foreach my $v ($v_rs->all) {
        my $valid_until = $v->person->valid_until;
        next if !$valid_until;
        next if $valid_until && $valid_until <= $now;
        $output_str .= $v->plate_reg . "\r\n";
    }

    $c->res->content_type('text/plain');
    $c->res->body($output_str);
}

sub membership_register : Chained('logged_in') :PathPart('membership_register') {
    my ($self, $c) = @_;

    my $from_date = $c->req->params->{at_date};
    $from_date = DateTime->now->ymd
        if $from_date !~ /^\d{4}-\d{2}-\d{2}$/;
    #$c->model('AccessDB::Person')->update_member_register();
    $c->stash( register => $c->model('AccessDB::MemberRegister')->on_date($from_date),
               template => 'member_register.tt' );
}


=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {
    my ($self, $c) = @_;

    $c->stash( current_view => 'TT');
}

=head1 AUTHOR

Catalyst developer

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
