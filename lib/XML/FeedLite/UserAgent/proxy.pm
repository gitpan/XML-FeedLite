#########
# Author:        rmp@psyphi.net
# Maintainer:    rmp@psyphi.net
# Created:       2006-06-08
# Last Modified: $Date: 2007/07/16 21:31:47 $
# Id:            $Id: proxy.pm,v 1.1 2007/07/16 21:31:47 zerojinx Exp $
# Source:        $Source: /cvsroot/xml-feedlite/xml-feedlite/lib/XML/FeedLite/UserAgent/proxy.pm,v $
# $HeadURL$
#
package XML::FeedLite::UserAgent::proxy;
use strict;
use warnings;

our $VERSION  = do { my @r = (q$Revision: 1.1 $ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };

sub host     { return $_[0]->{'host'}; }
sub port     { return $_[0]->{'port'}; }
sub scheme   { return $_[0]->{'scheme'}; }

#########
# userinfo, presumably for authenticating to the proxy server.
# Not sure what format this is supposed to be (username:password@ ?)
# Things fail silently if this isn't present.
#
sub userinfo { return q(); }

1;

__END__

=head1 NAME

=head1 VERSION

$Revision: 1.1 $

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 host - get/set host

=head2 port - get/set port

=head2 scheme - get/set scheme

=head2 userinfo - stub for authentication? Stops LWP::P::UA from silently failing

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
