#

use strict;
use warnings;
no warnings qw( uninitialized );

use Test::More tests => 26;

use Time::HiRes;
use Data::Dumper;

use WebService::Blekko;

my $blekko = WebService::Blekko->new( pagesize => 34, scheme => 'http', qps => 1, auth => 'webservice-blekko-testing', );
my $badserver = WebService::Blekko->new( server => 'doesnotexist.blekko.com', auth => 'webservice-blekko-testing', );
my $redirserver = WebService::Blekko->new( server => 'www.blekko.com', scheme => 'http', auth => 'webservice-blekko-testing', );
my $four04server = WebService::Blekko->new( server => 'bugz.blekko.com', scheme => 'https', auth => 'webservice-blekko-testing', );

my $answer;
my $ok;
my $start = Time::HiRes::time;

# failures

$answer = $badserver->query( "obama" );
ok( $answer->error, "bad server: error" );
ok( ! $answer->next, "bad server: no results" );

$answer = $redirserver->query( "obama" );
ok( $answer->error, "redir server: error" );
ok( ! $answer->next, "redir server: no results" );
ok( $answer->http_code =~ /^3/, "redir server: redir seen: got ".$answer->http_code );

$answer = $four04server->query( "obama" );
ok( $answer->error, "404 server: error" );
ok( ! $answer->next, "404 server: no results" );
ok( $answer->http_code =~ /^(4|301|302)/, "404 server: 4xx or redir seen: got ".$answer->http_code );

my $rand = int( rand( 1_000_000 ) );
$answer = $blekko->query( "obamarh$rand" );
ok( ! $answer->error, "random does-not-exist query: no error" );
ok( $answer->total_num == 0, "random does-not-exist query: 0 results" );
ok( ! $answer->next, "random does-not-exist query: no next result" );
ok( $answer->http_code eq '200', "random does-not-exist query: status is 200: got ".$answer->http_code );

# successes

$answer = $blekko->query( "obama" );

ok( ! $answer->error, "query: no error" );
ok( $answer->http_code eq '200', "query: status is 200: got ".$answer->http_code );
ok( $answer->total_num > 32, "query: got at least 32 of 34 results" ); # can be less than 34 for reasons too complicated to explain

ok( defined $answer->raw, "query: raw answer exists" );
$ok = 1;
foreach my $f qw( universal_total_results RESULT ERROR noslash_q q total_num )
{
    if ( ! exists $answer->raw->{$f} )
    {
        print STDERR "Missing ResultsSet field $f\n";
        $ok = 0 ;
    }
}
ok( $ok, "query: all advertised raw fields present" );

$ok = 1;
my $snippets = 0;
while ( my $r = $answer->next )
{
    $snippets++ if defined $r->raw->{snippet};
    foreach my $f qw( url c n_group url_title short_host )
    {
        if ( ! exists $r->raw->{$f} )
        {
            print STDERR "Missing Result field $f\n";
            $ok = 0;
        }
    }
}
ok( $ok, "query: all results have advertised raw fields" );
ok( $snippets > 30, "query: almost all results have raw snippets" );
# XXX test more accessors

# bogus slashtag gives error

$answer = $blekko->query( "obama /asdfasdf" );
ok( $answer->error =~ / is not valid/, "query: answer with bogus slashtag got error / is not valid/" );

# suggested slashtags

$answer = $blekko->query( "linus torvalds" );
ok( defined $answer->sug_slash, "linus torvalds: got slashtag suggestions" );
ok( ref $answer->sug_slash eq 'ARRAY', "linus torvalds: suggestions are an array ref" );
ok( scalar @{$answer->sug_slash} > 1, "linus torvalds: more than one suggestion" );

my $elapsed = Time::HiRes::time - $start;
ok( $elapsed >= 0.7, "2 calls in a row obeys qps, ish, elapsed = $elapsed" ); # this is an inexact measurement

# auto-slashtags

$answer = $blekko->query( "cure for headaches" );
ok( $answer->auto_slashtag eq "/blekko/health", "cure for headaches: query was rewritten with /health" );
ok( $answer->auto_slashtag_query eq "/ps=34 /json cure for headaches /health", "cure for headaches: saw the new query" );

