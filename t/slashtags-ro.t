#

use strict;
use warnings;
no warnings qw( uninitialized );

use Test::More tests => 9;

use List::MoreUtils qw( uniq );

use WebService::Blekko;

use LWP::Protocol;
my $scheme = 'https';
$scheme = 'http' if ! LWP::Protocol::implementor($scheme);

my $answer;

eval {
	WebService::Blekko->new( auth => 'webservice-blekko-testing', scheme => 'not-a-valid-scheme' );
};
ok( scalar $@, "invalid scheme throws an exception" );

my $blekko = WebService::Blekko->new( auth => 'webservice-blekko-testing', );
my $badserver = WebService::Blekko->new( server => 'doesnotexist.blekko.com', auth => 'webservice-blekko-testing', );
my $redirserver = WebService::Blekko->new( server => 'www.blekko.com', scheme => 'http', auth => 'webservice-blekko-testing', );
my $four04server = WebService::Blekko->new( server => 'bugz.blekko.com', scheme => $scheme, auth => 'webservice-blekko-testing', );

# logout

$answer = $blekko->logout();
ok( ! $answer->error, "logout from blekko no error" );
ok( $answer->result, "logout from blekko result" );

# list

$answer = $blekko->list_urls( 'teaaasttag1' );
ok( $answer->error, "listing urls in non-existant teaaasttag1 gets error" );
ok( ! $answer->result, "listing urls in non-existant teaaasttag1 no result" );

$answer = $blekko->list_urls( '/health' );
ok( ! $answer->error, "listing urls in /health no error" );
ok( $answer->result, "listing urls in /health result" );

ok( ref $answer->result eq 'ARRAY', "list_slashtag returns an array ref" );
ok( scalar @{$answer->result} > 10, "/health has more than 10 urls" );

