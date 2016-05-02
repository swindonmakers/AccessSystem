package AccessSystem::API::Controller::Root;
use Moose;
use namespace::autoclean;
use AccessSystem::Form::Person;
use Data::Dumper;

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

sub base :Chained('/') :PathPart('') :CaptureArgs(0) {
}

## Given an access token, eg RFID id or similar, and a "thing" guid,
## eg "the Main Door", check whether they both exist as ids, and
## whether a person owning said token is allowed to access said thing.

sub verify: Chained('/base') :PathPart('verify') :Args(0) {
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

sub msg_log: Chained('/base'): PathPart('msglog'): Args() {
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

sub induct: Chained('/base'): PathPart('induct'): Args() {
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

sub register: Chained('/base'): PathPath('register'): Args(0) {
    my ($self, $c) = @_;

    my $form = AccessSystem::Form::Person->new({ctx => $c});
    my $new_person = $c->model('AccessDB::Person')->new_result({});

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
        $c->stash->{member} = $new_person;
        $c->forward('send_membership_email');

        ## Then, display details just in case:
        $c->stash( template => 'member_created.tt');
    } else {
        $c->stash(form => $form, 
                  template => 'forms/person.tt');
    }
}

sub add_child: Chained('/base') :PathPart('add_child') :Args(0) {
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
        active => ['more_children'], 
        inactive => ['has_children', 'membership_guide', 'address']
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
        $c->forward('send_membership_email');

        ## Then, display details just in case:
        $c->stash( template => 'member_created.tt');
        
    } else {
        $c->stash(form => $form,
                  parent => $parent,
                  template => 'forms/person.tt');
    }
}

sub send_membership_email: Private {
    my ($self, $c) = @_;

    my $member = $c->stash->{member};
    $c->stash->{email} = {
            to => $member->email,
#           cc => 'info@swindon-makerspace.org',
            from => 'info@swindon-makerspace.org',
            subject => 'Swindon Makerspace membership info',
            body => "
Dear " . $member->name . ",

Thank you for signing up for membership of the Swindon Makerspace. To activate your 24x7 access and ability to use the regulated equipment, please set up a Standing Order with your bank using the following details:

Monthly fee: £" . sprintf("%0.2f", $member->dues/100)  . "/month
To: Swindon Makerspace
Bank: Barclays
Sort Code: 20-84-58
Account: 83789160
Ref: " . $member->bank_ref . "

So that you don't have to wait for bank transfers to get started with the Makerspace tools, your account will be activated for the first 3 days.

Regards,

Swindon Makerspace
",
        };
        $c->forward($c->view('Email'));
    
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
