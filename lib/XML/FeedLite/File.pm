package XML::FeedLite::File;
use strict;
use base qw(XML::FeedLite);

=head2 fetch : Fetch feed data from file

  $xflf->fetch({
                '/path/to/file1' => sub { ... },
                '/path/to/file2# => sub { ... },
               });

=cut
sub fetch {
  my ($self, $url_ref) = @_;

  for my $fn (keys %{$url_ref}) {
    next unless (ref($url_ref->{$fn}) eq "CODE");
    open(my $fh, $fn) or die $!;
    local $/ = undef;
    my $xml = <$fh>;
    close($fh);

    my $cb = $url_ref->{$fn};
    &$cb($xml);
  }
}

1;
