#########
# Author:        rmp@psyphi.net
# Maintainer:    rmp@psyphi.net
# Created:       2006-06-08
# Last Modified: 2006-06-09
#
package XML::FeedLite::Normalised;
use strict;
use base "XML::FeedLite";

=head2 entries : Data structure of processed feed entries

  my $hrEntries = $xfln->entries();

=cut
sub entries {
  my $self    = shift;
  my $rawdata = $self->SUPER::entries(@_);

  for my $feed (keys %{$self->{'format'}}) {
    my $format = $self->{'format'}->{$feed};

    next if($format !~ /^(atom|rss)/);

    my $method = "process_$format";

    $self->$method($rawdata->{$feed});
  }
  return $rawdata;
}

=head2 process_rss : Processor for RSS 1.0-format entries

  Used by X::FL::N::entries

  $xfln->process_rss([...]);

=cut
sub process_rss {
  my ($self, $feeddata) = @_;

  for my $entry (@{$feeddata}) {
    %{$entry} = (
		 'title'   => $entry->{'title'}->[0]->{'content'}||"",
		 'content' => $entry->{'description'}->[0]->{'content'}||"",
		 'author'  => $entry->{'dc:creator'}->[0]->{'content'}||"",
		 'date'    => $entry->{'dc:date'}->[0]->{'content'}||"",
		 'link'    => [map { $_->{'content'}||"" } @{$entry->{'link'}}],
		);
  }
}

=head2 process_atom : Processor for Atom-format entries

  Used by X::FL::N::entries

  $xfln->process_atom([...]);

=cut
sub process_atom {
  my ($self, $feeddata) = @_;

  for my $entry (@{$feeddata}) {
    %{$entry} = (
		 'title'   => $entry->{'title'}->[0]->{'content'}||"",
		 'content' => $entry->{'content'}->[0]->{'content'}||"",
		 'author'  => $entry->{'author'}->[0]->{'content'}||"",
		 'date'    => $entry->{'updated'}->[0]->{'content'}||"",
		 'link'    => [map { $_->{'href'}||"" } @{$entry->{'link'}}],

		);
  }
}

1;
