#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'WebService::Blekko' ) || print "Bail out!
";
}

diag( "Testing WebService::Blekko $WebService::Blekko::VERSION, Perl $], $^X" );
