#

use strict;
use warnings;
no warnings qw( uninitialized );

use Test::More;

use List::MoreUtils qw( uniq );
use Data::Dumper;
use WebService::Blekko;

eval "use YAML";
if ( $@ )
{
    plan skip_all => "No YAML, no rw testing.";
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
    ok( $answer->error, "login to badserver fails" );
    ok( ! $answer->result, "login to badserver fails" );

    eval {
        $answer = $badserver->logout();
    };
    ok( $answer->error, "logout from badserver fails" );
    ok( ! $answer->result, "logout from badserver fails" );
}

$answer = $redirserver->login( $user, $password );
ok( $answer->error, "login to redirserver fails" );
ok( ! $answer->result, "login to redirserver fails" );

$answer = $redirserver->logout();
ok( $answer->error, "logout from redirserver fails" );
ok( ! $answer->result, "logout from redirserver fails" );

$answer = $four04server->login( $user, $password );
ok( $answer->error, "login to four04server fails" );
ok( ! $answer->result, "login to four04server fails" );
ok( $answer->http_code == '404', "login to four04server is 404" );

$answer = $four04server->logout();
ok( $answer->error, "logout from four04server fails" );
ok( ! $answer->result, "logout from four04server fails" );
ok( $answer->http_code == '404', "logout from four04server is 404" );

$answer = $blekko->login( $user, $password );
ok( ! $answer->error, "login to blekko" );
ok( $answer->result, "login to blekko" );

$answer = $blekko->user_info();
ok( ! $answer->error, "user_info while logged in" );
ok( $answer->result eq $user, "user_info while logged in" );

$answer = $blekko->logout();
ok( ! $answer->error, "logout from blekko" );
ok( $answer->result, "logout from blekko" );

$answer = $blekko->user_info();
ok( $answer->error, "user_info while logged out" );
ok( ! $answer->result, "user_info while logged out" );

$answer = $blekko->logout();
ok( ! $answer->error, "logout twice from blekko" );
ok( $answer->result, "logout twice from blekko" );

$answer = $blekko->login( $user, $password );
ok( $answer->result, "re-login to blekko" );
ok( ! $answer->error, "re-login to blekko" );

# delete_urls / list / add_urls

my @urls = ( 'www.nytimes.com', 'www.huffingtonpost.com' );
my @fullurls = ( 'http://www.nytimes.com/', 'http://www.huffingtonpost.com/' );
my @temp;

# failures first
# XXX urls must be an array ref

$answer = $blekko->delete_urls( 'teaaaasttag1', \@urls );
ok( $answer->error, "deleting urls from non-existant teaaasttag1 fails" );
ok( ! $answer->result, "deleting urls from non-existant teaaasttag1 fails" );
$answer = $blekko->list_urls( 'teaaasttag1' );
ok( $answer->error, "listing urls in non-existant teaaasttag1 fails" );
ok( ! $answer->result, "listing urls in non-existant teaaasttag1 fails" );
$answer = $blekko->add_urls( 'teaaasttag1', \@urls );
ok( $answer->error, "adding urls to non-existing slashtag" );
ok( ! $answer->result, "adding urls to non-existing slashtag" );

$answer = $blekko->logout();
ok( ! $answer->error, "logout from blekko" );
ok( $answer->result, "logout from blekko" );

$answer = $blekko->delete_urls( 'testtag1', \@urls );
ok( $answer->error, "deleting urls fails while logged out" );
ok( ! $answer->result, "deleting urls fails while logged out" );
$answer = $blekko->add_urls( 'testtag1', \@urls );
ok( $answer->error, "adding urls fails while logged out" );
ok( ! $answer->result, "adding urls fails while logged out" );

$answer = $blekko->login( $user, $password );
ok( $answer->result, "re-login to blekko" );
ok( ! $answer->error, "re-login to blekko" );

# now successes
# delete urls, just to be sure they aren't there, delete always succeeds

$answer = $blekko->delete_urls( 'testtag1', \@urls );
ok( $answer->result, "deleting urls from testtag1" );
ok( ! $answer->error, "deleting urls from testtag1" );
$answer = $blekko->list_urls( 'testtag1' );
ok( ! $answer->error, "listing urls in testtag1" );
ok( ref $answer->result eq 'ARRAY', "return value from list is array ref" );
@temp = @{$answer->result};
push @temp, @fullurls;
ok( scalar @{$answer->result} == scalar( uniq @temp ) - 2, "deleted urls are not in list of testtag1" );

# add urls

$answer = $blekko->add_urls( 'testtag1', \@urls );
ok( ! $answer->error, "adding urls to testtag1" );
ok( $answer->result, "adding urls to testtag1" );
$answer = $blekko->list_urls( 'testtag1' );
ok( ! $answer->error, "listing urls in testtag1" );
ok( ref $answer->result eq 'ARRAY', "return value from list is array ref" );
@temp = @{$answer->result};
push @temp, @fullurls;
ok( scalar @{$answer->result} == scalar( uniq @temp ), "added urls are in list in testtag1" );

# delete urls
# XXX urls must be an array ref

$answer = $blekko->delete_urls( 'testtag1', \@urls );
ok( $answer->result, "deleting urls from testtag1" );
ok( ! $answer->error, "deleting urls from testtag1" );
$answer = $blekko->list_urls( 'testtag1' );
ok( ! $answer->error, "listing urls in testtag1" );
ok( ref $answer->result eq 'ARRAY', "return value from list is array ref" );
@temp = @{$answer->result};
push @temp, @fullurls;
ok( scalar @{$answer->result} == scalar( uniq @temp ) - 2, "deleted urls are not in list of testtag1" );

$answer = $blekko->logout();
ok( $answer->result, "re-logout from blekko" );
ok( ! $answer->error, "re-logout from blekko" );

# create_slashtag
# XXX illegal tag name
# XXX urls must be an array ref
# XXX logged in
# XXX tag already exists

$answer = $blekko->login( $user, $password );
ok( $answer->result, "re-login to blekko" );
ok( ! $answer->error, "re-login to blekko" );
my $tagname = sprintf "tag%4.4d", int( rand( 9999 ) );
$answer = $blekko->create_slashtag( $tagname, \@urls, "A test tag" );
ok( $answer->result, "create_slashtag $tagname" );
ok( ! $answer->error, "create_slashtag $tagname" );
$answer = $blekko->list_urls( $tagname );
ok( ! $answer->error, "listing urls in $tagname" );
ok( ref $answer->result eq 'ARRAY', "return value from list is array ref" );
ok( scalar @{$answer->result} == scalar @fullurls, "correct number of urls in $tagname" );

# remove_slashtag
{
$TODO="Needs a bugfix";
$answer = $blekko->remove_slashtag( $tagname );
ok( $answer->result, "delete $tagname" );
ok( ! $answer->error, "delete $tagname" );
}
$answer = $blekko->remove_slashtag( $tagname );
ok( ! $answer->result, "delete $tagname twice fails" );
ok( $answer->error, "delete $tagname twice fails" );

