package AccessSystem::Emailer;
use warnings;
use strict;

use 5.28.0;

use Moo;
use Config::General;
use Email::Sender::Simple;
use Email::Sender::Transport::SMTP;

has config => (
    is => 'rw',
    default => sub {
        return { Config::General->new("$ENV{CATALYST_HOME}/accesssystem_api.conf")->getall };
    });

sub send {
    my ($self, $email, $debug) = @_;
    $debug ||= 0;

    my $smtp = $self->config->{'View::Email'}{sender}{mailer_args};
    my $transport = Email::Sender::Transport::SMTP->new($smtp);

    if (!$debug) {
        delete $transport->{debug};
    }

    return Email::Sender::Simple->try_to_send($email, { transport => $transport});
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
            From => 'info@swindon-makerspace.org',
            To   => $comms->person->email,
            Cc => $self->config->{emails}{cc},
            Subject => $comms->subject,
        ],
        parts => \@parts
        );

    return $email;
}


1;
