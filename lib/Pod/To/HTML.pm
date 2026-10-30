module Pod::To::HTML;
use Text::Escape;

my $title;
my @meta;
my @indexes;
my @body;

sub pod2html($pod) is export {
    @body.push: whatever2html($pod);

    my $title_html = $title // 'Pod document';

    # TODO: make this look nice again when q:to"" gets implemented
    my $prelude = qq[<!doctype html>
<html>
<head>
  <title>{$title_html}</title>
  <meta charset="UTF-8" />
  <link rel="stylesheet" href="http://perlcabal.org/syn/perl.css">
  {metadata()}
</head>
<body class="pod" id="___top">
];

    return $prelude
        ~ ($title.defined ?? "<h1>{$title_html}</h1>\n" !! '')
        ~ buildindexes()
        ~ @body.join
        ~ "</body>\n</html>";
}

sub whatever2html($node) {
    given $node {
        when Pod::Heading      { heading2html($node)             }
        when Pod::Block::Code  { code2html($node)                }
        when Pod::Block::Named { named2html($node)               }
        when Pod::Block::Para  { para2html($node)                }
        when Pod::Block::Table { table2html($node)               }
#        when Pod::Block::Declarator { declarator2html($node)     }
        when Pod::Item         { item2html($node)                }
        when Positional        { $node.map({whatever2html($_)}).join }
        when Pod::Block::Comment { }
        default                { $node.Str                       }
    }
}

sub metadata {
    @meta.map(-> $p {
        qq[<meta name="{$p.key}" value="{$p.value}" />\n]
    }).join;
}

sub buildindexes {
    my $r = qq[<nav class="indexgroup">\n];

    my $indent = q{ } x 2;
    my @opened;
    for @indexes -> $p {
        my $lvl  = $p.key;
        my %head = $p.value;
        if +@opened {
            while @opened[*-1] > $lvl {
                $r ~= $indent x @opened - 1
                    ~ "</ul>\n";
                @opened.pop;
            }
        }
        my $last = @opened[*-1] // 0;
        if $last < $lvl {
            $r ~= $indent x $last
                ~ qq[<ul class="indexList indexList{$lvl}">\n];
            @opened.push($lvl);
        }
        $r ~= $indent x $lvl
            ~ qq[<li class="indexItem indexItem{$lvl}">]
            ~ qq[<a href="#{%head<uri>}">{%head<html>}</a>\n];
    }
    for ^@opened {
        $r ~= $indent x @opened - 1 - $^left
            ~ "</ul>\n";
    }

    return $r ~ "</nav>\n";
}

sub heading2html($pod) {
    my $lvl = min($pod.level, 6);
    my %escaped = ($_ => escape($pod.content[0].content, $_) for <uri html>);
    @indexes.push: Pair.new(key => $lvl, value => %escaped);

    return
        sprintf('<h%d id="%s">', $lvl, %escaped<uri>)
            ~ qq[<a class="u" href="#___top" title="go to top of document">]
                ~ %escaped<html>
            ~ qq[</a>]
        ~ qq[</h{$lvl}>\n];
}

sub named2html($pod) {
    given $pod.name {
        when 'pod'  { whatever2html($pod.content)     }
        when 'para' { para2html($pod.content[0])      }
        when 'defn' { whatever2html($pod.content[0]) ~ "\n"
                    ~ whatever2html($pod.content[1..*-1]) }
        when 'config' { }
        when 'nested' { }
        default     {
            if $pod.name eq 'TITLE' {
                $title = prose2html($pod.content[0]);
            }
            elsif $pod.name ~~ any(<VERSION DESCRIPTION AUTHOR COPYRIGHT SUMMARY>)
              and $pod.content[0] ~~ Pod::Block::Para {
                @meta.push: Pair.new(key => $pod.name.lc, value => prose2html($pod.content[0]));
            }

            '<section>'
                ~ "<h1>{$pod.name}</h1>\n"
                ~ whatever2html($pod.content)
                ~ "</section>\n"
        }
    }
}

sub prose2html($pod, $sep = '') {
    escape($pod.content.join($sep), 'html');
}

sub para2html($pod) {
    '<p>' ~ escape(twine2text($pod.content), 'html') ~ "</p>\n"
}

sub code2html($pod) {
    '<pre>' ~ prose2html($pod) ~ "</pre>\n"
}

sub item2html($pod) {
#FIXME
    '<ul><li>' ~ whatever2html($pod.content) ~ "</li></ul>\n"
}

sub formatting2text($pod) {
    twine2text($pod.content)
}

sub twine2text($twine) {
    return '' unless $twine.elems;
    my $r = $twine[0];
    for $twine[1..*] -> $f, $s {
        $r ~= twine2text($f.content);
        $r ~= $s;
    }
    return $r;
}

sub table2html($pod) {
    my @r;

    if $pod.caption {
        @r.push("<caption>{escape($pod.caption, 'html')}</caption>");
    }

    if $pod.headers {
        @r.push(
            '<thead><tr>',
            $pod.headers.map(-> $cell {
                "<th>{escape($cell, 'html')}</th>"
            }),
            '</tr></thead>'
        );
    }

    @r.push(
        '<tbody>',
        $pod.content.map(-> $line {
            '<tr>',
            $line.list.map(-> $cell {
                "<td>{escape($cell, 'html')}</td>"
            }),
            '</tr>'
        }),
        '</tbody>'
    );

    return "<table>\n{@r.join("\n")}\n</table>";
}
