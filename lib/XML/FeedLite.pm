#########
# Author:        rmp@psyphi.net
# Maintainer:    rmp@psyphi.net
# Created:       2006-06-08
# Last Modified: $Date: 2009/01/09 14:38:54 $
# Id:            $Id: FeedLite.pm,v 1.8 2009/01/09 14:38:54 zerojinx Exp $
# Source:        $Source: /cvsroot/xml-feedlite/xml-feedlite/lib/XML/FeedLite.pm,v $
# $HeadURL$
#
package XML::FeedLite;
use strict;
use warnings;
use XML::FeedLite::UserAgent;
use HTTP::Request;
use HTTP::Headers;
use HTML::Entities;
use MIME::Base64;
use English qw(-no_match_vars);
use Carp;
use Readonly;

our $VERSION  = do { my @r = (q$Revision: 1.8 $ =~ /\d+/smxg); sprintf '%d.'.'%03d' x $#r, @r };
our $DEBUG    = 0;
Readonly::Scalar our $BLK_SIZE => 8192;
Readonly::Scalar our $TIMEOUT  => 30;
Readonly::Scalar our $MAX_REQ  => 5;

our $PATTERNS = {
		 'ENTRIES' => {
			       'atom' => qr{<entry[^>]*>(.*?)</entry>}smix,
			       'rss'  => qr{<item(?:\ [^>]*|)>(.*?)</item>}smix,
			      },
		 'META'    => {
			       'atom' => {
					  'title' => qr{<feed.*?<title[^>]*>(.*?)</title>}smix,
					 },
			       'rss'  => {
					  'title' => qr{<channel.*?<title[^>]*>(.*?)</title.*?</channel>}smix,
					 },
			      },
		};


sub new {
  my ($class, $ref) = @_;
  my $self = {
	      'url'     => [],
	      'timeout' => $TIMEOUT,
	      'data'    => {},
	     };

  bless $self, $class;

  if($ref && (ref $ref eq 'HASH')) {
    for my $arg (qw(url timeout http_proxy proxy_user proxy_pass user_agent)) {
       if(defined $ref->{$arg} && $self->can($arg)) {
	 $self->$arg($ref->{$arg});
       }
    }

  } elsif($ref) {
    $self->url($ref);
  }

  return $self;
}

sub http_proxy {
  my ($self, $proxy)    = @_;
  $proxy and $self->{'http_proxy'} = $proxy;

  if(!$self->{'_checked_http_proxy_env'}) {
    $self->{'http_proxy'} ||= $ENV{'http_proxy'};
    $self->{'_checked_http_proxy_env'} = 1;
  }

  $self->{'http_proxy'} ||= q();

  if($self->{'http_proxy'} =~ m{^(https?://)(\S+):(.*?)\@(.*?)$}smx) {
    #########
    # http_proxy contains username & password - we'll set them up here:
    #
    $self->proxy_user($2);
    $self->proxy_pass($3);

    $self->{'http_proxy'} = "$1$4";
  }

  return $self->{'http_proxy'};
}

sub _accessor {
  my ($self, $field, $val) = @_;
  $val and $self->{$field} = $val;
  return $self->{$field};
}

sub proxy_user {
  my ($self, @args) = @_;
  return $self->_accessor('proxy_user', @args);
}

sub proxy_pass {
  my ($self, @args) = @_;
  return $self->_accessor('proxy_pass', @args);
}

sub user_agent {
  my ($self, @args) = @_;
  return $self->_accessor('user_agent', @args) || "XML::FeedLite v$VERSION";
}

sub timeout {
  my ($self, @args) = @_;
  return $self->_accessor('timeout', @args);
}

sub url {
  my ($self, $url) = @_;

  if($url) {
    $self->reset();

    if(ref $url eq 'ARRAY') {
      $self->{'url'} = $url;

    } else {
      $self->{'url'} = [$url];
    }
  }

  return $self->{'url'};
}

sub reset { ## no critic
  my $self = shift;
  delete $self->{'results'};
  delete $self->{'feedmeta'};
  delete $self->{'data'};
  return;
}

sub entries {
  my ($self, $url, $opts) = @_;

  if(exists $self->{'results'}) {
    return $self->{'results'};
  }

  my $results   = {};
  my $ref       = {};
  my $ar_url    = [];

  if($url && $opts) {
    if(ref $url) {
      $ar_url = $url;
    } else {
      $ar_url = [$url];
    }
  } else {
    $ar_url = $self->url();
    $opts   = $url;
  }
  $opts ||= {};

  for my $s_url (grep { $_ } @{$ar_url}) {
    #########
    # loop over urls to fetch
    #
    $results->{$s_url}            = [];
    $self->{'feedmeta'}->{$s_url} = {};

    $ref->{$s_url} = sub {
      my $blk = shift;
      $self->{'data'}->{$s_url} .= $blk;

      if(!$self->{'format'}->{$s_url}) {
	if($blk =~ m{xmlns="https?://[a-z\d\.\-/]+/atom}smix) {
	  $self->{'format'}->{$s_url} = 'atom';

	} elsif($blk =~ m{xmlns="https?://[a-z\d\.\-/]+/rss}smix) {
	  $self->{'format'}->{$s_url} = 'rss';

	} elsif($blk =~ m{rss\s+version\s*=\s*"2.0"}smix) {
	  $self->{'format'}->{$s_url} = 'rss';
	}
      }

      my $feedmeta = $self->{'feedmeta'}->{$s_url};
      for my $f (keys %{$PATTERNS->{'META'}->{$self->{'format'}->{$s_url}}}) {
	if($feedmeta->{$f}) {
	  next;
	}

	my $pat = $PATTERNS->{'META'}->{$self->{'format'}->{$s_url}}->{$f};
	($feedmeta->{$f}) = $blk =~ /$pat/smx;
      }

      my $pat = $PATTERNS->{'ENTRIES'}->{$self->{'format'}->{$s_url}};
      if(!$pat) {
	carp qq(No pattern defined for url=$s_url fmt=@{[$self->{'format'}->{$s_url}||'unknown']});
	return;
      }

      while($self->{'data'}->{$s_url} =~ s/$pat//smx) {
	$self->_parse_entry($results->{$s_url}, $1);
      }
      return;
    };
  }

  $self->fetch($ref, $opts->{'headers'});

  $DEBUG and print {*STDERR} qq(Content retrieved\n);

  $self->{'results'} = $results;
  return $results;
}

sub _parse_entry {
  my ($self, $results, $blk) = @_;
  my $entry = {};
  $blk    ||= q();

  my $pat = qr{(<([a-z:]+)([^>]*)>(.*?)</\2>|<([a-z:]+)([^>]*)/>)}smix;
  while($blk =~ s{$pat}{}smx) {

    my ($tag, $attr, $content);
    if($4) {
      ($tag, $attr, $content) = ($2, $3, $4);

    } else {
      ($tag, $attr) = ($5, $6)
    }

    my $tagdata   = {};
    $attr       ||= q();

    while($attr =~ s{(\S+)\s*=\s*["']([^"']*)["']}{}smx) {
      if($2) {
	$tagdata->{$1} = $2;
      }
    }

    if($content) {
      my $mode = $tagdata->{'mode'} || q();

      if($mode eq 'escaped') {
	$content = decode_entities($content);

      } elsif($mode eq 'base64') {
	$content = decode_base64($content);
      }

      $tagdata->{'content'} = $content;
    }

    if(scalar keys %{$tagdata}) {
      push @{$entry->{$tag}}, $tagdata;
    }
  }

  push @{$results}, $entry;
  return q();
}

sub meta {
  my ($self, $feed) = @_;

  if(!$self->{'_fetched'}) {
    $self->entries($feed);
    $self->{'_fetched'} = 1;
  }

  if($feed) {
    return $self->{'feedmeta'}->{$feed}||{};
  }

  return $self->{'feedmeta'}||{};
}

sub title {
  my ($self, $feed) = @_;
  return $self->meta($feed)->{'title'} || 'Untitled';
}

sub fetch {
  my ($self, $url_ref, $headers) = @_;
  $self->{'ua'}                ||= XML::FeedLite::UserAgent->new(
								 'http_proxy' => $self->http_proxy(),
								);
  $self->{'ua'}->initialize();
  $self->{'ua'}->max_req($self->max_req()||$MAX_REQ);
  $self->{'statuscodes'}          = {};
  $headers                      ||= {};
  if($ENV{'HTTP_X_FORWARDED_FOR'}) {
    $headers->{'X-Forwarded-For'} ||= $ENV{'HTTP_X_FORWARDED_FOR'};
  }

  for my $url (keys %{$url_ref}) {
    if(ref $url_ref->{$url} ne 'CODE') {
      next;
    }

    $DEBUG and print {*STDERR} qq(Building HTTP::Request for $url [timeout=$self->{'timeout'}] via $url_ref->{$url}\n);

    my $headers  = HTTP::Headers->new(%{$headers});
    $headers->user_agent($self->user_agent());

    if($self->proxy_user() && $self->proxy_pass()) {
      $headers->proxy_authorization_basic($self->proxy_user(), $self->proxy_pass());
    }

    my $response = $self->{'ua'}->register(HTTP::Request->new('GET', $url, $headers),
					   $url_ref->{$url},
					   $BLK_SIZE);
    if($response) {
      $self->{'statuscodes'}->{$url} ||= $response->status_line();
    }
  }

  $DEBUG and print {*STDERR} qq(Requests submitted. Waiting for content\n);
  eval {
    $self->{'ua'}->wait($self->{'timeout'});
    1;
  } or do {
    if($EVAL_ERROR) {
      carp $EVAL_ERROR;
    }
  };

  for my $url (keys %{$url_ref}) {
    if(ref $url_ref->{$url} ne 'CODE') {
      next;
    }

    $self->{'statuscodes'}->{$url} ||= '200';
  }
  return;
}

sub statuscodes {
  my ($self, $url)         = @_;
  $self->{'statuscodes'} ||= {};

  if($self->{'ua'}) {
    my $uacodes = $self->{'ua'}->statuscodes();
    for my $k (keys %{$uacodes}) {
      if($uacodes->{$k}) {
	$self->{'statuscodes'}->{$k} = $uacodes->{$k};
      }
    }
  }

  return $url?$self->{'statuscodes'}->{$url}:$self->{'statuscodes'};
}

sub max_req {
  my ($self, @args) = @_;
  return $self->_accessor('max_req', @args);
}

1;
__END__

=head1 NAME

XML::FeedLite - Perl extension for fetching Atom and RSS feeds with minimal outlay

=head1 VERSION

$Revision: 1.8 $

=head1 SYNOPSIS

  use XML::FeedLite;

=head1 DESCRIPTION

This module fetches and processes Atom and RSS-format XML feeds. It's
designed as an alternative to XML::Atom, specifically to work better
under mod_perl. This module requires LWP::Parallel::UserAgent.

=head1 SUBROUTINES/METHODS

=head2 new - Constructor

  my $xfl = XML::FeedLite->new("http://www.atomenabled.org/atom.xml");

  my $xfl = XML::FeedLite->new([qw(http://www.atomenabled.org/atom.xml
                                   http://slashdot.org/slashdot.rss)]);

  my $xfl = XML::FeedLite->new({
			        'timeout'    => 60,
                                'url'        => 'http://www.atomenabled.org/atom.xml',
                                'http_proxy' => 'http://user:pass@webcache.local.com:3128/',
			       });

 Options can be: url        (optional scalar or array ref, URLs of feeds)
                 timeout    (optional int,      HTTP fetch timeout in seconds)
                 http_proxy (optional scalar,   web cache or proxy if not set in %ENV)
                 proxy_user (optional scalar,   username for authenticating forward-proxy)
                 proxy_pass (optional scalar,   password for authenticating forward-proxy)
                 user_agent (optional scalar,   User-Agent HTTP request header value)


  Very often you'll want to use XML:::FeedLite::Normalised instead of this baseclass.

=head2 http_proxy - Get/Set http_proxy

    $xfl->http_proxy("http://user:pass@squid.myco.com:3128/");

=head2 proxy_user - Get/Set proxy username for authenticating forward-proxies

  This is only required if the username wasn't specified when setting http_proxy

    $xfl->proxy_user('myusername');

=head2 proxy_pass - Get/Set proxy password for authenticating forward-proxies

  This is only required if the password wasn't specified when setting http_proxy

    $xfl->proxy_pass('secretpassword');

=head2 user_agent - Get/Set user-agent for request headers

    $xfl->user_agent('Feedtastic/1.0');

=head2 timeout - Get/Set timeout

    $xfl->timeout(30);

=head2 url - Get/Set DSN

  $xfl->url('http://das.ensembl.org/das/ensembl1834/'); # give url (scalar or arrayref) here if not specified in new()

  Or, if you want to add to the existing url list and you're feeling sneaky...

  push @{$xfl->url}, 'http://my.server/das/additionalsource';

=head2 reset - Flush bufers, reset flags etc.

  $xfl->reset();

=head2 entries - Retrieve XML::Simple data structures from feeds

  my $entry_data = $xfl->entries();

=head2 meta - Meta data globally keyed on feed, or for a given feed 

  my $hrMeta     = $xfl->meta();
  my $hrFeedMeta = $xfl->meta('http://mysite.com/feed.xml');

=head2 title - The name/title of a given feed

  my $title = $xfl->title($feed);

=head2 fetch - Performs the HTTP fetch and processing

  $xfl->fetch({
               #########
               # URLs and associated callbacks
               #
               'url1' => sub { ... },
               'url2' => sub { ... },
              },
              {
               #########
               # Optional HTTP headers
               #
               'X-Forwarded-For' => 'a.b.c.d',
              });

=head2 statuscodes - Retrieve HTTP status codes for request URLs

  my $code         = $xfl->statuscodes($url);
  my $code_hashref = $xfl->statuscodes();

=head2 max_req - set number of running concurrent requests

  $xfl->max_req(5);
  print $xfl->max_req();

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
