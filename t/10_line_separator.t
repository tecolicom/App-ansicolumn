use v5.14;
use warnings;
use utf8;
use Test::More 0.98;

use lib './t';
use ac;
use Encode qw(encode_utf8 decode_utf8);

# do not read the rc file of the user
use File::Spec;
$ENV{HOME} = File::Spec->rel2abs('t/home');

# U+2028 LINE SEPARATOR in a cell of the table mode breaks the cell
# into lines; elsewhere it ends a line as before.

my $LS = "\x{2028}";

sub out {
    my($in, @opt) = @_;
    my $d = ac->new(@opt)->exec($in);
    utf8::is_utf8($d) ? $d : decode_utf8($d);
}

my @T = (qw(-t -s |), q(-o), q(|));

is(out("k1|one${LS}three\nk2|x\n", @T),
   "k1|one\n  |three\nk2|x\n",
   'a cell is broken into lines, the row stays one row');

is(out("k1|a${LS}bb${LS}ccc|z\nk2|x|y\n", @T),
   "k1|a  |z\n  |bb |\n  |ccc|\nk2|x  |y\n",
   'the width of the column is the widest line, other cells are padded');

is(out("k1|a|p${LS}q\nk2|b${LS}c|r\n", @T),
   "k1|a|p\n  | |q\nk2|b|r\n  |c|\n",
   'the row is as tall as its tallest cell');

is(out("k1|a${LS}${LS}b\n", @T),
   "k1|a\n  |\n  |b\n",
   'an empty line in a cell');

is(out("k1|a${LS}\n", @T),
   "k1|a\n  |\n",
   'a separator at the end of a cell gives an empty last line');

is(out("one${LS}two\nthree\n", qw(-c 20)),
   out("one\ntwo\nthree\n", qw(-c 20)),
   'outside the table mode it ends a line as before');

# with -w, every line of a cell is wrapped on its own
my $wide = "k1|the quick brown fox${LS}jumps over the lazy dog\n";
my $w = out($wide, @T, qw(-w 16));
is($w,
   "k1|the quick\n  |brown fox\n  |jumps over\n  |the lazy dog\n",
   'with -w the lines of a cell are wrapped one by one');

# --table-wrap-mark marks wrapped lines only, not the lines of a
# cell given by the separator
my $m = out($wide, @T, qw(-w 16), q(--table-wrap-mark), encode_utf8("\x{b7}"));
is($m,
   "k1|the quick\n  |\x{b7}brown fox\n  |jumps over\n  |\x{b7}the lazy dog\n",
   'wrap-mark is not put on a line started by the separator');

# --table-cell-mark marks the first line of a cell, in a column which
# has a cell of more than one line, whether by wrapping or by the
# separator
my $c = out("k1|one${LS}two\nk2|three\n", @T, q(--table-cell-mark=+));
is($c,
   "k1|+one\n  |two\nk2|+three\n",
   'cell-mark: the first line of every cell in a broken column');

my $h = out("h|head\nk1|one${LS}two\n", @T, q(--table-cell-mark=+), q(--table-head=1));
is($h,
   "h |head\nk1|+one\n  |two\n",
   'cell-mark: a header row has no mark');

# a color over the separator is closed at the end of the line and
# opened again on the next
is(out("k|\e[1mone${LS}two\e[m|z\n", @T),
   "k|\e[1mone\e[m|z\n |\e[1mtwo\e[m|\n",
   'a color over the separator is closed and opened again');

# with spaces between columns, a LINE SEPARATOR is not one of them
is(out("k one${LS}two z\nkk x y\n", qw(-t -o |)),
   "k |one|z\n  |two|\nkk|x  |y\n",
   'space separator: the separator breaks the cell');

done_testing;
