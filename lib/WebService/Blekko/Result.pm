#

package WebService::Blekko::Result;

use strict;
use warnings;
no warnings qw( uninitialized );

=head1 NAME

WebService::Blekko::Result -- generic result from WebService::Blekko

=cut

our $VERSION = '1.00';

sub new
{
    my $class = shift;
    my $self = bless {}, $class;

    my ( $result, $error, $http_code ) = @_;

    $self->{result} = $result;
    $self->{error} = $error;
    $self->{http_code} = $http_code;

    return $self;
}

=head1 METHODS

=head2 result

=head2 error

=head2 http_code

=cut

# accessors

sub result
{
    my ( $self ) = @_;

    return $self->{result};
}

sub error
{
    my ( $self ) = @_;

    return $self->{error};
}

sub http_code
{
    my ( $self ) = @_;

    return $self->{http_code};
}

1;
