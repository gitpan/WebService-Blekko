#

use strict;
use warnings;
no warnings qw( uninitialized );

use Test::More tests => 8;

use List::MoreUtils qw( uniq );

use WebService::Blekko;

my $answer;

my $blekko = WebService::Blekko->new( auth => 'webservice-blekko-testing', );
my $badserver = WebService::Blekko->new( server => 'doesnotexist.blekko.com', auth => 'webservice-blekko-testing', );
my $redirserver = WebService::Blekko->new( server => 'www.blekko.com', scheme => 'http', auth => 'webservice-blekko-testing', );
my $four04server = WebService::Blekko->new( server => 'bugz.blekko.com', scheme => 'https', auth => 'webservice-blekko-testing', );

# logout

$answer = $blekko->logout();
ok( ! $answer->error, "logout from blekko" );
ok( $answer->result, "logout from blekko" );

# list

$answer = $blekko->list_urls( 'teaaasttag1' );
ok( $answer->error, "listing urls in non-existant teaaasttag1 fails" );
ok( ! $answer->result, "listing urls in non-existant teaaasttag1 fails" );

$answer = $blekko->list_urls( '/health' );
ok( ! $answer->error, "listing urls in /health succeeds" );
ok( $answer->result, "listing urls in /health succeeds" );

ok( ref $answer->result eq 'ARRAY', "list_slashtag returns an array ref" );
ok( scalar @{$answer->result} > 10, "/health has more than 10 urls" );

