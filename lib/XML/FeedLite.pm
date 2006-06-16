package XML::FeedLite;
#########
# Author:        rmp@psyphi.net
# Maintainer:    rmp@psyphi.net
# Created:       2006-06-08
# Last Modified: 2006-06-16
#
use strict;
use warnings;
use XML::FeedLite::UserAgent;
use HTTP::Request;
use HTTP::Headers;
use HTML::Entities;
use MIME::Base64;

our $DEBUG    = 0;
our $VERSION  = do { my @r = (q$Revision: 1.3 $ =~ /\d+/g); sprintf "%d."."%03d" x $#r, @r };
our $BLK_SIZE = 8196;
our $TIMEOUT  = 30;
our $MAX_REQ  = 5;
our $PATTERNS = {
		 'ENTRIES' => {
			       'atom' => qr!<entry[^>]*>(.*?)</entry>!smi,
			       'rss'  => qr!<item(?: [^>]*|)>(.*?)</item>!smi,
			      },
		 'META'    => {
			       'atom' => {
					  'title' => qr!<feed.*?<title[^>]*>(.*?)</title>!smi,
					 },
			       'rss'  => {
					  'title' => qr!<channel.*?<title[^>]*>(.*?)</title.*?</channel>!smi,
					 },
			      },
		};


=head1 NAME

XML::FeedLite - Perl extension for fetching Atom and RSS feeds with minimal outlay

=head1 SYNOPSIS

  use XML::FeedLite;

=head1 METHODS

=head2 new : Constructor

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

=cut
sub new {
  my ($class, $ref) = @_;
  my $self = {
	      'url'               => [],
	      'timeout'           => $TIMEOUT,
	      'data'              => {},
	     };

  bless $self, $class;

  if($ref && ref($ref) eq "HASH") {
    for my $arg (qw(url timeout http_proxy proxy_user proxy_pass user_agent)) {
      $self->$arg($ref->{$arg}) if(defined $ref->{$arg} && $self->can($arg));
    }

  } elsif($ref) {
    $self->url($ref);
  }

  return $self;
}

=head2 http_proxy : Get/Set http_proxy

    $xfl->http_proxy("http://user:pass@squid.myco.com:3128/");

=cut
sub http_proxy {
  my ($self, $proxy)    = @_;
  $self->{'http_proxy'} = $proxy if($proxy);

  if(!$self->{'_checked_http_proxy_env'}) {
    $self->{'http_proxy'} ||= $ENV{'http_proxy'};
    $self->{'_checked_http_proxy_env'} = 1;
  }

  if($self->{'http_proxy'} =~ m|^(https?://)(\S+):(.*?)\@(.*?)$|) {
    #########
    # http_proxy contains username & password - we'll set them up here:
    #
    $self->proxy_user($2);
    $self->proxy_pass($3);

    $self->{'http_proxy'} = "$1$4";
  }

  return $self->{'http_proxy'};
}

=head2 proxy_user : Get/Set proxy username for authenticating forward-proxies

  This is only required if the username wasn't specified when setting http_proxy

    $xfl->proxy_user("myusername");

=cut
sub proxy_user {
  my ($self, $proxy_user) = @_;
  $self->{'proxy_user'}   = $proxy_user if($proxy_user);
  return $self->{'proxy_user'};
}

=head2 proxy_pass : Get/Set proxy password for authenticating forward-proxies

  This is only required if the password wasn't specified when setting http_proxy

    $xfl->proxy_pass("secretpassword");

=cut
sub proxy_pass {
  my ($self, $proxy_pass) = @_;
  $self->{'proxy_pass'}   = $proxy_pass if($proxy_pass);
  return $self->{'proxy_pass'};
}

=head2 user_agent : Get/Set user-agent for request headers

    $xfl->user_agent("Feedtastic/1.0");

=cut
sub user_agent {
  my ($self, $user_agent) = @_;
  $self->{'user_agent'}   = $user_agent if($user_agent);
  return $self->{'user_agent'} || "XML::FeedLite v$VERSION";
}

=head2 timeout : Get/Set timeout

    $xfl->timeout(30);

=cut
sub timeout {
  my ($self, $timeout) = @_;
  $self->{'timeout'}   = $timeout if($timeout);
  return $self->{'timeout'};
}

=head2 url : Get/Set DSN

  $xfl->url("http://das.ensembl.org/das/ensembl1834/"); # give url (scalar or arrayref) here if not specified in new()

  Or, if you want to add to the existing url list and you're feeling sneaky...

  push @{$xfl->url}, "http://my.server/das/additionalsource";

=cut
sub url {
  my ($self, $url) = @_;

  if($url) {
    $self->reset();

    if(ref($url) eq "ARRAY") {
      $self->{'url'} = $url;

    } else {
      $self->{'url'} = [$url];
    }
  }

  return $self->{'url'};
}

=head2 reset : Flush bufers, reset flags etc.

  $xfl->reset();

=cut
sub reset {
  my $self = shift;
  delete($self->{'results'});
  delete($self->{'feedmeta'});
  delete($self->{'data'});
}

=head2 entries : Retrieve XML::Simple data structures from feeds

  my $entry_data = $xfl->entries();

=cut
sub entries {
  my ($self, $url, $opts) = @_;

  return $self->{'results'} if(exists $self->{'results'});

  my $results   = {};
  my $ref       = {};
  my $arUrl     = [];

  if($url && $opts) {
    if(ref($url)) {
      $arUrl = $url;
    } else {
      $arUrl = [$url];
    }
  } else {
    $arUrl = $self->url();
    $opts  = $url;
  }
  $opts ||= {};

  for my $sUrl (@{$arUrl}) {
    #########
    # loop over urls to fetch
    #
    $results->{$sUrl}            = [];
    $self->{'feedmeta'}->{$sUrl} = {};

    $ref->{$sUrl} = sub {
      my $blk = shift;
      $self->{'data'}->{$sUrl} .= $blk;

      if(!$self->{'format'}->{$sUrl}) {
	if($blk =~ m|xmlns="https?://[a-z\d\.\-/]+/atom|i) {
	  $self->{'format'}->{$sUrl} = "atom";

	} elsif($blk =~ m|xmlns="https?://[a-z\d\.\-/]+/rss|i) {
	  $self->{'format'}->{$sUrl} = "rss";

	} elsif($blk =~ m|rss\s+version\s*=\s*"2.0"|i) {
	  $self->{'format'}->{$sUrl} = "rss";
	}
      }

      my $feedmeta = $self->{'feedmeta'}->{$sUrl};
      for my $f (keys %{$PATTERNS->{'META'}->{$self->{'format'}->{$sUrl}}}) {
	next if($feedmeta->{$f});
	my $pat = $PATTERNS->{'META'}->{$self->{'format'}->{$sUrl}}->{$f};
	($feedmeta->{$f}) = $blk =~ /$pat/;
      }

      my $pat = $PATTERNS->{'ENTRIES'}->{$self->{'format'}->{$sUrl}};
      if(!$pat) {
	warn qq(No pattern defined for url=$sUrl fmt=@{[$self->{'format'}->{$sUrl}||"unknown"]});
	return;
      }
      while($self->{'data'}->{$sUrl} =~ s/$pat//) {
	&_parse_entry($self, $results->{$sUrl}, $1);
      }
      return;
    };
  }

  $self->fetch($ref, $opts->{'headers'});

  $DEBUG and print STDERR qq(Content retrieved\n);

  $self->{'results'} = $results;
  return $results;
}

sub _parse_entry {
  my ($self, $results, $blk) = @_;
  my $entry = {};
  $blk    ||= "";

  my $pat = qr!(<([a-z:]+)([^>]*)>(.*?)</\2>|<([a-z:]+)([^>]*)/>)!smi;
  while($blk =~ s|$pat||) {

    my ($tag, $attr, $content);
    if($4) {
      ($tag, $attr, $content) = ($2, $3, $4);

    } else {
      ($tag, $attr) = ($5, $6)
    }

    my $tagdata   = {};
    $attr       ||= "";

    while($attr =~ s|(\S+)\s*=\s*["']([^"']*)["']||sm) {
      $tagdata->{$1} = $2 if($2);
    }

    if($content) {
      my $mode = $tagdata->{'mode'} || "";

      if($mode eq "escaped") {
	$content = decode_entities($content);

      } elsif($mode eq "base64") {
	$content = decode_base64($content);
      }

      $tagdata->{'content'} = $content;
    }
    push @{$entry->{$tag}}, $tagdata if(keys %$tagdata);
  }

  push @{$results}, $entry;
  return "";
}

=head2 meta : Meta data globally keyed on feed, or for a given feed 

  my $hrMeta     = $xfl->meta();
  my $hrFeedMeta = $xfl->meta("http://mysite.com/feed.xml");

=cut
sub meta {
  my ($self, $feed) = @_;
  if(!$self->{'_fetched'}) {
    $self->entries($feed);
    $self->{'_fetched'} = 1;
  }

  if($feed) {
    return $self->{'feedmeta'}->{$feed}||{};
  } else {
    return $self->{'feedmeta'}||{};
  }
}

=head2 title : The name/title of a given feed

  my $title = $xfl->title($feed);

=cut
sub title {
  my ($self, $feed) = @_;
  return $self->meta($feed)->{'title'} || "Untitled";
}

=head2 fetch : Performs the HTTP fetch and processing

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

=cut
sub fetch {
  my ($self, $url_ref, $headers) = @_;
  $self->{'ua'}                ||= XML::FeedLite::UserAgent->new(
								 'http_proxy' => $self->http_proxy(),
								);
  $self->{'ua'}->initialize();
  $self->{'ua'}->max_req($self->max_req()||$MAX_REQ);
  $self->{'statuscodes'}          = {};
  $headers                      ||= {};
  $headers->{'X-Forwarded-For'} ||= $ENV{'HTTP_X_FORWARDED_FOR'} if($ENV{'HTTP_X_FORWARDED_FOR'});

  for my $url (keys %$url_ref) {
    next if(ref($url_ref->{$url}) ne "CODE");

    $DEBUG and print STDERR qq(Building HTTP::Request for $url [timeout=$self->{'timeout'}] via $url_ref->{$url}\n);

    my $headers  = HTTP::Headers->new(%$headers);
    $headers->user_agent($self->user_agent()) if($self->user_agent());

    if($self->proxy_user() && $self->proxy_pass()) {
      $headers->proxy_authorization_basic($self->proxy_user(), $self->proxy_pass());
    }

    my $response = $self->{'ua'}->register(HTTP::Request->new('GET', $url, $headers),
					   $url_ref->{$url},
					   $BLK_SIZE);

     $self->{'statuscodes'}->{$url} ||= $response->status_line() if($response);
  }

  $DEBUG and print STDERR qq(Requests submitted. Waiting for content\n);
  eval {
    $self->{'ua'}->wait($self->{'timeout'});
  };

  if($@) {
    warn $@;
  }

  for my $url (keys %$url_ref) {
    next if(ref($url_ref->{$url}) ne "CODE");

    $self->{'statuscodes'}->{$url} ||= "200";
  }
}

=head2 statuscodes : Retrieve HTTP status codes for request URLs

  my $code         = $xfl->statuscodes($url);
  my $code_hashref = $xfl->statuscodes();

=cut
sub statuscodes {
  my ($self, $url)         = @_;
  $self->{'statuscodes'} ||= {};

  if($self->{'ua'}) {
    my $uacodes = $self->{'ua'}->statuscodes();
    for my $k (keys %$uacodes) {
      $self->{'statuscodes'}->{$k} = $uacodes->{$k} if($uacodes->{$k});
    }
  }

  return $url?$self->{'statuscodes'}->{$url}:$self->{'statuscodes'};
}

=head2 max_req set number of running concurrent requests

  $xfl->max_req(5);
  print $xfl->max_req();

=cut
sub max_req {
  my ($self, $max)    = @_;
  $self->{'_max_req'} = $max if($max);
  return $self->{'_max_req'};
}

1;
__END__


=head1 DESCRIPTION

This module fetches and processes Atom and RSS-format XML feeds. It's
designed as an alternative to XML::Atom, specifically to work better
under mod_perl. This module requires LWP::Parallel::UserAgent.

=head1 SEE ALSO

XML::Atom

=head1 AUTHOR

Roger Pettett, E<lt>rmp@psyphi.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Roger Pettett

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
