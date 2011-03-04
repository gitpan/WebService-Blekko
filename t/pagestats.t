#

use strict;
use warnings;
no warnings qw( uninitialized );

use Test::More tests => 20;

use Time::HiRes;

use WebService::Blekko;

my $blekko = WebService::Blekko->new( auth => 'webservice-blekko-testing', );
my $answer;
my $ok;
my $start;
my $elapsed;

# pagestats

$answer = $blekko->pagestats( "yahoo.com" );
ok( $answer->error, "pagestats of invalid url returns error" );
ok( $answer->http_code, "pagestats of invalid url returns 200" );

$start = Time::HiRes::time;
$answer = $blekko->pagestats( "http://yahoo.com" );
ok( ! $answer->error, "pagestats of valid url is not an error" );
ok( $answer->http_code eq '200', "pagestats status is 200" );
ok( $answer->host_inlinks > 1_000_000, "pagestats: yahoo.com has inlinks" ); # XXX add isnum
ok( $answer->host_rank > 1, "pagestats: yahoo.com is popular" ); # XXX add isnum
ok( ! $answer->adsense, "pagestats: yahoo.com isn't running Google ads" );
ok( $answer->ip =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/, "pagestats: yahoo.com has a valid IP" );
ok( $answer->cached, "pagestats: yahoo.com is cached" );

$ok = 1;
foreach my $f ( qw( adsense cached dup host_inlinks host_rank ip rss ) )
{
    $ok = 0 if ! exists $answer->raw->{$f};
}
ok( $ok, "pagestats: all advertised raw fields present" );

$answer = $blekko->pagestats( "http://yahoo.comasdfasdf" );
ok( ! $answer->error, "pagestats doesnotexist is not an error" );
ok( $answer->http_code eq '200', "pagestats status is 200 for doesnotexist" );
ok( $answer->host_inlinks == 0, "pagestats: doesnotexist has 0 inlinks" ); # XXX add isnum
ok( $answer->host_rank == 0, "pagestats: doesnotexist is not popular" ); # XXX add isnum
ok( ! $answer->adsense, "pagestats: doesnotexist is not running Google ads" );
ok( ! $answer->ip, "pagestats: doesnotexist does not have an IP address" );
ok( ! $answer->cached, "pagestats: doesnotexist is not cached" );
ok( ! $answer->dup, "pagestats: doesnotexist is not duplicated off-site" );

$elapsed = Time::HiRes::time - $start;
ok( $elapsed >= 0.5, "2 calls in a row obeys qps, ish, actual elapsed = $elapsed" ); # this is an inexact measurement

$ok = 1;
foreach my $f ( qw( adsense cached dup host_inlinks host_rank ip rss ) )
{
    $ok = 0 if ! exists $answer->raw->{$f};
}
ok( $ok, "pagestats doesnotexist: all advertised raw fields present" );

# XXX test more accessors

