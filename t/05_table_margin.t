use v5.14;
use warnings;
use utf8;
use Test::More 0.98;

use lib './t';
use ac;
use Encode qw(decode_utf8);

# do not read the rc file of the user
use File::Spec;
$ENV{HOME} = File::Spec->rel2abs('t/home');

# In a column that has a cell wider than the width, cells are wrapped
# before the run-in margin, as lines are in panes.  A cell that fits
# only by using the margin is wrapped too, unless it ends with a
# character that runs in.  A column with no over-wide cell is left as
# it is (--cell 10, run-in 2).

sub out {
    my $d = ac->new(qw(-t -s | --table-remove=1,-0 --cell 10))->exec(shift);
    utf8::is_utf8($d) ? $d : decode_utf8($d);
}

is(out("|aaaaaaaaa|\n|bbbbbbbbbbbbbbb|\n"), <<'END', 'cell in the margin is wrapped');
aaaaaaaa
a
bbbbbbbb
bbbbbbb
END

is(out("|aaaaaaaaa|\n|bb|\n"), <<'END', 'column without over-wide cell is not wrapped');
aaaaaaaaa
bb
END

is(out("|あいうえ。|\n|かきくけこさしすせそ|\n"), <<'END', 'run-in character stays in the margin');
あいうえ。
かきくけ
こさしす
せそ
END

done_testing;
