package AccessBot;

use Mojo::Base 'Telegram::Bot::Brain';
use Config::General;
use lib 'lib';
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
        my %mainconf = Config::General->new("$ENV{BOT_HOME}/accesssystem_api.conf")->getall();
        my $db_info = $mainconf{'Model::AccessDB'}{connect_info};
        $self->_db(AccessSystem::Schema->connect($db_info->{dsn}, $db_info->{user}, $db_info->{password}));
    }
    return $self->_db();
};

sub init {
    my $self = shift;
    $self->add_listener(\&read_message);
}

sub read_message {
    my ($self,$message) = @_;
    if($message->text =~ m{^/memberstats}) {
        my $data = $self->db->resultset('Person')->membership_stats;
        my $msg_text = "
Current members: " . ($data->{valid_members}{count} || 0) . " - (" . join(', ', map { "$_: " . ($data->{valid_members}{$_} || 0) } (qw/full concession otherspace adult child/)) . "),
Ex members: " . ($data->{ex_members}{count} || 0) . " - (" . join(', ', map { "$_: " . ($data->{ex_members}{$_} || 0) } (qw/full concession otherspace/)) . "),
Overdue members: " . ($data->{overdue_members}{count} || 0) ." - (" . join(', ', map { "$_: " . ($data->{overdue_members}{$_} || 0) } (qw/full concession otherspace/)) . "),
Left this month: " . ($data->{recent_expired}{count} || 0) ." - (" . join(', ', map { "$_: " . ($data->{recent_expired}{$_} || 0) } (qw/full concession otherspace/)) . ")";

        $message->reply($msg_text);
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
