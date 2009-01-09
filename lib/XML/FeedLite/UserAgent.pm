#########
# Author:        rmp@psyphi.net
# Maintainer:    rmp@psyphi.net
# Created:       2006-06-08
# Last Modified: $Date: 2009/01/09 14:38:54 $
# Id:            $Id: UserAgent.pm,v 1.3 2009/01/09 14:38:54 zerojinx Exp $
# Source:        $Source: /cvsroot/xml-feedlite/xml-feedlite/lib/XML/FeedLite/UserAgent.pm,v $
# $HeadURL$
#
package XML::FeedLite::UserAgent;
use strict;
use warnings;
use LWP::Parallel::UserAgent;
use base qw(LWP::Parallel::UserAgent);
use XML::FeedLite::UserAgent::proxy;

our $VERSION  = do { my @r = (q$Revision: 1.3 $ =~ /\d+/smxg); sprintf '%d.'.'%03d' x $#r, @r };

sub new {
  my ($class, %args) = @_;
  my $self = LWP::Parallel::UserAgent->new(%args);
  bless $self, $class;
  $self->{'http_proxy'} = $args{'http_proxy'}; # || $ENV{'http_proxy'};
  return $self;
}

sub _need_proxy {
  my $self = shift;
  $self->{'http_proxy'} or return;
  my ($scheme, $host, $port) = $self->{'http_proxy'} =~ m{(https?)://([^:\#\?/]+):?(\d+)?}smx;
  $host or return;
  my $proxy = {
	       'host'   => $host,
	       'port'   => $port   || '3128',
	       'scheme' => $scheme || 'http',
	      };
  bless $proxy, 'XML::FeedLite::UserAgent::proxy';
  return $proxy;
}

sub on_failure {
  my ($self, $request, $response, $entry)   = @_;
  $self->{'statuscodes'}                  ||= {};
  $self->{'statuscodes'}->{$request->url()} = $response->status_line();
  return;
}

sub on_return {
  my @args = @_;
  return on_failure(@args);
}

sub statuscodes {
  my ($self, $url)         = @_;
  $self->{'statuscodes'} ||= {};
  return $url?$self->{'statuscodes'}->{$url}:$self->{'statuscodes'};
}

1;

__END__

=head1 NAME

XML::FeedLite::UserAgent

=head1 VERSION

$Revision: 1.3 $

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 new - Constructor

Call with whatever LWP::P::UA usually has

=head2 on_failure - internal error propagation method

=head2 on_return - internal error propagation method

=head2 statuscodes - helper for tracking response statuses keyed on url

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@psyphi.netE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2005 by Roger Pettett

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
