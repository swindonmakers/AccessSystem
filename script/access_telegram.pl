#!/usr/bin/perl

use strict;
use warnings;
use feature 'say';

use lib "$ENV{BOT_HOME}/lib";
use AccessSystem::TelegramBot;

my $bot = AccessSystem::TelegramBot->new();

my $me = $bot->getMe();
use Data::Dumper;
say "Result from getMe call:";
say Dumper($me->as_hashref);
$bot->bot_name($me->as_hashref->{username});
$bot->me($me);
$bot->think();
