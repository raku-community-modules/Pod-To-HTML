[![Actions Status](https://github.com/raku-community-modules/Pod-To-HTML/actions/workflows/linux.yml/badge.svg)](https://github.com/raku-community-modules/Pod-To-HTML/actions) [![Actions Status](https://github.com/raku-community-modules/Pod-To-HTML/actions/workflows/macos.yml/badge.svg)](https://github.com/raku-community-modules/Pod-To-HTML/actions) [![Actions Status](https://github.com/raku-community-modules/Pod-To-HTML/actions/workflows/windows.yml/badge.svg)](https://github.com/raku-community-modules/Pod-To-HTML/actions)

Pod::To::HTML
=============

Raku module to render Pod as HTML.

Synopsis
--------

From the command line:

    $ raku --doc=HTML lib/FancyModule.rakumod > FancyModule.html

From within Raku:

```raku
use Pod::To::HTML;

# Pod file
say render(
    'your/file.pod'.IO,
    title => 'My Own Title',
    subtitle => 'On the Art of Making Titles',
    lang => 'en',
);
```

Installation
------------

From the [Raku ecosystem](https://modules.raku.org):

    $ zef install Pod::To::HTML

From source:

    $ git clone https://github.com/raku-community-modules/Pod-To-HTML.git
    $ cd Pod-To-HTML/
    $ zef install .

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

Additional information can be made available to the Mustache template by supplying to `render` as named arguments.

### Semantic Blocks

Semantic blocks are treated as metadata and supplied as such to a Mustache template. For example, from the Pod document:

```raku
=begin pod
=TITLE Classes and objects
=SUBTITLE A tutorial about creating and using classes in Raku
=LANG English
=DATE January 01, 2020
=end pod
```

The template variables `title`, `subtitle`, `lang`, and `date` are made available to a Mustache template. Both `title` and `subtitle` can be overridden via the `render` subroutine.

**Note**: Pod's semantic blocks can be overridden via `render` by using a variable of the same name.

Examples
--------

Check the [examples](resources/examples/README.md) directory (which should have been installed with your distribution, or is right here if you download from source) for a few illustrative examples. 

Debugging
---------

You can set the `RAKUDOC_DEBUG` environmental variable to make the module produce some debugging information.

    RAKUDOC_DEBUG=1 raku --doc=HTML lib/FancyModule.rakumod > FancyModule.html

AUTHORS
=======

  * Anthony Parsons

  * Moritz Lenz

  * Timo Paulssen

  * Alex Moquin

  * Wenzel P. P. Peppmeyer

  * Zoffix Znet

  * Alex Chen

  * JJ Merelo

  * Jonathan Stowe

  * Richard Hainsworth

  * Antonio Gamiz

  * Oleksander Kiryuhin

  * Elizabeth Mattijsen

And many other Raku Community members.

Source can be located at: https://github.com/raku-community-modules/Pod-To-HTML . Comments and Pull Requests are welcome.

COPYRIGHT AND LICENSE
=====================

Copyright 2011-2025 Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

The `META6.json` file of this distribution may be distributed and modified without restrictions or attribution.

