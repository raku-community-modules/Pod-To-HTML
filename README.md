Pod::To::HTML v0.8.1
====================

[![Test in a Raku container](https://github.com/Raku/Pod-To-HTML/actions/workflows/test.yaml/badge.svg)](https://github.com/Raku/Pod-To-HTML/actions/workflows/test.yaml)


Raku module to render Pod as HTML.

Synopsis
--------

From the command line:

    raku --doc=HTML lib/FancyModule.rakumod > FancyModule.html

From within Raku:

    use Pod::To::HTML:auth<github:Raku>;

    # Pod file
    say render(
        'your/file.pod'.IO,
        title => 'My Own Title',
        subtitle => 'On the Art of Making Titles',
        lang => 'en',
    );

Installation
------------

From the [Raku ecosystem](https://modules.raku.org):

    $ zef install Pod::To::HTML:author<github:Raku>

From source:

    $ git clone https://github.com/Raku/Pod-To-HTML.git
    $ cd Pod-To-HTML/
    $ zef install .

**Note**: Perl 6 2018.06 introduces changes on how non-breaking whitespace was handled; this is now included in the tests. If the installation fails, please upgrade to Perl 6 >= 2018.06 or simply disregard the test and install with `--force` if that particular feature is of no use to you.

**Note 2**: Perl6 2018.11 introduced handling of Definition blocks, `Defn`. Please upgrade if you are using that feature in the documentation.

Description
-----------

`Pod::To::HTML` takes a Pod tree and outputs correspondingly formatted HTML using a default or provided Mustache template. There are two ways of accomplishing this:

* from the command line, using `raku --doc=HTML`, which extracts the Pod from the document and feeds it to `Pod::To::HTML`.

* from within a Raku program via the exported `render` subroutine, which creates a complete HTML document from the Pod. This allows more customization (`title`, `subtitle`, and `lang` can override Pod's corresponding semantics, different Mustache template (possibly with partials), additional template variables for the template, etc.) than simply rendering the Pod via `raku --doc=HTML` which just use the default template.

Exported subroutines
--------------------

**`render`**: Render a Pod document from several sources. `title`, `subtitle`, and `lang` are supplied to the Mustache template and override the Pod document's corresponding semantic blocks. A `template` path can be passed; the Mustache template `main.mustache` must be under that path. Partials to the template must be under the same path in a directory named `partials`.

  * `render(Array $pod, Str :$title, Str :$subtitle, Str :$lang, Str :$template = Str, *%template-vars)`

  * `render(Pod::Block $pod, Str :$title, Str :$subtitle, Str :$lang, Str :$template = Str, *%template-vars)`

  * `render(IO::Path $file, Str :$title, Str :$subtitle, Str :$lang, Str :$template = Str, *%template-vars)`

  * `render(Str $pod-string, Str :$title, Str :$subtitle, Str :$lang, Str :$template = Str, *%template-vars)`

Template information
--------------------

`Pod::To::HTML` makes the following information available to the Mustache template:

  * `title`: This is picked up from the Pod's semantic block `=TITLE` (if any), although it can be overridden by supplying it via `render`. It defaults to the empty string.

  * `subtitle`: This is picked up from the Pod's semantic block `=SUBTITLE` (if any), although it can be overridden by supplying it via `render`. It defaults to the empty string.

  * `lang`: This is picked up from the Pod's semantic block `=LANG` (if any), although it can be overridden by supplying it via `render`. It defaults to the `en`.

  * `toc`: The Pod document's table of contents.

  * `footnotes`: The Pod document's [footnotes](https://docs.raku.org/language/pod#Notes).

Additional information can be made available to the Mustache template by supplying to `render` as named arguments. For example, `css-url => https://design.raku.org/perl.css` will be available to the template as `css-url`.

### Semantic Blocks

Semantic blocks are treated as metadata and supplied as such to a Mustache template. For example, from the Pod document:

    =begin pod
    =TITLE Classes and objects
    =SUBTITLE A tutorial about creating and using classes in Raku
    =LANG English
    =DATE January 01, 2020
    =end pod

the template variables `title`, `subtitle`, `lang`, and `date` are made available to a Mustache template. Both `title` and `subtitle` can be overridden via the `render` subroutine.

**Note**: Pod's semantic blocks can be overridden via `render` by using a variable of the same name.

Examples
--------

Check the [examples](resources/examples/README.md) directory (which should have been installed with your distribution, or is right here if you download from source) for a few illustrative examples. 

Debugging
---------

You can set the `P6DOC_DEBUG` environmental variable to make the module produce some debugging information.

    P6DOC_DEBUG=1 raku --doc=HTML lib/FancyModule.rakumod > FancyModule.html

License
-------

You can use and distribute this module under the terms of the The Artistic License 2.0. See the LICENSE file included in this distribution for complete details.

The `META6.json` file of this distribution may be distributed and modified without restrictions or attribution.
