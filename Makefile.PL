use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'WebService::Blekko',
    AUTHOR              => q{Greg Lindahl <greg@blekko.com>},
    VERSION_FROM        => 'lib/WebService/Blekko.pm',
    ABSTRACT_FROM       => 'lib/WebService/Blekko.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'JSON' => 0,
        'Time::HiRes' => 0,
        'LWP::UserAgent' => 0,
        'HTTP::Request' => 0,
        'List::Util' => 0,
        'Data::Dumper' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'WebService-Blekko-*' },
);
