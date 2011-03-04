#

package WebService::Blekko::QueryResultSet;

use strict;
use warnings;
no warnings qw( uninitialized );

=head1 NAME

WebService::Blekko::QueryResultSet -- query result from WebService::Blekko

=cut

our $VERSION = '1.00';

use WebService::Blekko::QueryResult;

sub new
{
    my $class = shift;
    my $self = bless {}, $class;

    my ( $json, $http_code ) = @_;

    $self->{http_code} = $http_code;

    if ( $http_code !~ /^2/ )
    {
        $self->{error} = "Remote webserver returned $http_code";
        $self->{total_num} = 0;
        return $self;
    }

    my $answer = WebService::Blekko::my_decode_json( $json );

    $self->{raw} = $answer;

    if ( defined $answer->{ERROR} )
    {
        # {suggesttag} doesn't ever seem to be useful
        $self->{error} = $answer->{ERROR}->{errstring};
    }

    foreach my $f ( qw( total_num RESULT sug_slash query_rewritten ) )
    {
        $self->{$f} = $answer->{$f};
    }

    if ( $self->{total_num} )
    {
        if ( ! ref $self->{RESULT} eq 'ARRAY' ||
             scalar @{$self->{RESULT}} != $self->{total_num} )
        {
            $self->{error} = "Internal error: total_num did not equal actual result count";
            $self->{total_num} = 0;
            return $self;
        }
    }

    $self->{next} = 0;

    return $self;
}

=head1 METHODS

=head2 next

Retrieves the next WebService::Blekko::QueryResult in the list.

=head2 error

Set to a non-zero string if there is an error.

=head2 http_code

The HTTP response code. If it is not 2XX, there was a problem.

=head2 total_num

The total number of possible results.

=head2 sug_slash

A list of suggested slashtags. For example, a search for Linus
Torvalds will return a list of suggestions such as /linux and
/tech. It is a good idea to show these suggestions to your users.

=head2 auto_slashtag

Under certain circumstances, blekko will add a slashtag to your query
term. For example, q=cure+for+headaches will auto-fire the /health
slashtag, and this will cause auto_slashtag to be set to the string '/health'.

If you wish to avoid auto-slashtag firing, add /web to the query,
i.e. q=cure+for+headaches+/web

=head2 auto_slashtag_query

When an auto slashtag is fired, sometimes we also change the query by
adding or dropping words. If so, auto_slashtag_query will be set to
a string with the final query terms.

=cut

sub next
{
    my ( $self ) = @_;

    return if $self->{next} >= $self->{total_num};

    return WebService::Blekko::QueryResult->new( @{$self->{RESULT}}[$self->{next}++] );
}

# accessors

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

sub total_num
{
    my ( $self ) = @_;

    return $self->{total_num};
}

sub sug_slash
{
    my ( $self ) = @_;

    return $self->{sug_slash};
}

sub auto_slashtag
{
    my ( $self ) = @_;

    return defined $self->{query_rewritten} ? $self->{query_rewritten}->{slashtag} : undef;
}

sub auto_slashtag_query
{
    my ( $self ) = @_;

    return defined $self->{query_rewritten} ? $self->{query_rewritten}->{new_q_str} : undef;
}

sub raw
{
    my ( $self ) = @_;

    return $self->{raw};
}

1;

