use v5.14;
use warnings;
use Test::More 0.98;

use lib './t';
use ac;
use Data::Section::Simple qw(get_data_section);

is(ac->new()->exec(''), '', 'empty');
is(ac->new(qw(-t))->exec(''), '', 'empty: -t');

my $stdin = join '', map "$_\n", 1..100;

for (
    [ normal => [qw(-c80)] ],
    [ xpose  => [qw(-c80 -x)] ],
) {
    my($name, $opt) = @$_;
    is(ac->new(@$opt)->exec($stdin), get_data_section($name), $name);
}

$stdin = get_data_section('xpose') =~ s/ +/ /gr;

for (
    [ table  => [qw(-t)] ],
    [ right  => [qw(-t -R::3)] ],
    [ single => ['-t', '-o', ' '] ],
    [ align  => [qw(-A)] ],
    [ tab    => [qw(-T)] ],
) {
    my($name, $opt) = @$_;
    is(ac->new(@$opt)->exec($stdin), get_data_section($name), $name);
}

$stdin = "a b cc\ndddd ee ffffff\ng hh iii\n";

for (
    [ center         => [qw(-t --table-center=1)] ],
    [ 'item-format'  => [qw(-t), '--item-format= %s '] ],
) {
    my($name, $opt) = @$_;
    is(ac->new(@$opt)->exec($stdin), get_data_section($name), $name);
}

$stdin = "|a|b|cc|\n|dddd|ee|ffffff|\n|g|hh|iii|\n";

for (
    [ 'squeeze' => [qw(-t -s | --table-squeeze)] ],
    [ 'discard' => [qw(-t -s |), '--table-remove=1,-0'] ],
) {
    my($name, $opt) = @$_;
    is(ac->new(@$opt)->exec($stdin), get_data_section($name), $name);
}

{
    my $input = "a b cc\ndddd ee ffffff\ng hh iii\n";
    my $out = ac->new(qw(-t --padding))->setstdin($input)->update->data;
    my @lens = map { length } split /\n/, $out;
    is(scalar(grep { $_ == $lens[0] } @lens), scalar @lens,
       'padding: all lines have equal length');
}

my @isolation_opt = qw(-P6 -c40 --border=none);

# single-line paragraph (title only)
$stdin = join '', map "$_\n", qw(line1 line2 line3 line4), '', qw(TITLE), '', qw(line5 line6);

for (
    [ 'no-isolation-single' => [@isolation_opt, '--no-isolation'] ],
    [ 'isolation-single'    => [@isolation_opt, '--isolation'] ],
) {
    my($name, $opt) = @$_;
    is(ac->new(@$opt)->exec($stdin), get_data_section($name), $name);
}

# multi-line paragraph
$stdin = join '', map "$_\n", qw(line1 line2 line3 line4), '', qw(TITLE content line5);

for (
    [ 'no-isolation-multi' => [@isolation_opt, '--no-isolation'] ],
    [ 'isolation-multi'    => [@isolation_opt, '--isolation'] ],
) {
    my($name, $opt) = @$_;
    is(ac->new(@$opt)->exec($stdin), get_data_section($name), $name);
}

# no blank line before page boundary (isolation should not trigger)
$stdin = join '', map "$_\n", qw(line1 line2 line3 line4 line5 line6 line7 line8);

{
    my $expected = get_data_section('no-isolation-noblank');
    is(ac->new(@isolation_opt, '--no-isolation')->exec($stdin), $expected, 'no-isolation-noblank');
    is(ac->new(@isolation_opt, '--isolation')->exec($stdin),    $expected, 'isolation-noblank');
}

my @formfeed_opt = qw(-P6 -C1 -c40 --border=none -D --fillup=pane --fillup-str=~);

for (
    [ 'ff-basic'   => "a\nb\nc\n\fd\ne\nf\n" ],
    [ 'ff-midline' => "a\nb\nabc\fdef\n" ],
    [ 'ff-tab'     => "a\nb\nabc\fde\tf\n" ],
) {
    my($name, $input) = @$_;
    is(ac->new(@formfeed_opt)->exec($input), get_data_section($name), $name);
}

done_testing;

__DATA__

@@ normal
1       11      21      31      41      51      61      71      81      91
2       12      22      32      42      52      62      72      82      92
3       13      23      33      43      53      63      73      83      93
4       14      24      34      44      54      64      74      84      94
5       15      25      35      45      55      65      75      85      95
6       16      26      36      46      56      66      76      86      96
7       17      27      37      47      57      67      77      87      97
8       18      28      38      48      58      68      78      88      98
9       19      29      39      49      59      69      79      89      99
10      20      30      40      50      60      70      80      90      100
@@ xpose
1       2       3       4       5       6       7       8       9       10
11      12      13      14      15      16      17      18      19      20
21      22      23      24      25      26      27      28      29      30
31      32      33      34      35      36      37      38      39      40
41      42      43      44      45      46      47      48      49      50
51      52      53      54      55      56      57      58      59      60
61      62      63      64      65      66      67      68      69      70
71      72      73      74      75      76      77      78      79      80
81      82      83      84      85      86      87      88      89      90
91      92      93      94      95      96      97      98      99      100
@@ table
1   2   3   4   5   6   7   8   9   10
11  12  13  14  15  16  17  18  19  20
21  22  23  24  25  26  27  28  29  30
31  32  33  34  35  36  37  38  39  40
41  42  43  44  45  46  47  48  49  50
51  52  53  54  55  56  57  58  59  60
61  62  63  64  65  66  67  68  69  70
71  72  73  74  75  76  77  78  79  80
81  82  83  84  85  86  87  88  89  90
91  92  93  94  95  96  97  98  99  100
@@ right
 1  2   3    4  5   6    7  8   9    10
11  12  13  14  15  16  17  18  19   20
21  22  23  24  25  26  27  28  29   30
31  32  33  34  35  36  37  38  39   40
41  42  43  44  45  46  47  48  49   50
51  52  53  54  55  56  57  58  59   60
61  62  63  64  65  66  67  68  69   70
71  72  73  74  75  76  77  78  79   80
81  82  83  84  85  86  87  88  89   90
91  92  93  94  95  96  97  98  99  100
@@ center
 a    b   cc
dddd  ee  ffffff
 g    hh  iii
@@ item-format
 a       b     cc
 dddd    ee    ffffff
 g       hh    iii
@@ squeeze
a     b   cc
dddd  ee  ffffff
g     hh  iii
@@ discard
a     b   cc
dddd  ee  ffffff
g     hh  iii
@@ single
1  2  3  4  5  6  7  8  9  10
11 12 13 14 15 16 17 18 19 20
21 22 23 24 25 26 27 28 29 30
31 32 33 34 35 36 37 38 39 40
41 42 43 44 45 46 47 48 49 50
51 52 53 54 55 56 57 58 59 60
61 62 63 64 65 66 67 68 69 70
71 72 73 74 75 76 77 78 79 80
81 82 83 84 85 86 87 88 89 90
91 92 93 94 95 96 97 98 99 100
@@ align
1       2       3       4       5       6       7       8       9       10
11      12      13      14      15      16      17      18      19      20
21      22      23      24      25      26      27      28      29      30
31      32      33      34      35      36      37      38      39      40
41      42      43      44      45      46      47      48      49      50
51      52      53      54      55      56      57      58      59      60
61      62      63      64      65      66      67      68      69      70
71      72      73      74      75      76      77      78      79      80
81      82      83      84      85      86      87      88      89      90
91      92      93      94      95      96      97      98      99      100
@@ tab
1	2	3	4	5	6	7	8	9	10
11	12	13	14	15	16	17	18	19	20
21	22	23	24	25	26	27	28	29	30
31	32	33	34	35	36	37	38	39	40
41	42	43	44	45	46	47	48	49	50
51	52	53	54	55	56	57	58	59	60
61	62	63	64	65	66	67	68	69	70
71	72	73	74	75	76	77	78	79	80
81	82	83	84	85	86	87	88	89	90
91	92	93	94	95	96	97	98	99	100
@@ no-isolation-single
line1   TITLE
line2
line3   line5
line4   line6


@@ isolation-single
line1
line2   line5
line3   line6
line4

TITLE
@@ no-isolation-multi
line1   TITLE
line2   content
line3   line5
line4


@@ isolation-multi
line1   content
line2   line5
line3
line4

TITLE
@@ no-isolation-noblank
line1   line7
line2   line8
line3
line4
line5
line6
@@ ff-basic
a
b
c
~
~
~
d
e
f
~
~
~
@@ ff-midline
a
b
abc
~
~
~
def
~
~
~
~
~
@@ ff-tab
a
b
abc
~
~
~
de      f
~
~
~
~
~
