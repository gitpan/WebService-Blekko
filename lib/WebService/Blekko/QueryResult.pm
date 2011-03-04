#

package WebService::Blekko::QueryResult;

use strict;
use warnings;
no warnings qw( uninitialized );

=head1 NAME

WebService::Blekko::QueryResult -- a single result from WebService::Blekko::query

=cut

our $VERSION = '1.00';

sub new
{
    my $class = shift;
    my $self = bless {}, $class;

    $self->{result} = $_[0];

    return $self;
}

# accessors

=head1 METHODS

=head2 title

The title of this result, including HTML markup highlighting the
search terms.

=head2 snippet

A snippet from the result, including HTML markup.

=head2 url

The URL of the result.

=head2 display_url

The URL of the result, including HTML markup.

=cut

sub title
{
    my ( $self ) = @_;

    return $self->{result}->{url_title};
}

sub snippet
{
    my ( $self ) = @_;

    return $self->{result}->{snippet};
}

sub url
{
    my ( $self ) = @_;

    return $self->{result}->{url};
}

sub display_url
{
    my ( $self ) = @_;

    return $self->{result}->{display_url};
}

sub raw
{
    my ( $self ) = @_;

    return $self->{result};
}

1;
