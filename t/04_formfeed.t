use v5.14;
use warnings;
use Test::More 0.98;

use lib './t';
use ac;

# do not read the rc file of the user
use File::Spec;
$ENV{HOME} = File::Spec->rel2abs('t/home');

# A formfeed moves to the top of the next pane.  The lines are laid out
# in panes of 4 lines, three panes in a row (-D -C3 --height=4 -c30).

sub panes {
    my $stdin = shift;
    ac->new(qw(-D -C3 --height=4 -c30), @_)->exec($stdin);
}

# The blank line at the top of the second pane is removed, which pulls
# the line with the formfeed into the second pane.  It still has to
# start the third pane.
is(panes("a\nb\nc\nd\n\ne\nf\ng\n\fX\nY\n"), <<'END', 'formfeed after a removed blank line');
a         e         X
b         f         Y
c         g
d
END

ok(panes("a\nb\nc\nd\n\ne\nf\ng\n\fX\nY\n") !~ /\f/, 'no formfeed in the output');

# Text before a formfeed ends the pane, text after it starts the next.
is(panes("a\nb\nc\fd\ne\n"), <<'END', 'formfeed in the middle of a line');
a         d
b         e
c

END

# A formfeed at the top of a pane does not make an empty pane.
is(panes("a\nb\nc\nd\n\fe\nf\n"), <<'END', 'formfeed at the top of a pane');
a         e
b         f
c
d
END

# --no-pagebreak: a formfeed is not a pane break.
unlike(panes("a\fb\n", '--no-pagebreak'), qr/^b/m, '--no-pagebreak');

done_testing;
