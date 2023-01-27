package AccessSystem::API::Controller::Root;
use Moose;
use namespace::autoclean;
use AccessSystem::Form::Person;
use DateTime;
use Data::Dumper;
use LWP::UserAgent;
use MIME::Base64;
use JSON;
use Data::GUID;

BEGIN { extends 'Catalyst::Controller' }

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
                    trainer => $result->{person}->get_column('trainer'),
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
    
}

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
    $c->stash->{email} = {
        to => $member->email,
        cc => $c->config->{email}{cc},
        from => 'info@swindon-makerspace.org',
        subject => 'Swindon Makerspace App Login',
        body => "
Dear " . $member->name . ",

You requested to use the Access System Mobile Payments app (or someone did using your id). " . ($success 
? "

Enter this key into the Settings -> Key field to continue: " . $member->login_tokens->first->login_token
: "

You need to login to the website first to create a login key, please visit " . $c->uri_for('login') . " ."
) .
"

Regards,

Swindon Makerspace
",
    };
    ## Store the comms:
    $member->communications_rs->create({
        type => 'app_login_email',
        content => $c->stash->{email}{body},
        status => 'sent',
    });
    $c->forward($c->view('Email'));
    $c->stash(
        json => {
            success => 1,
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
        $c->stash->{email} = {
                to => $member->email,
                cc => $c->config->{email}{cc},
                from => 'info@swindon-makerspace.org',
                subject => 'Swindon Makerspace Telegram Confirmation',
                body => "
Dear " . $member->name . ",

You requested to attach a Telegram ID of $telegram_chatid ($telegram_user) to your Makerspace Member account (or someone did using your email).

Follow this link to confirm: " . $c->uri_for('confirm_email', { token => $token }) . "

Regards,

Swindon Makerspace
",
        };
        ## Store the comms:
        $member->communications_rs->create({
            type => 'telegram_confirm',
            content => $c->stash->{email}{body},
        });
        $c->forward($c->view('Email'));
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
        my $token = Data::GUID->new->as_string();
        $member->confirmations->create({
            token => $token,
            storage => {
                tool_id => $tool_id,
                person_id => $person_id,
                },
        });
        $c->stash->{email} = {
                to => $member->email,
                cc => $c->config->{email}{cc},
                from => 'info@swindon-makerspace.org',
                subject => 'Swindon Makerspace Induction Confirmation',
                body => "
Dear " . $member->name . ",

You have been inducted on the ". $allowed_row->tool->name . "Please confirm that you understand the safety induction for using the tool, and that you take responsibility for your actions while using it.

Follow this link to confirm: " . $c->uri_for('confirm_induction', { token => $token }) . "

Regards,

Swindon Makerspace
",
        };
        ## Store the comms:
        $member->communications_rs->create({
            type => 'induction_confirm',
            content => $c->stash->{email}{body},
        });
        $c->forward($c->view('Email'));
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
    $c->stash->{email} = {
            to => $member->email,
            cc => $c->config->{emails}{cc},
            from => 'info@swindon-makerspace.org',
            subject => 'Swindon Makerspace membership info',
            content_type => 'multipart/alternative',
            parts => [
                Email::MIME->create(
                    attributes => {
                        content_type => 'text/plain',
                        charset => 'utf-8',
                    },
                    body => "
Dear " . $member->name . ",

Thank you for signing up for membership of the Swindon Makerspace. To activate your ${access} access and ability to use the regulated equipment, please set up a Standing Order with your bank using the following details:

Monthly fee: £${dues_nice}/month
To: Swindon Makerspace
Bank: Barclays
Sort Code: 20-84-58
Account: 83789160
Bank Ref: " . $member->bank_ref . "

To get access to the Makerspace, please visit on an open evening (Wednesday evenings), and bring (or buy for £1 from the space) a suitable RFID token.

Please do make sure you have read the Member's Guide (which you just agreed to!) as this details how the space works
- if you missed it, here is the link again: https://docs.google.com/document/d/1ruqYeKe7kMMnNzKh_LLo2aeoFufMfQsdX987iU6zgCI/edit#heading=h.a7vgchnwk02g

For live chat with other members, you are encouraged to join our Telegram group: https://t.me/joinchat/A5Xbrj7rku0D-F3p8wAgtQ.
This is useful for seeing if anyone is in the space, getting help/ideas on projects etc.

For more drawn out discussions (that you can read back on), announcements, and projects we have a forum located at http://forum.swindon-makerspace.org/.

Information such as Equipment documentation and ongoing project notes can be found on our wiki, located at https://github.com/swindonmakers/wiki/wiki/.

Please also keep an eye on our calendar at http://www.swindon-makerspace.org/calendar/, sometimes the space is \"booked\" (see Guide!)
 you may still use the space, but please be courteous and avoid using loud machinery during bookings.

One last thing, please do try and help out, we have a number of small and large infrastructure tasks that need doing, as well as regular
maintenance (eg bins emptying!), if you see such a task and have 5 mins to do it, please don't leave it for the next member.

Thanks for reading this far! See you in the space!

Regards,

Swindon Makerspace
",
                ),
                Email::MIME->create(
                    attributes => {
                        content_type => 'text/html',
                        charset => 'utf-8',
                    },
                    body => "
<p>Dear " . $member->name . ",</p>

<p>Thank you for signing up for membership of the Swindon Makerspace. To activate your access and ability to use the regulated equipment, please set up a Standing Order with your bank using the following details:</p>
<p>Monthly fee: £${dues_nice}/month<br/>
To: Swindon Makerspace<br/>
Bank: Barclays<br/>
Sort Code: 20-84-58<br/>
Account: 83789160<br/>
Bank Ref: " . $member->bank_ref. " <br/> 
</p>
<p>To get access to the Makerspace, please visit on an open evening (Wednesday evenings), and bring (or buy for £1 from the space) a suitable RFID token.
</p>
<p>Please do make sure you have read the Member's Guide (which you just agreed to!) as this details how the space works</p>
<p>- if you missed it, here is the link again: <a href='https://docs.google.com/document/d/1ruqYeKe7kMMnNzKh_LLo2aeoFufMfQsdX987iU6zgCI/edit#heading=h.a7vgchnwk02g'>Membership Guide</a></p>

<p>For live chat with other members, you are encouraged to join our <a href='https://t.me/joinchat/A5Xbrj7rku0D-F3p8wAgtQ'>Telegram group</a>.</p>
<p>This is useful for seeing if anyone is in the space, getting help/ideas on projects etc.</p>

<p>For more drawn out discussions (that you can read back on), announcements, and projects we have a <a href='http://forum.swindon-makerspace.org/'>forum</a>.</p>

<p>Information such as Equipment documentation and ongoing project notes can be found on our <a href='https://github.com/swindonmakers/wiki/wiki/'>Wiki</a>.</p>

<p>Please also keep an eye on our <a href='http://www.swindon-makerspace.org/calendar/'>calendar</a>, sometimes the space is \"booked\" (see Guide!). You may still use the space, but please be courteous and avoid using loud machinery during bookings.</p>

<p>One last thing, please do try and help out, we have a number of small and large infrastructure tasks that need doing, as well as regular maintenance (eg bins emptying!), if you see such a task and have 5 mins to do it, please don't leave it for the next member.</p>

<p>Thanks for reading this far! See you in the space!</p>

<p>Regards,</p>

<p>Swindon Makerspace</p>
",
                )]
    };

    ## Store the comms:
    $member->communications_rs->create({
        type => 'membership_email',
        content => $c->stash->{email}{parts}[0]->body,
        status => 'sent',
    });
    $c->forward($c->view('Email'));   
}

sub nudge_member: Chained('base'): PathPart('nudge_member'): Args(1) {
    my ($self, $c, $id) = @_;
    my $member = $c->model('AccessDB::Person')->find({ id => $id });
    if($member && !$member->is_valid && !$member->end_date) {
        $c->stash(member => $member);
        $c->forward('send_reminder_email');
        $c->stash(json => { message => "Attempted to send reminder email" });
    } else {
        $c->stash(json => { message => "Can't find member $id or member is still valid!" });
    }
    delete $c->stash->{member};
    $c->forward('View::JSON');
}

sub send_reminder_email: Private {
    my ($self, $c) = @_;

    my $member = $c->stash->{member};
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
    $c->stash->{email} = {
            to => $member->email,
            cc => $c->config->{emails}{cc},
            from => 'info@swindon-makerspace.org',
            subject => 'Swindon Makerspace membership check',
            content_type => 'multipart/alternative',
            parts => [
                Email::MIME->create(
                    attributes => {
                        content_type => 'text/plain',
                        charset => 'utf-8',
                    },
                    body => "
Dear " . $member->name . ",

We've noticed that you haven't paid any Makerspace membership dues recently, your last payment was on " . $paid_date .", and your membership has been expired since " . $expires_date . ". If you intended to let your membership lapse, would you mind confirming by using this form https://forms.gle/hnaa1honuW29jEdq5 or by replying to this email.

If you'd like to resume your membership, we'd love to see you! Just make another payment and your membership will resume. We will store your membership data (for reporting purposes) for a year, and then delete it from our systems. If you wish to rejoin after a year, you will need to re-register.

Please note: If you have left any items in the space, and intend not to resume your membership, please come and collect them. We will move items to roof storage, and in 2 weeks consider them a donation to the space.

This is the only reminder email we'll send you.

Regards,

Swindon Makerspace
",
                ),
                Email::MIME->create(
                    attributes => {
                        content_type => 'text/html',
                        charset => 'utf-8',
                    },
                    body => "
<p>Dear " . $member->name . ",</p>

<p>We've noticed that you haven't paid any Makerspace membership dues recently, your last payment was on " . $paid_date .", and your membership has been expired since " . $expires_date . ". If you intended to let your membership lapse, would you mind confirming by <a href='https://forms.gle/hnaa1honuW29jEdq5'>telling us why</a> or by replying to this email.</p>

<p>If you'd like to resume your membership, we'd love to see you! Just make another payment and your membership will resume. We will store your membership data (for reporting purposes) for a year, and then delete it from our systems. If you wish to rejoin after a year, you will need to re-register.</p>

<p>Please note: If you have left any items in the space, and intend not to resume your membership, please come and collect them. We will move items to roof storage, and in 2 weeks consider them a donation to the space.</p>

<p>This is the only reminder email we'll send you.</p>

<p>Regards,</p>

<p>Swindon Makerspace</p>
",
                )]};

    ## Store the comms:
    $member->communications_rs->create({
        type => 'reminder_email',
        content => $c->stash->{email}{parts}[0]->body,
        status => 'sent',
    });
    $c->forward($c->view('Email'));   
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
    $c->stash->{email} = {
            to => $member->email,
            cc => $c->config->{emails}{cc},
            from => 'info@swindon-makerspace.org',
            subject => 'Your Swindon Makerspace member box',
            content_type => 'multipart/altrernative',
            parts => [
                Email::MIME->create(
                    attributes => {
                        content_type => 'text/plain',
                        charset => 'utf-8',
                    },
                    body => "
Hello, $name,
  We were just doing a check-up of the member boxes, and we noticed you seem to have a box, but not a current membership.
We would, of course, love to have you back. Now is a great time to re-up. If circumstances have changed such that you need a concessionary membership (half price, 12.50 GBP/month), reply to this email and a director will help you. If you've just paused your membership during lockdown, you will be happy to know that we are now allowing groups of up to 6, and hope to be open as in the before-times on June 21st. If you've decided to not rejoin, then please reply to this email and arrange a time to get your box (and we'd like to know why you aren't coming back, if you don't mind). At the very least, please respond to this email to let us know that you don't want your stuff back, and we will dispose of it.

If you don't tell us anything, or pay your membership fees, at some point after $now_plus_one_month, we will assume you don't want your box & contents back.  Consider this your final warning of that.

Just in case you've fogotten how to give us money:

Monthly fee: £${dues_nice}/month
To: Swindon Makerspace
Bank: Barclays
Sort Code: 20-84-58
Account: 83789160
Ref: $bank_ref

Regards,
Swindon Makerspace
",
                ),
                Email::MIME->create(
                    attributes => {
                        content_type => 'text/html',
                        charset => 'utf-8',
                    },
                    body => "
<p>Hello, $name,</p>
<p>  We were just doing a check-up of the member boxes, and we noticed you seem to have a box, but not a current membership.</p>
<p>We would, of course, love to have you back. Now is a great time to re-up. If circumstances have changed such that you need a concessionary membership (half price, 12.50 GBP/month), reply to this email and a director will help you. If you've just paused your membership during lockdown, you will be happy to know that we are now allowing groups of up to 6, and hope to be open as in the before-times on June 21st. If you've decided to not rejoin, then please reply to this email and arrange a time to get your box (and we'd like to know why you aren't coming back, if you don't mind). At the very least, please respond to this email to let us know that you don't want your stuff back, and we will dispose of it.</p>

<p>If you don't tell us anything, or pay your membership fees, at some point after $now_plus_one_month, we will assume you don't want your box & contents back.  Consider this your final warning of that.</p>

<p>Just in case you've fogotten how to give us money:</p>

<p>Monthly fee: £${dues_nice}/month<br/>
To: Swindon Makerspace<br/>
Bank: Barclays<br/>
Sort Code: 20-84-58<br/>
Account: 83789160<br/>
Ref: $bank_ref<br/>
</p>
<p>Regards,</p>
<p>Swindon Makerspace</p>
"
                )]};

    ## Store the comms:
    $member->communications_rs->create({
        type => 'box_reminder_email',
        content => $c->stash->{email}{parts}[0]->body,
        status => 'sent',
    });
    $c->forward($c->view('Email'));
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
    $c->stash->{email} = {
#            to => 'jess@jandj.me.uk', #'info@swindon-makerspace.org',
            to => $c->config->{emails}{cc},
            from => 'info@swindon-makerspace.org',
            subject => 'Swindon Makerspace membership status',
            body => "
Dear Directors,

Current members: " . $data->{valid_members}{count} . " - (" . join(', ', map { "$_: " . ($data->{valid_members}{$_} || 0) } (qw/full concession otherspace adult child/)) . "), 
Ex members: " . ($data->{ex_members}{count} || 0) . " - (" . join(', ', map { "$_: " . ($data->{ex_members}{$_} || 0) } (qw/full concession otherspace/)) . "), 
Overdue members: " . $data->{overdue_members}{count} ." - (" . join(', ', map { "$_: " . ($data->{overdue_members}{$_} || 0) } (qw/full concession otherspac/)) . "), 
Recently: 
" . join("\n", map { sprintf("%03d: %40s: %20s: %s", 
                                   $_->{id},
                                   $_->{name},
                                   ($_->{concessionary_rate}
                                    ? 'concession' 
                                    : ( $_->{member_of_other_hackspace}
                                        ? 'otherspace' 
                                        : 'full' )
                                   ),
                                   $_->{valid_until}) } (@{ $data->{recent_expired}{people} }) ) .",

Income expected: £" . sprintf("%0.2f", $data->{income}/100) . "

Regards,

The Access System.
",
    };

    $c->forward($c->view('Email'));   
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
