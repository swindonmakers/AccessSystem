package AccessSystem::Emailer;
use warnings;
use strict;

use 5.28.0;

use Config::General;
use Email::Sender::Simple;
use Email::Sender::Transport::SMTP;

sub send {
    my ($class, $email) = @_;

    my %m_config = Config::General->new("$ENV{CATALYST_HOME}/accesssystem_api.conf")->getall;
    my $smtp = $m_config{'View::Email'}{sender}{mailer_args};
    my $transport = Email::Sender::Transport::SMTP->new($smtp);

    return Email::Sender::Simple->try_to_send($email, { transport => $transport});
}

1;
