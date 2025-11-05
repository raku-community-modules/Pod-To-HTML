use OO::Monitors:ver<1.1.7+>:auth<zef:raku-community-modules>;
use URI::Escape:ver<0.3.8+>:auth<zef:raku-community-modules>; # uri_escape
use Template::Mustache:ver<1.2.4+>:auth<zef:raku-community-modules>:api<1.2.0>;
use Pod::Load:ver<0.7.2+>:auth<zef:jjmerelo>;

class Pod::List is Pod::Block {};
class Pod::DefnList is Pod::Block {};
BEGIN { if ::('Pod::Defn') ~~ Failure { CORE::Pod::<Defn> := class {} } }
class Node::To::HTML {...}  # UNCOVERABLE
class TOC::Calculator {...}  # UNCOVERABLE

role Pod::To::HTML::Renderer {  # UNCOVERABLE
    method render(%context) {  # UNCOVERABLE
        ...
    }
}

class Pod::To::HTML::Mustache does Pod::To::HTML::Renderer {
    has $.template;
    has $.main-template-path;

    method render(%context) {
        # Get 'main.mustache' (and possible its partials) under template path
        my ($template-file, %partials) =
          retrieve-templates($!template, $!main-template-path);

        Template::Mustache.new.render(
          $template-file.IO.slurp, %context, :from[%partials], :literal
        )
    }
}

# The Rakudo compiler expects there to be a render method with a
# Pod::To::<name> invocant when --doc=name is used. Then the render
# method is called with a pod tree.  The following adds a Pod::To::HTML
# class and the method to call the subs in the module.
class Pod::To::HTML {
    # Renderers
    has $.page-renderer;
    has $.node-renderer;

    # Data from creator
    has $.title;
    has $.subtitle;
    has &.url;
    has $.lang;
    has %.template-vars;

    # Page data
    has %.metadata;
    has %.crossrefs;
    has @.body;
    has @.footnotes;

    method new(
      :$title,
      :$subtitle,
      :$lang,
      :templates(:$template), :$main-template-path = '',
      :$node-renderer = Node::To::HTML,
      :$page-renderer = Pod::To::HTML::Mustache.new(
        :$template, :$main-template-path
      ),
      *%template-vars
    ) {
        self.bless(:$title, :$subtitle, :$lang, :$node-renderer, :$page-renderer, :%template-vars);
    }

    method url($url-text) {
        &!url.defined ?? &!url($url-text) !! $url-text
    }

    # Converts a Pod tree to a HTML document using templates
    multi method render(Pod::To::HTML:U: |c) { self.new.render(|c) }
    multi method render(Pod::To::HTML:D: $pod,
      TOC::Calculator :$toc,
                      :&url = -> $url { $url }
    ) {

        # Keep count of how many footnotes we've output.
        my Int $*done-notes = 0;
        &!url = &url;

        debug {
            note colored("About to call node2html ", "bold") ~ $pod.raku
        }
        @!body.push: $!node-renderer
          .new(renderer => self)
          .node2html($pod.map: { visit $_, :assemble(&assemble-list-items) });

        # sensible css default
        my $default-style := %?RESOURCES<css/github.css>.IO.slurp;

        # title and subtitle picked from Pod document can be overridden
        # with provided ones via the subroutines.
        my $title-html    := $!title    // %!metadata<title>    // '';
        my $subtitle-html := $!subtitle // %!metadata<subtitle> // '';
        my $lang-html     := $!lang     // %!metadata<lang>     // 'en';

        my %context = :@!body,
          # documentable template vars
          :title($title-html), :subtitle($subtitle-html),
          :toc($toc.new(:$pod).render), :lang($lang-html),
          :footnotes(self.do-footnotes),

          # probably documentable
          :$default-style,

          # Semantic blocks are made available to the Mustache template.
          |%!metadata,

          # Additional template variables for the Mustache template can be
          # supplied
          |%!template-vars;
        $!page-renderer.render(%context);
    }

    # Flushes accumulated footnotes since last call. The idea here is
    # that we can stick calls to this before each C«</section>» tag
    # (once we have those per-header) and have notes that are visually
    # and semantically attached to the section.
    method do-footnotes() {
        if @!footnotes -> @footnotes {
            my Int $current-note = $*done-notes + 1;
            my $notes = @!footnotes.kv.map(-> $k, $v {
                my $num = $k + $current-note;
                qq{<li><a href="#fn-ref-$num" id="fn-$num">[↑]</a> $v </li>\n}
            }).join;

            $*done-notes += @!footnotes;
            qq[<aside><ol start="$current-note">\n$notes\</ol></aside>]
        }
        else {
            ''
        }
    }
}

monitor Node::To::HTML {
    has Pod::To::HTML $.renderer;

    # inline level or below
    multi method node2inline($node --> Str:D) {
        debug {
            note colored("missing a node2inline multi for ","bold") ~ $node.gist
        }
        node2text($node);
    }

    multi method node2inline(Pod::Block::Para $node --> Str:D) {
        self.node2inline($node.contents)
    }

    multi method node2inline(Pod::FormattingCode $node --> Str:D) {
        my constant %basic-html =
          B => 'strong',  # Basis
          C => 'code',    # Code
          I => 'em',      # Important
          K => 'kbd',     # Keyboard
          R => 'var',     # Replaceable
          T => 'samp',    # Terminal
          U => 'u';
        # Unusual (css: text-decoration-line: underline)

        given $node.type {
            when any(%basic-html.keys) {
                q{<} ~ %basic-html{$_} ~ q{>}
                  ~ self.node2inline($node.contents)
                  ~ q{</} ~ %basic-html{$_} ~ q{>}
            }

            # Escape
            when 'E' {
                $node.meta.map({
                    when Int { "&#$_;" }
                    when Str { "&$_;" }
                }).join;
            }

            # Note
            when 'N' {
                $!renderer.footnotes.push(  # UNCOVERABLE
                  self.node2inline($node.contents)
                );
                my $id := +$!renderer.footnotes;
                qq{<a href="#fn-$id" id="fn-ref-$id">[$id]</a>}
            }

            # Links
            when 'L' {
                my $text = self.node2inline($node.contents);
                my $url  = $node.meta[0] || node2text($node.contents);

                # If we have an internal-only link, strip the # from the text
                if $text ~~ /^'#'/ {
                    $text = $/.postmatch
                }
                if !$text ~~ /^\?/ {
                    $url = unescape_html($url);
                }

                if $url ~~ /^'#'/ {
                    $url = '#' ~ uri_escape(escape_id($/.postmatch))
                }

                qq[<a href="{ $!renderer.url($url) }">{ $text }</a>]
            }

            # zero-width comment
            when 'Z' {
                ''
            }

            when 'D' {
                # TODO memorise these definitions (in $node.meta) and
                # display them properly
                my $text := self.node2inline($node.contents);
                qq[<defn>{ $text }</defn>]
            }

            when 'X' {
                multi sub recurse-until-str(Str:D $s) { $s }
                multi sub recurse-until-str(Pod::Block:D $n) {
                    $n.contents>>.&recurse-until-str().join
                }

                my $index-text := recurse-until-str($node).join;
                my @indices     = $node.meta;

                my $index-name-attr =
                  qq[index-entry{
                      @indices ?? '-' !! ''
                  }{
                      @indices.join('-')
                  }{
                      $index-text ?? '-' !! ''
                  }$index-text]
                    .subst('_', '__', :g)
                    .subst(' ', '_', :g);

                $index-name-attr =
                  $!renderer.url($index-name-attr).subst(/^\//, '');

                my $text := self.node2inline($node.contents);
                $!renderer.crossrefs{$_} = $text for @indices;

                $text
                  ?? qq[<a name="$index-name-attr"><span class="index-entry">$text\</span></a>]
                  !! qq[<a name="$index-name-attr"></a>]
            }

            # Stuff I haven't figured out yet
            default {
                debug {
                    note colored("missing handling for a formatting code of type ", "red")
                      ~ $node.type
                }
                qq{<kbd class="pod2html-todo">$node.type()&lt;}
                  ~ self.node2inline($node.contents)
                  ~ q{&gt;</kbd>}
            }
        }
    }

    multi method node2inline(Positional:D $node --> Str:D) {
        $node.map({ self.node2inline($_) }).join
    }

    multi method node2inline(Str:D $node --> Str:D) {
       escape_html($node);
    }

    # block level or below
    proto method node2html(|) {*}
    multi method node2html($node --> Str:D) {
        debug {
            note colored("Generic node2html called for ", "bold")
              ~ $node.raku
        }
        self.node2inline($node)
    }

    multi method node2html(Pod::Block::Declarator:D $node --> Str:D) {
        given $node.WHEREFORE {
            when Routine {
                "<article>\n"
                  ~ '<code class="pod-code-inline">'
                  ~ node2text(.name ~ .signature.raku)
                  ~ "</code>:\n"
                  ~ self.node2html($node.contents)
                  ~ "\n</article>\n";
            }
            default {
                debug {
                    note "I don't know what $node.WHEREFORE.WHAT.raku() is. Assuming class..."
                }
                "<h1>"
                  ~ self.node2html([$node.WHEREFORE.raku, q{: }, $node.contents])
                  ~ "</h1>"
            }
        }
    }

    # NOTE: may return anything due to callbacks, so no --> in signature
    multi method node2html(Pod::Block::Code:D $node) {
        debug {
            note colored("Code node2html called for ", "bold")
              ~ $node.gist
        }

        if %*POD2HTML-CALLBACKS andthen .<code> -> &cb {
            cb :$node, default => sub ($node) {
                '<pre class="pod-block-code">'
                  ~ self.node2inline($node.contents)
                  ~ "</pre>\n"
            }
        }
        else {
            '<pre class="pod-block-code">'
              ~ self.node2inline($node.contents)
              ~ "</pre>\n"
        }

    }

    multi method node2html(Pod::Block::Comment:D $node --> Str:D) {
        debug {
            note colored("Comment node2html called for ", "bold")
              ~ $node.gist
        }
        ''  # UNCOVERABLE
    }

    multi method node2html(Pod::Block::Named:D $node --> Str:D) {
        debug {
            note colored("Named Block node2html called for ", "bold")
              ~ $node.gist
        }
        given $node.name {
            when 'config' {
                ''
            }
            when 'nested' {
                qq{<div class="nested">\n}
                  ~ self.node2html($node.contents)
                  ~ qq{\n</div>\n}
            }
            when 'output' {
                qq[<pre class="pod-block-named-outout">\n]
                  ~ self.node2inline($node.contents)
                  ~ "</pre>\n"
            }
            when 'pod' {
                $node.config<class>
                  ?? qq[<span class="{ $node.config<class> }">\n{ self.node2html($node.contents) }</span>\n]
                  !! self.node2html($node.contents)
            }
            when 'para' {
                self.node2html($node.contents[0], |$node.config)
            }
            when 'Image' {
                my $url;
                if $node.contents == 1 {
                    my $n = $node.contents[0];
                    if $n ~~ Str {
                        $url = $n;
                    }
                    elsif ($n ~~ Pod::Block::Para) && $n.contents == 1 {
                        $url = $n.contents[0] if $n.contents[0] ~~ Str;
                    }
                }
                without $url {
                    die "Found an Image block, but don't know how to extract the image URL";
                }
                qq[<img src="$url" />]
            }
            when 'Xhtml' | 'Html' {
                unescape_html ($node.contents.map({ node2rawtext $_ }).join)
            }
            default {
                # A named block, specifically a semantic block.  Semantic
                # blocks (https://docs.raku.org/language/pod#Semantic_blocks)
                # are collected and supplied to templates as a poor man's YAML
                # metadata
                if $node.name.match(/^<[A..Z]>+$/)
                  && $node.contents.elems == 1
                  && $node.contents.head ~~ Pod::Block::Para {  # UNCOVERABLE
                    $!renderer.metadata{$node.name.lc} = node2text($node.contents);
                    ''
                }
                # any other named block
                else {
                    '<section>'
                      ~ "<h1>{ $node.name }</h1>\n"
                      ~ self.node2html($node.contents)
                      ~ "</section>\n"
                }
            }
        }
    }

    multi method node2html(Pod::Block::Para:D $node --> Str:D) {
        debug {
            note colored("Para node2html called for ", "bold")
              ~ $node.gist
        }
        '<p>' ~ self.node2inline($node.contents) ~ "</p>\n"
    }

    multi method node2html(Pod::Block::Table:D $node --> Str:D) {
        debug {
            note colored("Table node2html called for ", "bold")
              ~ $node.gist
        }
        my @r = $node.config<class>
          ?? '<table class="pod-table ' ~ $node.config<class> ~ '">'
          !! '<table class="pod-table">';

        if $node.caption -> $c {
            @r.push("<caption>{ self.node2inline($c) }</caption>");
        }

        if $node.headers {
            @r.push(
              '<thead><tr>',
              $node.headers.map(-> $cell {
                  "<th>{ self.node2html($cell) }</th>"
              }),
              '</tr></thead>'
            );
        }

        @r.push(
          '<tbody>',
          $node.contents.map(-> $line {
            '<tr>',
            $line.list.map(-> $cell {
            "<td>{ self.node2html($cell) }</td>"
            }),
            '</tr>'
          }),
          '</tbody>',
          '</table>'
        );

        @r.join("\n")
    }

    multi method node2html(Pod::Config:D $node --> Str:D) {
        debug {
            note colored("Config node2html called for ", "bold")
              ~ $node.raku
        }
        ''
    }

    multi method node2html(Pod::DefnList $node --> Str:D) {
        "<dl>\n" ~ self.node2html($node.contents) ~ "\n</dl>\n"
    }
    multi method node2html(Pod::Defn $node --> Str:D) {
        "<dt>" ~ self.node2html($node.term) ~ "</dt>\n"
          ~ "<dd>" ~ self.node2html($node.contents) ~ "</dd>\n"
    }

    # TODO: would like some way to wrap these and the following content
    # in a <section>; this might be the same way we get lists working...
    multi method node2html(Pod::Heading:D $node --> Str:D) {
        debug {
            note colored("Heading node2html called for ", "bold")
              ~ $node.gist
        }
        my $lvl = min($node.level, 6);
        #= HTML only has 6 levels of numbered headings
        my %escaped =
          id => escape_id(node2rawtext($node.contents)),
          html => self.node2inline($node.contents);

        %escaped<uri> = uri_escape %escaped<id>;

        my $content;
        if %escaped<html> ~~ m{href .+ \<\/a\>} {
            $content = %escaped<html>;
        }
        else {
            $content =
              qq[<a class="u" href="#___top" title="go to top of document">]
              ~ %escaped<html>
              ~ qq[</a>];
        }

        "<h$lvl id={"\"%escaped<id>\""}>$content\</h$lvl>\n";
    }

    # FIXME
    multi method node2html(Pod::List:D $node --> Str:D) {
        '<ul>' ~ self.node2html($node.contents) ~ "</ul>\n"
    }
    multi method node2html(Pod::Item:D $node --> Str:D) {
        debug {
            note colored("List Item node2html called for ", "bold")
              ~ $node.gist
        }
        '<li>' ~ self.node2html($node.contents) ~ "</li>\n"
    }

    multi method node2html(Positional:D $node --> Str:D) {
        debug {
            note colored("Positional node2html called for ", "bold")
              ~ $node.gist
        }
        $node.map({ self.node2html($_) }).join
    }

    multi method node2html(Str:D $node --> Str:D) {
        escape_html($node);
    }
}

sub pod2html($pod, *%nameds --> Str:D) is export {
    Pod::To::HTML.new(|%nameds).render($pod)
}

sub node2html(*@pos, *%nameds --> Str:D) is export {
    Node::To::HTML.new(:renderer(Pod::To::HTML.new)).node2html(|@pos, |%nameds)
}

proto sub render(|) is export {*}
multi sub render(
  Any:D $pod,
  Str  :$title,
  Str :$subtitle,
  Str :$lang,
  Str :$template,
  Str :$main-template-path = '',
  *%template-vars
--> Str:D) {
    die 'Can load only Pod::Block objects or an Array of such'
      unless $pod ~~ Pod::Block:D | Array:D;
    Pod::To::HTML.new(
      :$title, :$subtitle, :$lang, :$template, :$main-template-path, |%template-vars
    ).render($pod)
}
multi sub render(
  $file where Str | IO::Path,
  *%nameds
--> Str:D) {
    render((load($file)), |%nameds)
}

# FIXME: this code's a horrible mess. It'd be really helpful to have a
# module providing a generic way to walk a Pod tree and invoke callbacks
# on each node, that would reduce the multispaghetti at the bottom to
# something much more readable

my $debug := %*ENV<P6DOC_debug> // %*ENV<RAKUDO_DEBUG>;

sub debug(&message) { message() if $debug }

sub escape_html(Str $str --> Str) {
    $str ~~ /<[ & < > " ' {   ]>/ || $str ~~ / ' ' /
      ?? $str.trans:
           [q{&},     q{<},    q{>},    q{"},      q{'},     q{ }     ] =>
           [q{&amp;}, q{&lt;}, q{&gt;}, q{&quot;}, q{&#39;}, q{&nbsp;}]
      !! $str
}

sub unescape_html(Str $str --> Str) {
    $str.trans:
      [rx{'&amp;'}, rx{'&lt;'}, rx{'&gt;'}, rx{'&quot;'}, rx{'&#39;'}] =>
      [q{&},        q{<},       q{>},       q{"},         q{'}       ]
}

sub escape_id ($id) is export {
    $id.trim
      .subst(/\s+/, '_', :g)
      .subst('"', '&quot;', :g)
      .subst('&nbsp;', '_', :g)
      .subst('&#39;', "'", :g)
}

multi visit(Nil, |a) {
    debug {
        note colored("visit called for Nil", "bold")
    }
}

multi visit($root, :&pre, :&post, :&assemble = -> *% { Nil }) {
    debug {
        note colored("visit called for ", "bold")
          ~ $root.raku
    }
    my ($pre, $post);
    $pre = pre($root) if defined &pre;

    my @content = $root.?contents.map: { visit $_, :&pre, :&post, :&assemble }
    $post = post($root, :@content) if defined &post;

    assemble(:$pre, :$post, :@content, :node($root))
}

#try require Term::ANSIColor <&colored>;
#if &colored.defined {
# &colored = -> $t, $c { $t };
#}

sub colored($text, $how) { $text }

sub assemble-list-items(:@content, :$node, *%) {
    my @newcont;
    my $found-one = False;
    my $ever-warn = False;

    my $at-level = 0;
    my @push-alias;

    my sub oodwarn($got, $want) {
        unless $ever-warn {
            warn "=item$got without preceding =item$want found!";
            $ever-warn = True;
        }
    }

    for @content {
        when Pod::Item {
            $found-one = True;

            # here we deal with @newcont being empty (first list), or with the
            # last element not being a list (new list)
            unless +@newcont && @newcont[*-1] ~~ Pod::List {
                @newcont.push(Pod::List.new());
                if $_.level > 1 {
                    oodwarn($_.level, 1);
                }
            }

            # only bother doing the binding business if we're at a different
            # level than previous items
            if $_.level != $at-level {
                # guaranteed to be bound to a Pod::List (see above 'unless')
                @push-alias := @newcont[*-1].contents;

                for 2 .. ($_.level) -> $L {
                    unless +@push-alias && @push-alias[*-1] ~~ Pod::List {
                        @push-alias.push(Pod::List.new());
                        if +@push-alias == 1 { # we had to push a sublist to a list with no =items
                            oodwarn($OUTER::_.level, $L);
                        }
                    }
                    @push-alias := @push-alias[*-1].contents;
                }

                $at-level = $_.level;
            }

            @push-alias.push($_);
        }
        # This is simpler than lists because we don't need to
        # list
        when Pod::Defn {
            $found-one = True;
            unless +@newcont && @newcont[*-1] ~~ Pod::DefnList {
                @newcont.push(Pod::DefnList.new());
            }
            @newcont[*-1].contents.push($_);
        }

        default {
            @newcont.push($_);
            $at-level = 0;
        }
    }

    $found-one
      ?? $node.clone(contents => @newcont)
      !! $node
}

sub retrieve-templates($template-path, $main-template-path --> List:D) {
    sub get-partials($template-path --> Hash:D) {
        my $partials-dir = 'partials';
        my %partials;
        for dir($template-path.IO.add($partials-dir)) -> $partial {
            %partials{$partial.basename.subst('\.mustache')} =
              $partial.IO.slurp;
        }
        %partials
    }

    my $template-file = %?RESOURCES<templates/main.mustache>;
    my %partials;

    with $template-path {
        if "$template-path/main.mustache".IO ~~ :f {
            $template-file = $template-path.IO.add('main.mustache').IO;

            if $template-path.IO.add('partials').d {
                %partials = get-partials($template-path);
            }
        }
        else {
            note "$template-path does not contain required templates. Using default.";
        }
    }

    if $main-template-path {
        $template-file = $main-template-path.IO;
    }

    $template-file, %partials
}

monitor TOC::Calculator {
    has     $.pod is required;
    has int @.levels = 0;

    proto method find-headings($node, :$inside-heading) {*}

    multi method find-headings(Str:D $s is raw, :$inside-heading) {
        $inside-heading
          ?? { plain => $s.&escape_html }
          !! ()
    }

    multi method find-headings(
      Pod::FormattingCode:D $node is raw where *.type eq 'C', :$inside-heading
    ) {
        $inside-heading
          ?? %(coded => $node.contents.map({
                 self.find-headings($_, :$inside-heading)
               }).List
             )
          !! ()
    }

    multi method find-headings(Pod::Heading:D $node is raw, :$inside-heading) {
        @!levels.splice($node.level) if $node.level < +@!levels;
        @!levels[$node.level - 1]++;
        my $level-hierarchy = @!levels.join('.');
        # e.g. §4.2.12
        my @text = $node.contents.map: {
            self.find-headings($_, :inside-heading)
        }
        my $link := escape_id(node2text($node.contents));
        %(level => $node.level, :$level-hierarchy, :@text, :$link)
    }

    multi method find-headings(Positional:D \list, :$inside-heading) {
        list.map({
            self.find-headings($_, :$inside-heading)
        }).Array.Slip
    }

    multi method find-headings(Pod::Block:D $node is raw, :$inside-heading) {
        $node.contents.map({
            self.find-headings($_, :$inside-heading)
        }).Array.Slip
    }

    multi method find-headings(Pod::Config:D $node, :$inside-heading) {
        %()
    }

    multi method find-headings(Pod::Raw:D $node is raw, :$inside-heading) {
        $node.contents.map({
            self.find-headings($_, :$inside-heading)
        }).Array.Slip
    }

    method calculate() {
        self.find-headings($!pod).grep(*.Bool)
    }

    method render(--> Str:D) {
        my $toc    := self.calculate;
        my $result := $toc.map({
            qq[<tr class="toc-level-$_<level>"><td class="toc-number">$_<level-hierarchy>\</td><td class="toc-text"><a href="#$_<link>">{
              self.render-heading($_<text>)
            }\</a></td></tr>\n]
        }).join.trim;

        $result
          ?? qq:to/EOH/
             <nav class="indexgroup">
             <table id="TOC">
             <caption><h2 id="TOC_Title">Table of Contents</h2></caption>
             $result
             </table>
             </nav>
             EOH
          !! ''
    }

    method render-heading($heading) {
        if $heading ~~ Positional {
            $heading.map({ self.render-heading($_) }).join
        }
        elsif $heading ~~ Associative {
            with $heading<plain> -> $plain {
                return $plain;  # not sure why the return is needed here
            }
            orwith $heading<coded> {
                "<code class=\"pod-code-inline\">{ self.render-heading($_) }</code>"
            }
        }
    }
}

# HTML-escaped text
my sub node2text($node --> Str:D) {
    debug {
        note colored("Generic node2text called with ", "red")
          ~ $node.raku
    }

    given $node {
        when Pod::Block::Para {
            node2text($node.contents)
        }
        when Pod::Raw {
            $node.target.?lc eqv 'html'
              ?? $node.contents.join
              !! ''
        }
        when Positional {
            $node.map(&node2text).join
        }
        default {
            escape_html(node2rawtext($node))
        }
    }
}

# plain, unescaped text
sub node2rawtext($node --> Str:D) is export {
    debug {
        note colored("Generic node2rawtext called with ", "red")
          ~ $node.raku
    }
    given $node {
        when Pod::Block {
            node2rawtext($node.contents)
        }
        when Positional {
            $node.map(&node2rawtext).join
        }
        default {
            $node.Str
        }
    }
}

# vim: expandtab shiftwidth=4
