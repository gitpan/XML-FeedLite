#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use XML::FeedLite::Normalised;

my $feed = XML::FeedLite::Normalised->new('http://search.cpan.org/uploads.rdf');

print Dumper($feed->entries());
