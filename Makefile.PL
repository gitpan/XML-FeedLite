use 5.005;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'XML::FeedLite',
    VERSION_FROM      => 'lib/XML/FeedLite.pm', # finds $VERSION
    PREREQ_PM         => {LWP::Parallel::UserAgent => undef,
			  HTTP::Request  => undef,
			  HTTP::Headers  => undef,
			  HTML::Entities => undef,
			  MIME::Base64   => undef,
			 }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/XML/FeedLite.pm', # retrieve abstract from module
       AUTHOR         => 'Roger Pettett <rmp@psyphi.net>') : ()),
);

