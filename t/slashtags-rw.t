#

use strict;
use warnings;
no warnings qw( uninitialized );

use Test::More;

use List::MoreUtils qw( uniq );
use Data::Dumper;
use WebService::Blekko;

use LWP::Protocol;

eval "use YAML";
if ( $@ || ! LWP::Protocol::implementor( 'https' ) )
{
    plan skip_all => "No YAML or no https, no rw testing.";
    exit 0;
}

my $yaml_file = $ENV{SLASHTAGS_RW_CONFIG} || "$ENV{HOME}/.blekko-api-test";
if ( ! -f $yaml_file )
{
    plan skip_all => "No credentials file, skipping read/write slashtag testing";
    exit 0;
}

plan tests => 71;

my $yaml = YAML::LoadFile( $yaml_file );
my $server = $yaml->{server};
my $user = $yaml->{user};
my $password = $yaml->{password};

my $answer;

my $blekko = WebService::Blekko->new( server => $server,
                                      cookie_jar_file => '$ENV{HOME}/.blekkojson-cookies',
                                      auth => 'webservice-blekko-testing', );
my $badserver = WebService::Blekko->new( server => 'doesnotexist.blekko.com',
                                      cookie_jar_file => '$ENV{HOME}/.blekkojson-cookies',
                                      auth => 'webservice-blekko-testing', );
my $redirserver = WebService::Blekko->new( server => 'bugz.blekko.com',
                                      cookie_jar_file => '$ENV{HOME}/.blekkojson-cookies',
                                      auth => 'webservice-blekko-testing', );
my $four04server = WebService::Blekko->new( server => 'bugz.blekko.com', scheme => 'https',
                                      cookie_jar_file => '$ENV{HOME}/.blekkojson-cookies',
                                      auth => 'webservice-blekko-testing', );
my $nocookiejar = WebService::Blekko->new( server => 'doesnotexist.blekko.com',
                                      auth => 'webservice-blekko-testing', );

# login / logout

$answer = $nocookiejar->login( $user, $password );
ok( $answer->error, "login with nocookiejar fails" );
ok( ! $answer->result, "login with nocookiejar fails" );
ok( $answer->http_code == '200', "login with nocookiejar is 200" );

{
    local $TODO = "Causing HTTP::Message content not bytes at .../LWP/UserAgent.pm line 966";
    eval {
        $answer = $badserver->login( $user, $password );
    };
    ok( $answer->error, "login to badserver is error" );
    ok( ! $answer->result, "login to badserver is no result" );

    eval {
        $answer = $badserver->logout();
    };
    ok( $answer->error, "logout from badserver is error" );
    ok( ! $answer->result, "logout from badserver is no result" );
}

$answer = $redirserver->login( $user, $password );
ok( $answer->error, "login to redirserver is error" );
ok( ! $answer->result, "login to redirserver is no result" );

$answer = $redirserver->logout();
ok( $answer->error, "logout from redirserver is error" );
ok( ! $answer->result, "logout from redirserver is no result" );

$answer = $four04server->login( $user, $password );
ok( $answer->error, "login to four04server fails" );
ok( ! $answer->result, "login to four04server fails" );
ok( $answer->http_code =~ /^(404|301|302)/, "login to four04server is 404 or redir: got ".$answer->http_code );

$answer = $four04server->logout();
ok( $answer->error, "logout from four04server is error" );
ok( ! $answer->result, "logout from four04server is no result" );
ok( $answer->http_code =~ /^(404|301|302)/, "logout from four04server is 404 or redir: got ".$answer->http_code );

$answer = $blekko->login( $user, $password );
ok( ! $answer->error, "login to blekko no error" );
ok( $answer->result, "login to blekko result" );

$answer = $blekko->user_info();
ok( ! $answer->error, "user_info while logged in no error" );
ok( $answer->result eq $user, "user_info while logged in result" );

$answer = $blekko->logout();
ok( ! $answer->error, "logout from blekko no error" );
ok( $answer->result, "logout from blekkoresult" );

$answer = $blekko->user_info();
ok( $answer->error, "user_info while logged out is error" );
ok( ! $answer->result, "user_info while logged out no result" );

$answer = $blekko->logout();
ok( ! $answer->error, "logout twice from blekko no error" );
ok( $answer->result, "logout twice from blekko result" );

$answer = $blekko->login( $user, $password );
ok( $answer->result, "re-login to blekko no error" );
ok( ! $answer->error, "re-login to blekko result" );

# delete_urls / list / add_urls

my @urls = ( 'www.nytimes.com', 'www.huffingtonpost.com' );
my @fullurls = ( 'http://www.nytimes.com/', 'http://www.huffingtonpost.com/' );
my @temp;

# failures first
# XXX urls must be an array ref

$answer = $blekko->delete_urls( 'teaaaasttag1', \@urls );
ok( $answer->error, "deleting urls from non-existant teaaasttag1 is error" );
ok( ! $answer->result, "deleting urls from non-existant teaaasttag1 no result" );
$answer = $blekko->list_urls( 'teaaasttag1' );
ok( $answer->error, "listing urls in non-existant teaaasttag1 is error" );
ok( ! $answer->result, "listing urls in non-existant teaaasttag1 no result" );
$answer = $blekko->add_urls( 'teaaasttag1', \@urls );
ok( $answer->error, "adding urls to non-existing slashtag is error" );
ok( ! $answer->result, "adding urls to non-existing slashtag no result" );

$answer = $blekko->logout();
ok( ! $answer->error, "logout from blekko no errro" );
ok( $answer->result, "logout from blekko result" );

$answer = $blekko->delete_urls( 'testtag1', \@urls );
ok( $answer->error, "deleting urls fails while logged out is error" );
ok( ! $answer->result, "deleting urls fails while logged out no result" );
$answer = $blekko->add_urls( 'testtag1', \@urls );
ok( $answer->error, "adding urls fails while logged out is  error" );
ok( ! $answer->result, "adding urls fails while logged out no result" );

$answer = $blekko->login( $user, $password );
ok( ! $answer->error, "re-login to blekko no errro" );
ok( $answer->result, "re-login to blekko result" );

# now successes
# delete urls, just to be sure they aren't there, delete always succeeds

$answer = $blekko->delete_urls( 'testtag1', \@urls );
ok( ! $answer->error, "deleting urls from testtag1 no error" );
ok( $answer->result, "deleting urls from testtag1 result" );
$answer = $blekko->list_urls( 'testtag1' );
ok( ! $answer->error, "listing urls in testtag1 no error" );
ok( ref $answer->result eq 'ARRAY', "return value from list is array ref" );
@temp = @{$answer->result};
push @temp, @fullurls;
ok( scalar @{$answer->result} == scalar( uniq @temp ) - 2, "deleted urls are not in list of testtag1" );

# add urls

$answer = $blekko->add_urls( 'testtag1', \@urls );
ok( ! $answer->error, "adding urls to testtag1 no error" );
ok( $answer->result, "adding urls to testtag1 result" );
$answer = $blekko->list_urls( 'testtag1' );
ok( ! $answer->error, "listing urls in testtag1 no error" );
ok( ref $answer->result eq 'ARRAY', "return value from list is array ref" );
@temp = @{$answer->result};
push @temp, @fullurls;
ok( scalar @{$answer->result} == scalar( uniq @temp ), "added urls are in list in testtag1" );

# delete urls
# XXX urls must be an array ref

$answer = $blekko->delete_urls( 'testtag1', \@urls );
ok( ! $answer->error, "deleting urls from testtag1 no error" );
ok( $answer->result, "deleting urls from testtag1 result" );
$answer = $blekko->list_urls( 'testtag1' );
ok( ! $answer->error, "listing urls in testtag1 no error" );
ok( ref $answer->result eq 'ARRAY', "return value from list is array ref" );
@temp = @{$answer->result};
push @temp, @fullurls;
ok( scalar @{$answer->result} == scalar( uniq @temp ) - 2, "deleted urls are not in list of testtag1" );

$answer = $blekko->logout();
ok( ! $answer->error, "re-logout from blekko no error" );
ok( $answer->result, "re-logout from blekko result" );

# create_slashtag
# XXX illegal tag name
# XXX urls must be an array ref
# XXX logged in
# XXX tag already exists

$answer = $blekko->login( $user, $password );
ok( ! $answer->error, "re-login to blekko no error" );
ok( $answer->result, "re-login to blekko result" );
my $tagname = sprintf "tag%4.4d", int( rand( 9999 ) );
$answer = $blekko->create_slashtag( $tagname, \@urls, "A test tag" );
ok( ! $answer->error, "create_slashtag $tagname no error" );
ok( $answer->result, "create_slashtag $tagname result" );
$answer = $blekko->list_urls( $tagname );
ok( ! $answer->error, "listing urls in $tagname no error" );
ok( ref $answer->result eq 'ARRAY', "return value from list is array ref" );
ok( scalar @{$answer->result} == scalar @fullurls, "correct number of urls in $tagname" );

# remove_slashtag
{
    $TODO="Needs a bugfix";
    $answer = $blekko->remove_slashtag( $tagname );
    ok( ! $answer->error, "delete $tagname no error" );
    ok( $answer->result, "delete $tagname result" );
}
$answer = $blekko->remove_slashtag( $tagname );
ok( $answer->error, "delete $tagname twice fails error" );
ok( ! $answer->result, "delete $tagname twice fails no result" );

