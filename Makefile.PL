# $Id: Makefile.PL,v 1.3 2008/03/07 00:21:05 Daddy Exp $

use inc::Module::Install;

name('WWW-Search-Jarit');
version_from('lib/WWW/Search/Jarit.pm');
author('Martin Thurn <mthurn@cpan.org>');
license('perl');

requires('perl' => 5.004);
requires('Carp');
requires('HTTP::Request::Common');
requires('LWP::UserAgent');
build_requires('Test::More');
build_recommends('Test::Pod');
build_recommends('Test::Pod::Coverage');
requires('WWW::Search');
requires('WWW::Search::Result');
# We need the version where we can tell count_results NOT to escape
# the query:
test_requires('WWW::Search::Test' => 2.275);

WriteAll;

__END__

