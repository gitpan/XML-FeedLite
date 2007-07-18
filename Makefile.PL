use strict;
use warnings;
use 5.005;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
	      'NAME'          => 'XML::FeedLite',
	      'VERSION_FROM'  => 'lib/XML/FeedLite.pm', # finds $VERSION
	      'PREREQ_PM'     => {
				  'LWP::Parallel::UserAgent' => undef,
				  'HTTP::Request'            => 1.40,
				  'HTTP::Headers'            => 1.64,
				  'HTML::Entities'           => undef,
				  'MIME::Base64'             => undef,
				 },
	      'ABSTRACT_FROM' => 'lib/XML/FeedLite.pm',
	      'AUTHOR'        => 'Roger Pettett <rmp@psyphi.net>',
	      'LICENSE'       => 'perl',
	     );

