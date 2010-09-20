use strict;
use warnings;
use Test::Base tests => 7;
use HTML::Split;

filters {
    input    => [ qw( chomp ) ],
    expected => [ qw( lines chomp array ) ],
};

sub paginate {
    my $len = filter_arguments;
    return [
        HTML::Split->split(
            html   => $_,
            length => $len,
            relax  => 1,
        ),
    ];
}

run_compare;

__END__

===
--- input paginate=20
<p>0123 4567 89AB CDEF GHIJ KLMN</p>
--- expected
<p>0123 4567 89AB</p>
<p>CDEF GHIJ KLMN</p>

=== included bound char in last word in the sentence
--- input paginate=20
<p>0123 4567 89AB CD-EF GHIJ KLMN</p>
--- expected
<p>0123 4567 89AB</p>
<p>CD-EF GHIJ KLMN</p>

=== included bound char in last word in the sentence
--- input paginate=20
<p>0123 4567 89AB CD,EF GHIJ KLMN</p>
--- expected
<p>0123 4567 89AB</p>
<p>CD,EF GHIJ KLMN</p>

=== last word in the sentence
--- input paginate=20
<p>0123 4567 89AB CDEF, GHIJ KLMN</p>
--- expected
<p>0123 4567 89AB CDEF,</p>
<p>GHIJ KLMN</p>

=== last word in the sentence
--- input paginate=20
<p>Wow, I got $1,234,567,890!! Go, Test Go.</p>
--- expected
<p>Wow, I got $1,234,567,890!!</p>
<p>Go, Test Go.</p>

=== include bound cahr in last word and splitted in it in the sentence
--- input paginate=20
<p>The Split Test CO.,LTD. All rights reserved.</p>
--- expected
<p>The Split Test CO.,LTD.</p>
<p>All rights reserved.</p>

=== japanse is not available
--- input paginate=20
<p>テストです。０１２３。たんごくぎりをさがす。</p>
--- expected
<p>テストです。０１２３。たんごくぎり</p>
<p>をさがす。</p>
