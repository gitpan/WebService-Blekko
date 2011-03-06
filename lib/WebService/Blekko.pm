#

package WebService::Blekko;

=head1 NAME

WebService::Blekko - access the Blekko JSON APIs

=cut

use strict;
use warnings;
no warnings qw( uninitialized );

use LWP::UserAgent;
use HTTP::Request;
use List::Util qw( min );
use Time::HiRes;
use JSON;

use Data::Dumper;

use WebService::Blekko::QueryResultSet;
use WebService::Blekko::Pagestats;
use WebService::Blekko::Result;

our $VERSION = '1.00_04';

my $useragent = __PACKAGE__ . '_' . $VERSION;

=head1 SYNOPSIS

 use WebService::Blekko;

 my $blekko = WebService::Blekko->new( auth => 'webservice-blekko-example', );

 $res = $blekko->query( "obama /date" );

 if ( $res->error ) { ... }

 while ( my $r = $res->next ) {
    print $r->url, $r->title; # etc.
 }

=head1 DESCRIPTION

 This API wraps the Blekko search engine API(s). You can query for results,
 manipulate slashtags, get tool-bar-useful information, and so forth.

 For the Terms and Conditions for using Blekko data, please see

 https://blekko.com/ws/+/terms
 and
 https://blekko.com/ws/+/apiterms

 To get an API Auth key, please contact apiauth@blekko.com

=head1 METHODS

=head2 new( %opts )

Options include

 server => server to talk to, defaults to blekko.com
 auth => api auth key, gotten by contacting apiauth@blekko.com
 source => the name of your program/service
 pagesize => number of results to return, default 20, max of 100
 scheme => http, defaults to https
 qps => API calls per second, defaults to 1. Do not make this greater than 1 without asking.
 agent => the user-agent to be used by LWP::UserAgent. Defaults to the package name_version.

 cookie_jar_file => cookie jar file to use, see LWP::UserAgent
 cookie_jar => cookie jar object to use, see LWP::UserAgent

Additional options are passed to LWP::UserAgent.

=cut

sub new
{
    my $class = shift;
    my $self = bless {}, $class;

    my %opts = @_;

    $self->{server} = delete $opts{server} || 'blekko.com';
    $self->{auth} = delete $opts{auth} || die "Must specify auth in opts";
    $self->{auth} = "&auth=$self->{auth}";
    $self->{source} = delete $opts{source} || $useragent;
    $self->{source} = "&source=$self->{source}";
    $self->{pagesize} = delete $opts{pagesize};
    $self->{scheme} = delete $opts{scheme} || 'https';
    $self->{qps} = min( delete $opts{qps} || 1, 1 );
    $self->{last_query} = 0;

    $opts{agent} = $opts{agent} || $useragent;
    my $cjf = delete $opts{cookie_jar_file};
    my $cj = delete $opts{cookie_jar};
    $opts{max_redirect} ||= 0; # don't follow redirects

    # remaining opts are for LWP::UserAgent... default timeout is 180 seconds, yuck.

    $self->{ua} = LWP::UserAgent->new( %opts );
    return if ! defined $self->{ua};

    $self->{ua}->cookie_jar( { file => $cjf }, autosave => 1, ) if defined $cjf;
    $self->{ua}->cookie_jar( $cj ) if defined $cj;

    $self->{have_cookie_jar} = 1 if defined $cjf || defined $cj;

    return $self;
}

=head2 query( query_string )

Queries the server, and returns a WebService::Blekko::QueryResultSet.

=cut

sub query
{
    my ( $self, $q ) = @_; # XXX opts

    my $template = "%s://%s/ws/?q=%s%s%s";
    my $ps = '';
    $ps = "/ps=$self->{pagesize} " if $self->{pagesize};

    my $url = sprintf( $template, $self->{scheme}, $self->{server},
                       urlencode( "$ps/json $q" ), $self->{auth}, $self->{source} );
    # XXX opts to set page number

    my $req = HTTP::Request->new( 'GET', $url );
    $self->query_sleep();
    my $resp = $self->{ua}->request( $req );

    return WebService::Blekko::QueryResultSet->new( $resp->content, $resp->code );
}

=head2 pagestats( url )

Returns information about a webpage, suitable for toolbar use. Returns
a WebService::Blekko::Pagestats object, with methods host_inlinks, host_rank, etc.

=cut

sub pagestats
{
    my ( $self, $url ) = @_;

    if ( $url !~ m,^https?://,i )
    {
        return WebService::Blekko::Pagestats->new( undef, "url must start with http://", 200 );
    }

    my $template = "%s://%s/api/pagestats?url=%s%s%s";
    $url = sprintf( $template, $self->{scheme}, $self->{server}, $url, $self->{auth}, $self->{source} );

    my $req = HTTP::Request->new( 'GET', $url );
    $self->query_sleep();
    my $resp = $self->{ua}->request( $req );

    if ( ! $resp->is_success )
    {
        return WebService::Blekko::Pagestats->new( undef, "http failure, code is ".$resp->code, $resp->code );
    }

    return WebService::Blekko::Pagestats->new( $resp->content, 0, $resp->code );
}

=head2 login( username, password )

Logs into blekko, which is needed before you create/add to/delete slashtags. Requires
a cookie jar file or object to work.

Returns WebService::Blekko::Result, which has methods error, result,
and http_code. Check error before using result.

=cut

sub login
{
    my ( $self, $username, $password ) = @_; # opts

    if ( ! $self->{have_cookie_jar} )
    {
        return WebService::Blekko::Result->new( 0, "No cookie jar configured. Read the WebServer::Blekko docs.", 200 );
    }

    my $template = "https://%s/login?u=%s&p=%s%s%s"; # forced to https
    my $url = sprintf( $template, $self->{server}, $username, $password, $self->{auth}, $self->{source} );

    my $req = HTTP::Request->new( 'GET', $url );
    $self->query_sleep();
    my $resp = $self->{ua}->request( $req );

    if ( ! $resp->is_success )
    {
        return WebService::Blekko::Result->new( '', "http failure, code is ".$resp->code, $resp->code );
    }

    my $answer = my_decode_json( $resp->content ); # XXX does this need an eval?

    if ( defined $answer->{status} && $answer->{status} )
    {
        return WebService::Blekko::Result->new( 1, 0, $resp->code );
    }

    return WebService::Blekko::Result->new( 0, 'Login failed', $resp->code );
}

=head2 logout()

Logs out of blekko. Does not throw an error if you are already logged out.

=cut

sub logout
{
    my ( $self ) = @_;

    my $url = "$self->{scheme}://$self->{server}/logout";

    my $req = HTTP::Request->new( 'GET', $url );

    $self->query_sleep();
    my $resp = $self->{ua}->request( $req );

    # redir is success
    if ( $resp->is_redirect )
    {
        return WebService::Blekko::Result->new( 1, 0, $resp->code );
    }

    return WebService::Blekko::Result->new( 0, 'Logout failed', $resp->code );
}

=head2 user_info()

Returns the username of the currently logged-in user. Useful in
toolbars, where the user logs directly into blekko.

=cut

sub user_info
{
    my ( $self ) = @_;

    my $url = "$self->{scheme}://$self->{server}/api/userinfo";

    my $req = HTTP::Request->new( 'GET', $url );

    $self->query_sleep();
    my $resp = $self->{ua}->request( $req );

    if ( ! $resp->is_success )
    {
        return WebService::Blekko::Result->new( '', "http failure, code is ".$resp->code, $resp->code );
    }

    my $answer = my_decode_json( $resp->content ); # XXX does this need an eval?

    if ( defined $answer->{username} && $answer->{username} )
    {
        return WebService::Blekko::Result->new( $answer->{username}, 0, $resp->code );
    }

    return WebService::Blekko::Result->new( 0, 'Login failed', $resp->code );
}

=head2 create_slashtag( $slashtag, \@urls, $description )

Creates a slashtag.

=cut

sub create_slashtag
{
    my $self = shift;
    return $self->createupdate( "create", @_ );
}

=head2 add_urls( $slashtag, \@urls )

Adds urls to an existing slashtag.

=cut

sub add_urls
{
    my $self = shift;
    return $self->createupdate( "update", @_, undef );
}

sub createupdate
{
    my ( $self, $createupdate, $slashtag, $urls, $desc ) = @_; # XXX opts... at least urls is an array ref...

    if ( defined $urls && ref $urls ne 'ARRAY' )
    {
        return WebService::Blekko::Result->new( 0, "\$urls must be an array ref", 200 );
    }

    my $urls_string = '';
    $urls_string = "&urls=" . join( '%0A', @$urls ) if ( @$urls );
    $desc = $desc ? "&desc=$desc" : '';

    my $template = "%s://%s/tag/add?name=%s&submit=%s%s%s%s%s";
    my $url = sprintf( $template, $self->{scheme}, $self->{server}, $slashtag, $createupdate,
                       $urls_string, $desc, $self->{auth}, $self->{source} );

    my $req = HTTP::Request->new( 'GET', $url );
    $self->query_sleep();
    my $resp = $self->{ua}->request( $req );

    if ( $resp->is_redirect )
    {
        if ( $createupdate eq "create" )
        {
            return WebService::Blekko::Result->new( 0, "You are not logged in, or tag already exists", 200 );
        }
        else
        {
            return WebService::Blekko::Result->new( 0, "You are not logged in", 200 );
        }
    }

    if ( ! $resp->is_success )
    {
        return WebService::Blekko::Result->new( 0, "http failure, code is ".$resp->code, $resp->code );
    }

    if ( $resp->content ne '' )
    {
        return WebService::Blekko::Result->new( 0, "Error: ".$resp->content, $resp->code );
    }

    return WebService::Blekko::Result->new( 1, 0, $resp->code );
}

=head2 list_urls( $slashtag )

Returns an arrayref of the urls in the slashtag

=cut

sub list_urls
{
    my ( $self, $slashtag ) = @_; # XXX opts

    my $template = "%s://%s/tag/view?name=%s&format=text%s%s";
    my $url = sprintf( $template, $self->{scheme}, $self->{server}, $slashtag, $self->{auth}, $self->{soure} );

    my $req = HTTP::Request->new( 'GET', $url );
    $self->query_sleep();
    my $resp = $self->{ua}->request( $req );

    if ( ! $resp->is_success )
    {
        return WebService::Blekko::Result->new( 0, "http failure, code is ".$resp->code, $resp->code );
    }

    # if error, html is returned, even though we said 'format=text'
    # future proofed by also considering 'Error:' to indicate an error
    if ( substr( $resp->content, 0, 1 ) eq '<' || substr( $resp->content, 0, 6 ) eq 'Error:' )
    {
        return WebService::Blekko::Result->new( 0, "No such slashtag or other error", $resp->code );
    }

    my @answer = split /\n/, $resp->content;

    return WebService::Blekko::Result->new( \@answer, 0, $resp->code );
}

=head2 delete_urls( $slashtag, \@urls )

Deletes urls in a slashtag.

=cut

# XXX also &tags= to delete subtags in a slashtag

sub delete_urls
{
    my ( $self, $slashtag, $urls ) = @_; # XXX opts

    if ( defined $urls && ref $urls ne 'ARRAY' )
    {
        return WebService::Blekko::Result->new( 0, "\$urls must be an array ref", 200 );
    }

    my $urls_string = '';
    $urls_string = "&urls=" . join( '%0A', @$urls ) if ( @$urls );

    my $template = "%s://%s/tag/edit?submit=1&type=del&name=%s%s%s%s";
    my $url = sprintf( $template, $self->{scheme}, $self->{server}, $slashtag, $urls_string, $self->{auth}, $self->{source} );

    my $req = HTTP::Request->new( 'GET', $url );
    $self->query_sleep();
    my $resp = $self->{ua}->request( $req );

    if ( ! $resp->is_success )
    {
        return WebService::Blekko::Result->new( 0, "http failure, code is ".$resp->code, $resp->code );
    }

    # this always returns javascript :-/ so key off css
    # XXX future-proof me
    if ( $resp->content =~ /alertMsgError/ )
    {
        return WebService::Blekko::Result->new( 0, "No such slashtag or other error", $resp->code );
    }

    return WebService::Blekko::Result->new( 1, 0, $resp->code );
}

=head2 remove_slashtag( $slashtag )

Removes a slashtag.

=cut

sub remove_slashtag
{
    my ( $self, $slashtag ) = @_; # XXX opts

    my $template = "%s://%s/tag/delete?submit=1&name=%s%s%s";
    my $url = sprintf( $template, $self->{scheme}, $self->{server}, $slashtag, $self->{auth}, $self->{source} );

    my $req = HTTP::Request->new( 'GET', $url );
    $self->query_sleep();
    my $resp = $self->{ua}->request( $req );

    if ( ! $resp->is_success )
    {
        return WebService::Blekko::Result->new( 0, "http failure, code is ".$resp->code, $resp->code );
    }

    if ( $resp->content =~ /alertMsgErr/ )
    {
        return WebService::Blekko::Result->new( 0, "Error", $resp->code );
    }

    if ( $resp->content =~ / has been deleted/ )
    {
        return WebService::Blekko::Result->new( 1, 0, $resp->code );
    }

    return WebService::Blekko::Result->new( 0, "Did not see success", $resp->code );
}

# poor man's request rate limiter

sub query_sleep
{
    my ( $self ) = @_;

    my $now = Time::HiRes::time;
    my $delta = 1. / ( $self->{qps} || 1 );

    if ( $now - $self->{last_query} < $delta )
    {
        my $s = $self->{last_query} + $delta - $now;
        Time::HiRes::sleep( $s );
        $self->{last_query} = Time::HiRes::time;
    }
    else
    {
        $self->{last_query} = $now;
    }
}

# ----------------------------------------------------------------------
# to go away
# ----------------------------------------------------------------------

my %escapes;
for (0..255)
{
    $escapes{chr($_)} = sprintf("%%%02X", $_);
}
$escapes{' '} = '+';

sub urlencode
{
    my $url = shift;

    $url =~ s/([^A-Za-z0-9\-_.!~*\'()])/$escapes{$1}/ge if defined $url;
    return $url;
}

# keep the JSON::Boolean bs down to a minimum -- why isn't this an option in JSON?
# I can't be the only person using JSON for non-roundtrip purposes.
sub my_decode_json
{
    my ( $string ) = @_;

    return if ! defined $string || $string eq '';

    my $ret = decode_json( $string ); # XXX needs eval?

    if ( $ret && ref $ret eq 'HASH' )
    {
        foreach my $k ( keys %$ret )
        {
            my $it = $ret->{$k};
            if ( UNIVERSAL::isa( $it, 'JSON::Boolean' ) )
            {
                $ret->{$k} = 1 if $it eq $JSON::true;
                $ret->{$k} = 0 if $it eq $JSON::false;
            }
        }
    }
    return $ret;
}

=head1 SEE ALSO

 L<WebService::Yahoo::BOSS>, L<Google::Search>

=head1 AUTHOR

"Greg Lindahl", E<lt>greg@blekko.comE<gt>

Thanks to Fred Moyer for commenting on the interfaces.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by blekko, inc.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.12.3 or,
at your option, any later version of Perl 5 you may have available.

=cut

1;

