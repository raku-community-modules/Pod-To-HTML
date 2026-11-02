my sub escape_html(Str:D $str) {
    $str.subst('&', '&amp;', :g).subst('<', '&lt;', :g
         ).subst('>', '&gt;', :g).subst('"', '&quot;', :g
         ).subst("'", '&#39;', :g);
}

my sub escape(Str:D $str, Str:D $how) is export {
    given $how.lc {
        when 'none'         { $str }
        when 'html'         { escape_html($str) }
        when 'uri' | 'url'  { escape_str($str, &escape_uri_char)  }
        default { fail "Don't know how to escape format $how yet" }
    }
}

my sub escape_uri_char(Str:D $c --> Str:D) {
    return q{+} if $c eq q{ };

    my constant $allowed = 'abcdefghijklmnopqrstuvwxyz'
                ~ 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
                ~ '0123456789'
                ~ q{-_.!~*'()};

    return $c if defined $allowed.index($c);

    # TODO: each char should be UTF-8 encoded, then its bytes %-encoded
    q{%} ~ ord($c).fmt('%x');
}

sub escape_str(Str:D $str, &callback --> Str:D) {
    my $result = '';
    for ^$str.chars -> $index {
        $result ~= $callback($str.substr: $index, 1)
    }
    $result
}

# vim: expandtab shiftwidth=4
