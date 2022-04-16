package AccessBot;

use Mojo::Base 'Telegram::Bot::Brain';
use Config::General;

has _token => undef;
has token => sub {
    my ($self) = @_;
    if (!$self->_token) {
        my %conf = Config::General->new("$ENV{BOT_HOME}/keys.conf")->getall();
        $self->_token($conf{'Telegram::Bot'}{'api'});
    };
    return $self->_token();
};

sub init {
    my $self = shift;
    $self->add_listener(\&read_message);
}

sub read_message {
    my ($self,$message) = @_;
    if($message->text =~ m{^/memberstats}) {
        $message->reply('Hi');
    }
}
1;
    
package main;

my $bot = AccessBot->new();
$bot->init;
 
my $me = $bot->getMe();
use Data::Dumper;
say "Result from getMe call:";
say Dumper($me->as_hashref);

$bot->think();
