#!/usr/bin/perl -T
use strict;
use warnings;
use Data::Dumper;
use XML::FeedLite;

my $xfl = XML::FeedLite->new([qw(http://www.atomenabled.org/atom.xml
			         http://slashdot.org/slashdot.rss)]);
my $data = $xfl->entries();

print Dumper($data);
