package AccessSystem::API::Controller::Root;
use Moose;
use namespace::autoclean;
use AccessSystem::Form::Person;
use DateTime;
use Data::Dumper;
use LWP::UserAgent;
use MIME::Base64;
use JSON;

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

# insert into accessible_things (id, name, assigned_ip) values ('D1CAE50C-0C2C-11E7-84F0-84242E34E104', 'oneall_login_callback', '192.168.1.70');

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
            ],
            {
                prefetch => 'login_tokens',
            }
            );
        if($person->count > 1) {
            $person = $person->search({ parent_id => undef });
        }
        if(!$person->count || $person->count > 1) {
            $c->session->{message} = "Failed to match login against existing Makerspace member, ask an admin to check the message log if this is incorrect (tried to match email: $emails[0] )";

            $c->model('AccessDB::MessageLog')->create({
                accessible_thing_id => 'D1CAE50C-0C2C-11E7-84F0-84242E34E104',
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
            accessible_thing_id => 'D1CAE50C-0C2C-11E7-84F0-84242E34E104',
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
            prefetch => ['payments', 'tokens', 'usage', 'allowed']
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
                }
            );
        } elsif($result) {
            $c->stash(
                json => {
                    access => 0,
                    error  => $result->{error},
                }
            );
        } else {
            $c->stash(
                json => {
                    access => 0,
                    error  => 'Failed to look up parameters',
                }
            );
        }

        ## Log results:
        $c->model('AccessDB::UsageLog')->create(
            {
                person_id => $result && $result->{person} && $result->{person}->id || undef,
                accessible_thing_id => $c->req->params->{thing},
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
        my $thing = $c->model('AccessDB::AccessibleThing')->find({ id => $c->req->params->{thing} });
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
        my $thing = $c->model('AccessDB::AccessibleThing')->find({ id => $c->req->params->{thing} });
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

# Mini api - get possible dues given Age, Concession, Other hackspace member
# Ignoring Children for now as the register form adds those after the main member

sub get_dues: Chained('base'): PathPart('get_dues'): Args(0) {
    my ($self, $c) = @_;

    my $dob = $c->req->params->{dob};
    my $concession = $c->req->params->{concessionary_rate_override} || '';
    my $other_hackspace = $c->req->params->{member_of_other_hackspace} || '';

    $c->log->debug(Data::Dumper::Dumper($c->req->params));
#    $c->log->debug("Vals: $dob $concession $other_hackspace Result: ", $new_person->dues);
    my $new_person = $c->model('AccessDB::Person')->new_result({});
    $new_person->dob($dob);
    $new_person->concessionary_rate_override($concession);
    $new_person->member_of_other_hackspace(1) if $other_hackspace;

    $c->log->debug("Vals: $dob $concession $other_hackspace Result: ", $new_person->dues);
    $c->response->body($new_person->dues / 100);
}

sub register: Chained('base'): PathPart('register'): Args(0) {
    my ($self, $c) = @_;

    my $form = AccessSystem::Form::Person->new({ctx => $c, inactive => ['has_children']});
    my $new_person = $c->model('AccessDB::Person')->new_result({});
    $new_person->payment_override($new_person->normal_dues);

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
        { accessible_thing_id => '1A9E3D66-E90F-11E5-83C1-1E346D398B53', is_admin => 0 });
    $_->create_related(
        'allowed',
        { accessible_thing_id => '1A9E3D66-E90F-11E5-83C1-1E346D398B53', is_admin => 0 })
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
    $c->stash->{email} = {
            to => $member->email,
            cc => $c->config->{emails}{cc},
            from => 'info@swindon-makerspace.org',
            subject => 'Swindon Makerspace membership info',
            body => "
Dear " . $member->name . ",

Thank you for signing up for membership of the Swindon Makerspace. To activate your 24x7 access and ability to use the regulated equipment, please set up a Standing Order with your bank using the following details:

Monthly fee: £${dues_nice}/month
To: Swindon Makerspace
Bank: Barclays
Sort Code: 20-84-58
Account: 83789160
Ref: " . $member->bank_ref . "

To get access to the Makerspace, please visit on an open evening (Wednesday evenings), and bring (or buy for £1 from the space) a suitable token.

Please do make sure you have read the Member's Guide (which you just agreed to!) as this details how the space works
- if you missed it, here is the link again: https://docs.google.com/document/d/1ruqYeKe7kMMnNzKh_LLo2aeoFufMfQsdX987iU6zgCI/edit#heading=h.a7vgchnwk02g

For live chat with other members, you are encouraged to join our Telegram group: https://telegram.me/joinchat/A5Xbrj7rku3FJlueOPF8vg.
This is useful for seeing if anyone is in the space, getting help/ideas on projects etc.

For more drawn out discussions (that you can read back on), we use Google Groups: https://groups.google.com/forum/#!forum/swindon-makerspace
and store the results in Google Drive, to view these please reply with your google login details.

Please also keep an eye on our calendar at http://www.swindon-makerspace.org/calendar/, sometimes the space is \"booked\" (see Guide!)
 you may still use the space, but please be courteous and avoid using loud machinery during bookings.

One last thing, please do try and help out, we have a number of small and large infrastructure tasks that need doing, as well as regular
maintenance (eg bins emptying!), if you see such a task and have 5 mins to do it, please don't leave it for the next member.

Thanks for reading this far! See you in the space!

Regards,

Swindon Makerspace
",
    };

    ## Store the comms:
    $member->communications_rs->create({
        type => 'membership_email',
        content => $c->stash->{email}{body},
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
            body => "
Dear " . $member->name . ",

We've noticed that you haven't paid any Makerspace membership dues recently, your last payment was on " . $paid_date .", and your membership has been expired since " . $expires_date . ". If you intended to let your membership lapse, would you mind confirming by replying to this email and letting us know?

If you'd like to resume your membership, we'd love to see you! Just make another payment and your membership will resume. We will store your membership data (for reporting purposes) for a year, and then delete it from our systems. If you wish to rejoin after a year, you will just need to re-register.

Please note: If you have left any items in the space, and intend not to resume your membership, please come and collect them. We will move items to roof storage, and in 2 weeks consider them a donation to the space.

This is the only reminder email we'll send you.

Regards,

Swindon Makerspace
",
    };

    ## Store the comms:
    $member->communications_rs->create({
        type => 'reminder_email',
        content => $c->stash->{email}{body},
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

    my $people = $c->model('AccessDB::Person');
    my %data = ();

    my $income;
    my $now = DateTime->now()->subtract(days => 1);
    my $four_weeks = $now->clone->subtract('days' => 27);
    
    while (my $member = $people->next() ) {
        my @flags = ();
        push @flags, 'valid_members' if $member->is_valid;
        push @flags, 'child' if $member->parent;

        if(!$member->parent) {
            push @flags, 'concession' if $member->concessionary_rate;
            push @flags, 'otherspace' if $member->member_of_other_hackspace;
            push @flags, 'full' if !$member->member_of_other_hackspace && ! $member->concessionary_rate;

            push @flags, 'ex_members' if $member->end_date && !$member->is_valid;
            push @flags, 'overdue_members' if !$member->end_date && !$member->is_valid;

            push @flags, 'adult';
            push @flags, 'count';
        }
        my $v_until = $member->valid_until;
        push @flags, 'recent_expired' if !$member->end_date && $v_until && $v_until < $now && $v_until >= $four_weeks;
        
        $income += $member->dues if $member->is_valid;

        for my $f (@flags) {
            if($f eq 'recent_expired') {
                my %cols = $member->get_columns;
                push @{ $data{$f}{people} }, { %cols{qw/id parent_id name member_of_other_hackspace created_date end_date/}, concessionary_rate => $member->concessionary_rate, valid_until => $v_until->ymd };
            }
            for my $g (@flags) {
                $data{$f}{$g}++;
            }
        }
    }

    use Data::Dumper;
    $c->log->debug(Dumper(\%data));
    $c->stash->{email} = {
#            to => 'jess@jandj.me.uk', #'info@swindon-makerspace.org',
            to => $c->config->{emails}{cc},
            from => 'info@swindon-makerspace.org',
            subject => 'Swindon Makerspace membership status',
            body => "
Dear Directors,

Current members: " . $data{valid_members}{count} . " - (" . join(', ', map { "$_: " . ($data{valid_members}{$_} || 0) } (qw/full concession otherspace adult child/)) . "), 
Ex members: " . ($data{ex_members}{count} || 0) . " - (" . join(', ', map { "$_: " . ($data{ex_members}{$_} || 0) } (qw/full concession otherspace/)) . "), 
Overdue members: " . $data{overdue_members}{count} ." - (" . join(', ', map { "$_: " . ($data{overdue_members}{$_} || 0) } (qw/full concession otherspac/)) . "), 
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
                                   $_->{valid_until}) } (@{ $data{recent_expired}{people} }) ) .",

Income expected: £" . sprintf("%0.2f", $income/100) . "

Regards,

The Access System.
",
    };

    $c->forward($c->view('Email'));   
    $c->stash->{json} = \%data;
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
    $c->model('AccessDB::Person')->update_member_register();
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
