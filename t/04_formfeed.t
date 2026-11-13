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

# A formfeed in a color, as bat gives for a line with a formfeed alone.
# It once made the tab expansion run forever (Text::ANSI::Fold before
# 2.3901 gave the same text back as the rest).  The colors around it go
# with it, so the panes are those of a plain formfeed.
{
    local $SIG{ALRM} = sub { die "timeout\n" };
    alarm 30;
    my $out = eval { panes("\e[31ma\e[m\n\e[31m\f\e[m\n\e[31mb\e[m\n") };
    alarm 0;
    is($@, '', 'formfeed in a color ends');
    is($out =~ s/\e\[[\d;]*m//gr, <<'END', 'formfeed alone in a color');
a         b



END
}

sub plain { $_[0] =~ s/\e\[[\d;]*m//gr }

is(plain(panes("\e[31ma\e[m\n\e[31m\fb\e[m\nc\n")), <<'END', 'formfeed in a color before text');
a         b
          c


END

# a color is not carried over a formfeed, as it is not over a newline
{
    my $out = panes("\e[31ma\fb\e[m\n");
    is(plain($out), <<'END', 'formfeed in the middle of a color');
a         b



END
    unlike($out, qr/\e\[31mb/, 'the color ends at the formfeed');
}

# A part without a line is an empty page and takes a pane: the one
# before a formfeed at the top, and the one between two formfeeds.
# Nothing follows the formfeed at the end.
is(panes("\fa\n\f\f\nb\n\f"), <<'END', 'empty pages');
          a



b
END

is(panes("a\n\f\fb\n"), <<'END', 'an empty page between formfeeds');
a                   b



END

# the empty lines around a formfeed are lines, and those at the top of
# a pane are removed as usual (-D)
is(panes("a\n\n\f\n\nb\nc\n"), <<'END', 'empty lines around a formfeed');
a         b
          c


END

# formfeeds alone are no text, the same as an empty file
is(panes("\f\n"), '', 'formfeed alone');
is(panes("\f\n\f\n"), '', 'formfeeds alone');

# A formfeed is the top of the next part, and the newline after it is
# an empty line there.  It is seen unless the white spaces at the top
# of a pane are removed.
sub keep {
    my $stdin = shift;
    ac->new(qw(-C2 --height=2 -c20), @_)->exec($stdin);
}

is(keep("a\n\fb\n"), <<'END', 'formfeed at the top of a line');
a       b

END

is(keep("a\n\f\nb\n"), <<'END', 'formfeed alone on a line');
a
        b
END

is(keep("a\n\f\nb\n", '--no-white-space'), <<'END', 'formfeed alone on a line, --no-white-space');
a       b

END

# a part with empty lines alone has no line, as such a file has none,
# and is an empty page
is(keep("a\n\f\n\n\fb\n"), <<'END', 'empty lines between formfeeds');
a

b
END

# colors around formfeeds, as bat gives, make no difference
is(panes("a\n\e[31m\f\f\e[m\nb\n"), panes("a\n\f\f\nb\n"),
   'formfeeds one after another in a color');

done_testing;
