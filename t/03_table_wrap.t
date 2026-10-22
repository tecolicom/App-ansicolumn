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
    my $o = out(encode_utf8($row x 3), @T, '-w', 24);
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
