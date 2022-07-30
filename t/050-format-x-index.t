use Test;
use Pod::To::HTML;
plan 3;

=begin pod
X<|category,behavior> L<http://www.doesnt.get.rendered.com>
=end pod

my $r = pod2html $=pod, :url({ $_ });
ok $r ~~ m/'href="http://www.doesnt.get.rendered.com"'/;

=begin pod

When indexing X<an item|category,an item> the X<X format|category,X format> is used.

It is possible to index X<an item|category,an item> in repeated places.
=end pod

$r = node2html $=pod[1];

like $r, /
    'When indexing'
    \s* '<a id="index-entry-an%20item">'
    \s* '<span ' .* '>an item</span>'
    .+ 'the'
    .+ '<span ' .+ '>X format</span>'
    .+ 'to index'
    .+ '<span' .+ '>an item</span>'
    .+ 'in repeated places.'
    /, 'X format in text';

=begin pod

When indexing X<an item|category,Define an item> another text can be used for the index.

It is possible to index X<hierarchical items|defining, a term>with hierarchical levels.

=end pod

$r = node2html $=pod[2];
like $r, /
    'When indexing <a id="index-entry-Define%20an%20item">'
    .* '<span' .+ '>an item</span>'
    .+ 'to index ' .+ 'index-entry-%20a%20term' .+ '<span' .+ '>hierarchical items</span>'
    /,  'Text with indexed items correct';
