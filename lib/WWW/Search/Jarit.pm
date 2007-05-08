# $Id: Jarit.pm,v 1.2 2007/05/08 21:51:11 Daddy Exp $

=head1 NAME

WWW::Search::Jarit - class for searching www.search.com

=head1 SYNOPSIS

  use WWW::Search;
  my $oSearch = new WWW::Search('Jarit');
  $oSearch->native_query('101-230');
  while (my $oResult = $oSearch->next_result())
    { print $oResult->url, "\n"; }

=head1 DESCRIPTION

This class is a search.com specialization of L<WWW::Search>.  It
handles making and interpreting searches for medical instrument
cross-references at F<http://www.jarit.com>.

This class exports no public interface; all interaction should
be done through L<WWW::Search> objects.

=head1 NOTES

The query is applied as "ALL these words"
(i.e. boolean AND of all the query terms)

=head1 SEE ALSO

To make new back-ends, see L<WWW::Search>.

=head1 BUGS

Please tell the author if you find any!

=head1 AUTHOR

C<WWW::Search::Jarit> was originally written by Martin Thurn,
based on the code for C<WWW::Search::Search>.

=head1 LEGALESE

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

=cut

#####################################################################

package WWW::Search::Jarit;

use strict;
use warnings;

use Carp;
use Data::Dumper;
use HTTP::Request::Common;
use LWP::UserAgent;
use WWW::Search;
use WWW::Search::Result;

use base 'WWW::Search';

my
$VERSION = do { my @r = (q$Revision: 1.2 $ =~ /\d+/g); sprintf "%d."."%03d" x $#r, @r };
my $MAINTAINER = 'Martin Thurn <mthurn@cpan.org>';

sub gui_query
  {
  my $self = shift;
  return $self->native_query(@_);
  } # gui_query


sub native_setup_search
  {
  my ($self, $native_query, $native_options_ref) = @_;
  $self->{_debug} = $native_options_ref->{'search_debug'};
  $self->{_debug} = 2 if ($native_options_ref->{'search_parse_debug'});
  $self->{_debug} ||= 0;
  $self->user_agent('non-robot');
  $self->http_method('POST');
  $self->{_next_to_retrieve} = 1;
  $self->{_jarit_host_} = 'http://www.jarit.com/';
  $self->{_num_hits} = 0;
  if (! defined($self->{_options}))
    {
    $self->{_options} = {
                         'altno' => $native_query,
                         'getxref' => '',
                        };
    } # if
  } # native_setup_search


sub http_request
  {
  my $self = shift;
  my ($method, $url) = @_;
  # Above, note that we exactly replicate the arguments of
  # WWW::Search::http_request
  if (! $self->{_jarit_base_url_})
    {
    print STDERR " DDD WWW::Search::Jarit::_n_r_s, need a session iD\n" if (3 < $self->{_debug});
    # my $oReq = HTTP::Request->new(POST => 'http://www.jarit.com/cgi-bin/jarit.pl?instsrch', undef, [start => 'start']);
    # print STDERR " DDD   raw HTTP::Request is:\n", $oReq->as_string if (3 <= $self->{_debug});
    # my $oRes = $self->user_agent->request($oReq);
    my $oRes = $self->user_agent->post('http://www.jarit.com/cgi-bin/jarit.pl?instsrch',
                                       [start => 'start']);
    my $sRes = $oRes->as_string;
    if ($sRes =~ m!action="(.+?)"!)
      {
      $self->{_jarit_base_url_} = $self->absurl($self->{_jarit_host_}, $1);
      print STDERR " DDD   got jarit_base_url ==$self->{_jarit_base_url_}==\n" if (3 < $self->{_debug});
      } # if
    else
      {
      die;
      }
    } # if
  my @a = map { $_, $self->{_options}->{$_} } keys %{$self->{_options}};
  # print Dumper(\@a);
  my $oRes = $self->user_agent->post($self->{_jarit_base_url_}, \@a);
  print STDERR " DDD   response =====", $oRes->as_string, "=====\n" if (3 < $self->{_debug});
  return $oRes;
  } # http_request

sub preprocess_results_page_OFF
  {
  my $self = shift;
  my $sPage = shift;
  print STDERR '='x 10, $sPage, '='x 10, "\n";
  return $sPage;
  } # preprocess_results_page


sub parse_tree
  {
  my $self = shift;
  my $oTree = shift;
 TRY_RESULT_COUNT:
  while (! $self->approximate_result_count)
    {
    my $oH2 = $oTree->look_down(_tag => 'h2');
    if (ref $oH2)
      {
      if ($oH2->as_text =~ m!WE COULD NOT FIND THE CODE!i)
        {
        $self->approximate_result_count(0);
        last TRY_RESULT_COUNT;
        } # if
      } # if
    # If there is one result, the page doesn't report the count:
    $self->approximate_result_count(1);
    my $oCAPTION = $oTree->look_down(_tag => 'caption');
    if (ref $oCAPTION)
      {
      print STDERR " DDD oCAPTION is ===", $oCAPTION->as_HTML, "===\n" if (2 <= $self->{_debug});
      my $sCaption = $oCAPTION->as_text;
      if ($sCaption =~ m!ITEMS\s+\d+\s+TO\s+\d+\s+OF\s+(\d+)\s+DISPLAYED!i)
        {
        $self->approximate_result_count($1);
        } # if
      } # if
    # This is a dummy while loop, we never repeat:
    last TRY_RESULT_COUNT;
    } # while
  my $hits_found = 0;
  my @aoLI = $oTree->look_down(_tag => 'input',
                               type => 'checkbox',
                              );
 LI_TAG:
  foreach my $oLI (@aoLI)
    {
    next LI_TAG unless ref $oLI;
    print STDERR " DDD oLI is ===", $oLI->as_HTML, "===\n" if (2 <= $self->{_debug});
    my $oTD = $oLI->parent;
    my $oTDCatNo = $oTD->right->right;
    my $sCatNo = $oTDCatNo->as_text;
    my $oTDDesc = $oTDCatNo->right;
    my $sDesc = $oTDDesc->as_text;
    my $oTDImage = $oTDDesc->right;
    my $oIMG = $oTDImage->look_down(_tag => 'img');
    next LI_TAG if ! ref($oIMG);
    print STDERR " DDD oIMG is ===", $oIMG->as_HTML, "===\n" if (2 <= $self->{_debug});
    my $sURLImage = $self->absurl($self->{_jarit_base_url_}, $oIMG->attr('src'));

    my $hit = new WWW::Search::Result;
    $hit->add_url($sURLImage);
    $hit->title($sCatNo);
    $hit->description(&strip($sDesc));
    push(@{$self->{cache}}, $hit);
    $self->{'_num_hits'}++;
    $hits_found++;
    } # foreach LI_TAG
SKIP_RESULTS_LIST:
  # Find the next link, if any:
  my $oLInext = $oTree->look_down('_tag' => 'li',
                                  class => 'next');
  if (ref $oLInext)
    {
    my $oAnext = $oLInext->look_down(_tag => 'a');
    print STDERR " +   oAnext is ===", $oAnext->as_HTML, "===\n" if 2 <= $self->{_debug};
    $self->{_next_url} = $self->absurl($self->{'_prev_url'},
                                       $oAnext->attr('href'));
    } # if
 SKIP_NEXT_LINK:
  return $hits_found;
  } # parse_tree


sub strip
  {
  my $sRaw = shift;
  my $s = &WWW::Search::strip_tags($sRaw);
  # Strip leading whitespace:
  $s =~ s!\A[\240\t\r\n\ ]+  !!x;
  # Strip trailing whitespace:
  $s =~ s!  [\240\t\r\n\ ]+\Z!!x;
  return $s;
  } # strip

1;

__END__

This is the first link that users click on:

http://www.jarit.com/gocgi.html?instsrch

This is the first empty search:

POST http://www.jarit.com/cgi-bin/jarit.pl?instsrch
start=start

Another cross-reference search page to consider:
http://www.amblersurgical.com/page.cfm?NavID=2&WebContentID=2

