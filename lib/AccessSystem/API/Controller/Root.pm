package AccessSystem::API::Controller::Root;
use Moose;
use namespace::autoclean;
use AccessSystem::Form::Person;
use DateTime;
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
        $c->forward('finish_new_member');

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
        ctx => $c,
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
    

sub resend_email: Chained('/base'): PathPart('resendemail'): Args(1) {
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
            cc => 'info@swindon-makerspace.org',
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

sub nudge_member: Chained('/base'): PathPart('nudge_member'): Args(1) {
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
            cc => 'info@swindon-makerspace.org',
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
            to => 'info@swindon-makerspace.org',
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
