use v5.14;
use warnings;
use Test::More 0.98;

use lib './t';
use ac;

# do not read the rc file of the user
use File::Spec;
$ENV{HOME} = File::Spec->rel2abs('t/home');

# --pages: the parts between formfeeds are files of their own.  With
# -V they stand side by side, as mdee gives one page for each file.

sub pages {
    my $stdin = shift;
    ac->new(qw(--pages -V --no-filename --border=none -C3 -c30), @_)->exec($stdin);
}

# what mdee gives: a formfeed just before the first line of the next file
is(pages("a\nb\n\fc\nd\n\fe\n"), <<'END', 'a formfeed before each file');
a         c         e
b         d
END

is(pages("a\nb\fc\nd\n"), <<'END', 'a formfeed in the middle of a line');
a         c
b         d
END

# an empty part keeps its place, as an empty file does
is(pages("a\n\f\fc\n"), <<'END', 'an empty part');
a                   c
END

is(pages("\fa\n"), <<'END', 'an empty part at the top');
          a
END

# nothing follows the last formfeed
is(pages("a\n\fb\n\f"), <<'END', 'a formfeed at the end');
a         b
END

# without -V, every part begins a new page
is(ac->new(qw(--pages -C2 --height=2 -c20))->exec("a\nb\nc\n\fd\n"), <<'END', 'every part begins a new page');
a       c
b
d
END

done_testing;
