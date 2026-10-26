use v5.14;
use warnings;
use utf8;
use Test::More 0.98;

use lib './t';
use App::ansicolumn;

######################################################################
# table_widths: water-level allocation
######################################################################

sub tw { App::ansicolumn::table_widths(@_) }

is_deeply(tw([6,12,60,300], 74, 0, undef, 4), [6,12,28,28], 'worked example');
is_deeply(tw([6,12,60,300], 74, 2, undef, 4), [6,12,24,24], 'with item-format overhead');
is_deeply(tw([5,5], 20, 0, undef, 4),         [5,5],        'fits: unchanged');
is_deeply(tw([5,5], undef, 0, undef, 4),      [5,5],        'no budget: unchanged');
is_deeply(tw([50,50,50], 10, 0, undef, 4),    [4,4,4],      'floor');
is_deeply(tw([50,50], -3, 0, undef, 4),       [4,4],        'budget-negative');
is_deeply(tw([10,30,30], 40, 0, [undef,8,undef], 4), [10,8,22], 'fixed column removed from budget');
is_deeply(tw([3,3], undef, 0, [20,undef], 4), [20,3],       'fixed without budget');
is_deeply(tw([6,12,60,300], 75, 0, undef, 4), [6,12,28,29], 'leftover: longest content first');
is_deeply(tw([6,12,300,60], 75, 0, undef, 4), [6,12,29,28], 'leftover: follows content, not position');
is_deeply(tw([6,12,60,60], 75, 0, undef, 4),  [6,12,29,28], 'leftover: tie goes to the left column');
is_deeply(tw([30,30,30], 41, 0, [undef,8,undef], 4), [17,8,16], 'leftover: fixed column does not take it');
is_deeply(tw([50,50,50], 11, 0, undef, 4),    [4,4,4],      'leftover: none below floor');

######################################################################
# parse_cell_spec: --cell in table mode
######################################################################

sub pc { App::ansicolumn::parse_cell_spec(@_) }

is_deeply(pc(q(0,0,20), [5,5,50]),  [undef,undef,20], q(single constrained column));
is_deeply(pc(q(<20),    [8,50]),    [8,20],           q(upper bound, last repeated));
is_deeply(pc(q(20),     [8,50]),    [20,20],          q(fixed, last repeated));
is_deeply(pc(q(-10,+2), [30,5]),    [20,7],           q(relative to content));
is_deeply(pc(q(=),      [30]),      [30],             q(bare = is content width));
is_deeply(pc(q(10,20,30), [5,5]),   [10,20],          q(extra entries ignored));
eval { pc(q(abc), [5]) }; like($@, qr/^Invalid number: abc$/m, q(invalid token dies));

######################################################################
# CLI: wrapping in table mode
######################################################################

use ac;
use Encode qw(encode_utf8 decode_utf8);
use Data::Section::Simple qw(get_data_section);
use Text::ANSI::Fold::Util qw(ansi_width);
use File::Slurper qw(read_text);

sub out {
    my($in, @opt) = @_;
    my $d = ac->new(@opt)->exec($in);
    utf8::is_utf8($d) ? $d : decode_utf8($d);
}
sub widths { map { ansi_width($_) } split /\n/, shift }
sub cols   { map { [ split /\|/, $_, -1 ] } split /\n/, shift }

my $tbl = "|key|description|\n|k1|the quick brown fox jumps over the lazy dog|\n|k2|short|\n";
my @T = ('-t', '-s', '|', '--table-remove=1,-0');

is(out($tbl, @T, '-w', 80), out($tbl, @T), 'fits-identical');

for (
    [ 'wrap'        => [@T, '-w', 30] ],
    [ 'item-format' => [@T, '-w', 34, '-o', '|', '--item-format= %s '] ],
    [ 'right'       => [@T, '-w', 30, '--table-right=2'] ],
    [ 'cell-fixed'  => [@T, '--cell', '20,0', '-o', '|'] ],
) {
    my($name, $opt) = @$_;
    is(out($tbl, @$opt), get_data_section($name), $name);
}

{
    my $in = "|aaaa bbbb cccc dddd eeee|1111 2222 3333 4444 5555|\n" x 2;
    my $o = out($in, @T, '-w', 30);
    my @l = split /\n/, $o;
    is(scalar @l, 6, 'equal-level: 3 physical lines per row');
    my @c1 = map { /^(\S+(?: \S+)*)\s{2,}/ ? length $1 : 0 } @l;
    is((sort { $b <=> $a } @c1)[0], 9, 'equal-level: both columns share the level');
    ok(!(grep { $_ > 30 } widths($o)), 'equal-level: within width');
}

{
    my $row = "|j|ああああああああああ。いいいいいいいいいい、ううう|\n";
    my $o = out($row x 3, @T, '-w', 24);
    ok(!(grep { $_ > 24 } widths($o)), 'japanese: within width');
    unlike($o, qr/^\s*[。、]/m, 'japanese: no closing punctuation at line start');
    unlike($o, qr/^j\s+[。、]/m, 'japanese: no closing punctuation at cell start');
}

{
    my $in = "|k|\e[1mthe quick brown fox jumps over the lazy dog\e[m|\n" x 2;
    my $o = out($in, @T, '-w', 30);
    ok(!(grep { $_ > 28 } widths($o)), 'sgr: within width');
    my @bold = grep { /the|jumps/ } split /\n/, $o;
    ok(@bold >= 4 && !(grep { !/\e\[1m.*\e\[m/ } @bold), 'sgr: each physical line reopens and closes bold');
}

{
    my $o = out("|a|bbbbbbbbbbbbbbbbbbbbbbbbbbbb|\n|c||\n|d|e|\n", @T, '-w', 20);
    like($o, qr/^c\s*$/m, 'empty-cells: empty cell in a wrapping column stays one line');
    is(scalar(() = out("|||\n" x 3, @T, '-w', 20) =~ /\n/g), 3, 'empty-cells: all-empty rows give one line each');
}

is(ac->new('-t', '-A', '-w', 20)->exec("a bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n"),
   ac->new('-t', '-A')->exec("a bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n"), 'align-ignored');

{
    local $SIG{ALRM} = sub { die "timeout\n" };
    alarm 10;
    ok(length(out($tbl, @T, '-w', 3)) > 0, 'floor: produces output');
    for my $w (1, 2) {
        my $o = out($tbl, @T, '--cell', $w, '-o', '|');
        ok(length($o) > 0, "cell-tiny: --cell $w produces output");
        ok(!(grep { ansi_width($_->[0]) > $w } cols($o)), "cell-tiny: --cell $w column 1 width <= $w");
    }
    alarm 0;
}

{
    my $three = "|aaaaa|bbbbb|" . ("c" x 50) . "|\n" . "|a|b|c|\n";
    my $o = out($three, @T, '--cell', '0,0,20', '-o', '|');
    my @r = cols($o);
    ok(@r > 2 && !(grep { ansi_width($_->[2]) > 20 } @r), 'cell-auto: only column 3 is capped at 20');
    ok(!(grep { ansi_width($_->[0]) != 5 } @r), 'cell-auto: column 1 keeps its width');
}

{
    my $o = out($tbl, @T, '--cell', '<20', '-o', '|');
    my @r = cols($o);
    is(scalar @r, 5, 'cell-cap: 5 output lines');
    ok(!(grep { ansi_width($_->[0]) != 3 || ansi_width($_->[1]) > 20 } @r), 'cell-cap: 3 and <=20');
}

{
    my $three = "|aaaaa|" . ("b" x 40) . "|" . ("c d " x 15) . "|\n" x 2;
    my $o = out($three, @T, '--cell', '0,10', '-w', '60', '-o', '|');
    my @r = cols($o);
    ok(!(grep { ansi_width($_->[1]) != 10 } @r), 'cell-with-width: column 2 is exactly 10');
    ok(!(grep { $_ > 60 } widths($o)), 'cell-with-width: within total width');
}

{
    my $o = out("|a|b|c|\n|dddddddddddddddddddddddddd|\n", @T, '-w', 20);
    my @l = split /\n/, $o;
    is($l[0] =~ tr/\n//, 0, 'ragged: row 1 is one line');
    ok(@l >= 3 && !(grep { /\|/ } @l[1..$#l]), 'ragged: row 2 wraps without separators');
}

{
    my $o = out("|a|b|c|d|e|\n" x 3, '-t', '-s', '|', '-l', '3', '-w', 30);
    ok(length($o) > 0 && !(grep { $_ > 30 } widths($o)), 'limit: output within width');
    like($o, qr/b\|c\|d\|e\|/, 'limit: overflow cell keeps its separators');
}

{
    my $raw = ac->new(@T, '-w', 30, '--padding')->setstdin($tbl)->update->data;
    my @w = widths($raw);
    is(scalar(grep { $_ == $w[0] } @w), scalar @w, 'padding-wrap: all lines equal width');
}

is(ac->new('-V', '-c', '60', '--no-border', '--cell', '20,10', 't/data/para1.txt', 't/data/para2.txt')->exec(''),
   read_text('t/data/parallel-baseline.txt'), 'parallel-unchanged');

{
    my $link = "\e]8;;https://example.com\e\\the quick brown fox jumps over the lazy dog\e]8;;\e\\";
    my $o = out("|k|$link|\n" x 2, @T, q(-w), 30, q(--table-right=2), q(-o), q(|));
    my @vis = map { s/\e\]8;;[^\e]*\e\\//gr } split /\n/, $o;
    ok(@vis >= 4 && !(grep { /\h$/ } @vis), q(osc8-right: no trailing space hidden inside a hyperlink));
}

{
    # Column 1 wraps at a word boundary and leaves slack; column 2 is
    # hard-wrapped.  The slack goes back to column 2.
    my $in = "|aaaaaaaaaa bbbbbbbbbb|" . ("c" x 30) . "|\n" x 2;
    my $o = out($in, @T, '-w', 30, '-o', '|');
    my @r = cols($o);
    ok(!(grep { ansi_width($_->[0]) != 10 } @r), 'redistribute: column 1 keeps its wrapped width');
    is((sort { $b <=> $a } map { ansi_width($_->[1]) } @r)[0], 17, 'redistribute: column 2 takes the slack');
    ok(!(grep { $_ > 30 } widths($o)), 'redistribute: within width');
}

{
    # Double-width characters cannot fill an odd width; being one
    # column short is not slack, so both columns keep sharing.
    my $in = "|" . ("\x{3042}" x 20) . "|" . ("c" x 40) . "|\n";
    my $o = out($in, @T, q(-w), 30, q(-o), q(|));
    my @r = cols($o);
    is((sort { $b <=> $a } map { ansi_width($_->[1]) } @r)[0], 12, 'parity: one column short is not slack');
}

{
    # the mark is passed to the command as UTF-8 bytes
    my @M = (q(-o), q(|), q(--table-wrap-mark), encode_utf8("\x{b7}"));
    my @F = (q(--item-format= %s ));
    my $o = out($tbl, @T, q(-w), 34, @M, @F);
    like($o, qr/^\s+\|\x{b7}jumps over the lazy dog$/m, q(wrap-mark: replaces the leading pad of a continuation line));
    like($o, qr/^ k1  \| the quick brown fox$/m, 'wrap-mark: first line keeps its pad');
    like($o, qr/^ k2  \| short$/m, 'wrap-mark: unwrapped cell untouched');
    is($o =~ s/\x{b7}/ /gr, out($tbl, @T, q(-w), 34, q(-o), q(|), @F), 'wrap-mark: widths unchanged');
    like(out($tbl, @T, q(-w), 30, @M), qr/^\s+\|\x{b7}jumps over the lazy dog$/m, 'wrap-mark: prepended when there is no pad');
    my $sgr = out("|k|\e[1mthe quick brown fox jumps over the lazy dog\e[m|\n", @T, q(-w), 34, @M, @F);
    like($sgr, qr/^\s+\|\x{b7}\e\[1mover the lazy dog\e\[m$/m, q(wrap-mark: placed before the reopened SGR));
}

{
    # --table-cell-mark: the first line of every non-empty cell in a column
    # that has a wrapped cell; other columns are left alone
    my @F = (q(-o), q(|), q(--item-format= %s ));
    my @I = (q(--table-cell-mark=+));
    my $o = out($tbl, @T, q(-w), 34, @F, @I);
    like($o, qr/^ k1  \|\+the quick brown fox$/m, q(cell-mark: replaces the leading pad in the wrapped column));
    like($o, qr/^\s+\| jumps over the lazy dog$/m, q(cell-mark: continuation line keeps its pad));
    like($o, qr/^ k2  \|\+short$/m, q(cell-mark: unwrapped cell of a wrapped column is marked));
    unlike($o, qr/^\+/m, q(cell-mark: a column with no wrapped cell is not marked));
    like($o, qr/^ key \|\+description$/m, q(cell-mark: the first row is marked like any other without --table-head));
    is($o =~ s/\+/ /gr, out($tbl, @T, q(-w), 34, @F), q(cell-mark: widths unchanged));
    is(out($tbl, @T, @F, @I), out($tbl, @T, @F), q(cell-mark: a table with no wrapped cell is left alone));
    is(out($tbl, @T, q(-w), 80, @F, @I), out($tbl, @T, @F), q(cell-mark: nor when -w is wide enough));
    my $both = out($tbl, @T, q(-w), 34, @F, @I, q(--table-wrap-mark=-));
    like($both, qr/^\s+\|-jumps over the lazy dog$/m, q(cell-mark: continuation line gets the wrap mark));
    like($both, qr/^ k1  \|\+the quick brown fox$/m, q(cell-mark: first line gets the cell mark));
    like(out($tbl, @T, q(-w), 30, q(-o), q(|), @I), qr/^k1 \|\+the quick brown fox$/m, q(cell-mark: prepended when there is no pad));
    is(out("|a||\n|bbbbbbbbbb|c|\n", @T, q(-o), q(|), q(--cell), q(5,0), @I), "+a   |\n+bbb |c\nbbb  |\nbbb  |\nb    |\n", q(cell-mark: empty cells are not marked, nor the unwrapped column));
    my $two = out("|aaaaaaaaaa|bbbbbbbbbb|\n|c|d|\n", @T, @F, q(--cell), q(6,6), @I);
    like($two, qr/^\+a+\s*\|\+b+\s*$/m, q(cell-mark: every column that wrapped is marked));
    like($two, qr/^\+c\s+\|\+d\s*$/m, q(cell-mark: unwrapped cells of both wrapped columns are marked));
}

{
    # --table-head=N: the first N rows are a header and get no cell mark;
    # a row that wraps is still one row
    my @F = (q(-o), q(|), q(--item-format= %s ));
    my @I = (q(--table-cell-mark=+));
    my $o = out($tbl, @T, q(-w), 34, @F, @I, q(--table-head=1));
    like($o, qr/^ key \| description$/m, q(table-head: the header row is not marked));
    like($o, qr/^ k1  \|\+the quick brown fox$/m, q(table-head: body rows are marked));
    like($o, qr/^ k2  \|\+short$/m, q(table-head: all body rows are marked));
    my $sep = "|key|description|\n|-|-|\n|k1|the quick brown fox jumps over the lazy dog|\n";
    my $s = out($sep, @T, q(-w), 34, @F, @I, q(--table-head=2));
    like($s, qr/^ key \| description$/m, q(table-head=2: the header row is not marked));
    like($s, qr/^ -   \| -$/m, q(table-head=2: the separator row is not marked));
    like($s, qr/^ k1  \|\+the quick brown fox$/m, q(table-head=2: the body row is marked));
    my $long = "|key|a long header that wraps|\n|-|-|\n|k1|the quick brown fox jumps over the lazy dog|\n";
    my $w = out($long, @T, q(-w), 30, @F, @I, q(--table-head=2));
    unlike($w, qr/^\+| \+[^|]*$/m, q(table-head: no mark in the header rows even when the header wraps));
    like($w, qr/^ k1  \|\+the quick/m, q(table-head: a wrapped header still counts as one row));
    is(out($tbl, @T, q(-w), 34, @F, @I, q(--table-head=0)), out($tbl, @T, q(-w), 34, @F, @I), q(table-head=0: same as no --table-head));
    is(out($tbl, @T, @F, q(--table-head=1)), out($tbl, @T, @F), q(table-head: no effect without a mark));
}

{
    # marks stay at the left edge of the cell when the column is aligned
    my @F = (q(-o), q(|), q(--item-format= %s ));
    my $in = "|a|1|\n|bbb|22222|\n|c|the quick brown fox|\n";
    my @C = (q(--cell), q(0,<9), q(--table-cell-mark=+));
    is(out($in, @T, @F, @C, q(--table-right=2)),
       " a   |+        1\n bbb |+    22222\n c   |+      the\n     |     quick\n     |     brown\n     |       fox\n",
       q(cell-mark: left edge of a right-aligned cell));
    is(out($in, @T, @F, @C, q(--table-center=2)),
       " a   |+    1\n bbb |+  22222\n c   |+   the\n     |   quick\n     |   brown\n     |    fox\n",
       q(cell-mark: left edge of a centered cell));
    is(out("|k|the quick brown fox jumps over the lazy dog|\n|kk|short|\n",
	   @T, @F, q(-w), 26, q(--table-right=2), q(--table-wrap-mark=-)),
       " k  | the quick brown\n    |- fox jumps over\n    |-   the lazy dog\n kk |           short\n",
       q(wrap-mark: left edge of a right-aligned cell));
}

done_testing;

__DATA__

@@ wrap
key  description
k1   the quick brown fox
     jumps over the lazy dog
k2   short
@@ item-format
 key | description
 k1  | the quick brown fox
     | jumps over the lazy dog
 k2  | short
@@ right
key              description
k1       the quick brown fox
     jumps over the lazy dog
k2                     short
@@ cell-fixed
key                 |description
k1                  |the quick brown fox jumps over the lazy dog
k2                  |short
