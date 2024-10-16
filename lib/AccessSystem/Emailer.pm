package AccessSystem::Emailer;
use warnings;
use strict;

use 5.28.0;

use Moo;
use Config::General;
use Email::MIME;
use Email::Sender::Simple;
use Email::Sender::Transport::SMTP;
use Scalar::Util qw/blessed/;

has config => (
    is => 'lazy',
    default => sub {
        return { Config::General->new("$ENV{CATALYST_HOME}/accesssystem_api.conf")->getall };
    });

sub send {
    my ($self, $comm, $debug) = @_;
    $debug ||= 0;

    my $email;

    if (blessed $comm && $comm->isa('DBIx::Class::Core')) {
        $email = $self->generate_email($comm);
    } else {
        $email = $comm;
        $comm = undef;
    }

    my $smtp = $self->config->{'View::Email'}{sender}{mailer_args};
    my $transport = Email::Sender::Transport::SMTP->new($smtp);

    if (!$debug) {
        delete $transport->{debug};
    }

    my $ret = Email::Sender::Simple->try_to_send($email, { transport => $transport});
    if ($comm and $ret) {
        $comm->update({
            status => 'sent',
            sent_on => \'CURRENT_TIMESTAMP'
        });
    }

    return $ret;
}

sub generate_email {
    my ($self, $comms) = @_;

    my @parts;

    if ($comms->plain_text) {
        push @parts, Email::MIME->create(
                attributes => {
                    content_type => 'text/plain',
                    charset => 'utf-8',
                },
                body => $comms->plain_text,
            );
    }
    if ($comms->html) {
        push @parts, Email::MIME->create(
                attributes => {
                    content_type => 'text/html',
                    charset => 'utf-8',
                },
                body => $comms->html,
            );
    }

    my $email = Email::MIME->create(
        attributes => {
            content_type => 'multipart/alternative',
        },
        header_str => [
            From => '"Swindon Makerspace" <info@swindon-makerspace.org>',
            To   => $comms->person->email,
            Cc => $self->config->{emails}{cc},
            Subject => $comms->subject,
        ],
        parts => \@parts
        );

    return $email;
}


1;
