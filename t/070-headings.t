use v6;
use Test;
use Pod::To::HTML;

plan 5;

=begin pod

=head1 Heading 1

=head2 Heading 1.1

=head2 Heading 1.2

=head1 Heading 2

=head2 Heading 2.1

=head2 Heading 2.2

=head2 L<(Exception) method message|/routine/message#class_Exception>

=head3 Heading 2.2.1

=head3 X<Heading|Category,Heading> 2.2.2

=head1 Heading C<3>

=end pod

my $html = pod2html $=pod;

($html ~~ m:g/ ('2.2.2') /);

ok so ($0 && $1 && $2), 'hierarchical numbering';

($html ~~ m:g/ 'href="#Heading_3"' /);

ok so $0, 'link down to heading';

($html ~~ m:g/ ('id="index-entry-Heading"') /);

ok so ($0 || $1), 'no X<> anchors in ToC';

($html ~~ m:g/ ('<a href="#Heading_1">Heading 1</a>') /);

ok so $0, 'Proper rendering of heading';

($html ~~ m:g/ ('<h1 id="Heading_3"><a class="u" href="#___top" title="go to top of document">Heading <code>3</code></a></h1>') /);

ok so $0, 'Proper rendering of heading from multiple nodes';