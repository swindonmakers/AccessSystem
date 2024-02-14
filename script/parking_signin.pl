#!/usr/bin/perl

use local::lib '/usr/src/perl/libs/develop/perl5';
use 5.20.0;
use strictures 2;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);  # Set priority of root logger to ERROR

use WWW::Mechanize::Chrome;
use HTML::TreeBuilder;

my $reg = shift;

my $page_url = 'https://www.parkinggenie.co.uk/22959';

my $mech = WWW::Mechanize::Chrome->new(
    autoclose => 1,
    launch_exe => '/usr/bin/google-chrome-stable',
    host => 'localhost',

    background_networking => 0,
    autodie => 1,
    headless => 0,
    report_js_errors => 1,
    incognito => 1,
    );

$mech->get($page_url);
$mech->sleep(2);

$mech->wait_until_visible(
    selector => '#reg',
    timeout => 30
    );
sleep 1;
$mech->form_with_fields(
    'reg'
);
$mech->field('#reg', $reg);
$mech->click_button(value=>'Submit');


# my $resp = $mech->response;
# if(!$resp->is_success) {
#     die "Nope failed ", $resp->status_line, "\n", $resp->content;
# }

$mech->sleep(2);
# $mech->wait_until_visible(
#     selector => '#main',
#     timeout => 30,
#     );

my $tree = HTML::TreeBuilder->new_from_content($mech->content);
my $main = $tree->look_down('id' => 'main');
my @paras = $main->look_down('_tag' => 'p');

say "Parked: ";
say $_->as_text for @paras;
# Your parking exemption for AB11XXY is valid until Saturday, February 3, 2024 at 10:26.

# Your vehicle is a .


