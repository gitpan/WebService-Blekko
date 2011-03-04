#

package WebService::Blekko::Pagestats;

use strict;
use warnings;
no warnings qw( uninitialized );

=head1 NAME

WebService::Blekko::Pagestats -- results from WebService::Blekko::pagestats

=head1 DESCRIPTION

These results are similar to the information which drives the various buttons
in the blekko search engine results for every URL.

=cut

our $VERSION = '1.00';

sub new
{
    my $class = shift;
    my $self = bless {}, $class;

    my ( $json, $error, $http_code ) = @_;

    $self->{http_code} = $http_code;
    $self->{error} = $error;

    my $answer = WebService::Blekko::my_decode_json( $json ); # XXX needs eval?

    $self->{raw} = $answer;

    foreach my $f ( qw( host_inlinks host_rank adsense cached dup ip rss ) )
    {
        $self->{$f} = $answer->{$f};
    }

    return $self;
}

# accessors

=head1 METHODS

=head2 http_code

=head2 error

=head2 host_inlinks

An approximate count of the number of incoming links to this host

=head2 host_rank

blekko's rank for the host

=head2 adsense

The adsense ID observed on this page,

=head2 cached

True if blekko has a cached copy of this page. Use a query of the
URL /cache to display the cache.

=head2 dup

True if we think there is duplicate info on the page.

=head2 ip

The IP address blekko crawled for this website. Can be used
to query blekko for all websites observed on this IP address.

=head2 rss

Set if we observe an rss feed on this URL.

=cut

sub http_code
{
    my ( $self ) = @_;

    return $self->{http_code};
}

sub error
{
    my ( $self ) = @_;

    return $self->{error};
}

sub host_inlinks
{
    my ( $self ) = @_;

    return $self->{host_inlinks};
}

sub host_rank
{
    my ( $self ) = @_;

    return $self->{host_rank};
}

sub adsense
{
    my ( $self ) = @_;

    return $self->{adsense};
}

sub cached
{
    my ( $self ) = @_;

    return $self->{cached};
}

sub dup
{
    my ( $self ) = @_;

    return $self->{dup};
}

sub ip
{
    my ( $self ) = @_;

    return $self->{ip};
}

sub rss
{
    my ( $self ) = @_;

    return $self->{rss};
}

sub raw
{
    my ( $self ) = @_;

    return $self->{raw};
}

1;

