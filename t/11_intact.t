use v5.14;
use warnings;
use utf8;
use Test::More 0.98;

use lib './t';
use ac;
use Encode qw(decode_utf8);
use Text::ANSI::Fold::Util qw(ansi_width);

# do not read the rc file of the user
use File::Spec;
$ENV{HOME} = File::Spec->rel2abs('t/home');

# --intact: lines joined into one line by UNIT SEPARATOR (0x1F) are
# kept as they are: a line which fits the pane is not folded, run-in
# room included, and a wider one is cut at the pane width, with no word
# boundary and no line-break (kinsoku) rule; other lines are folded as
# before.

my $US = "\x1F";

sub out {
    my($in, @opt) = @_;
    my $d = ac->new(@opt)->exec($in);
    utf8::is_utf8($d) ? $d : decode_utf8($d);
}

# the pane is 24 wide and keeps 4 for run-in: lines are folded at 20
my @P = (qw(-C1 -S 25 --linestyle=wrap --runin=4 --lb=all));

my $prose = "abcdefghijklmnopqrstuvw";		# 23 wide
my $row   = "| a | bbbbbbbbbbbbbbb |";		# 23 wide
my $long  = "| e | ffffffffffffffffffffffff |";	# 32 wide
my $in = "$prose\n$row$US$row$US$long\nend\n";

my $o = out($in, @P, q(--intact));
my @l = split /\n/, $o;

unlike($o, qr/$US/, 'no UNIT SEPARATOR in the output');
ok(length $l[0] < length $prose, 'a line of text as wide as it is folded');
is($l[0] . $l[1], $prose, 'the rest of the line of text');
is($l[2], $row, 'a line which fits the pane is not folded');
is($l[3], $row, 'every line joined is a line');
like($l[4], qr/^\| e \| f+$/, 'a line wider than the pane is folded');
is($l[-1], 'end', 'the line after the joined lines');

my $plain = out($in, @P);
like($plain, qr/$US/, 'without --intact, the separator is left in the text');
isnt($plain, $o, 'without --intact, the joined lines are one line');

# with no folding, the marks of the joined lines are taken out
is(out("x${US}y\nz\n", qw(-C1 -S 10 --intact)), "x\ny\nz\n",
   'no folding: the joined lines are lines, and no mark is left');

# the width of the panes is that of the widest line, not of the joined line
my $w = out("$row$US$row\n", qw(-C1 --intact));
is((sort { $b <=> $a } map { ansi_width($_) } split /\n/, $w)[0], ansi_width($row),
   'the pane is as wide as the widest of the joined lines');

# in the table mode the separator is data, as without --intact
is(out("a${US}b\nc${US}d\n", q(-t), q(-s), $US, q(--intact)),
   out("a${US}b\nc${US}d\n", q(-t), q(-s), $US),
   'the table mode is not changed by --intact');

# a line wider than the pane is cut at the pane width, as a terminal
# does: no word boundary, no line-break (kinsoku) rule
{
    my @W = (qw(-C1 -S 20 --runin=2 --lb=all --boundary=word --intact));
    my $line = "| x | aaaa bbbb cccc\x{3001}dddd |";
    my $text = "aaaa bbbb cccc dddd\x{3001}eeee";
    my @l = split /\n/, out("a$US$line\n$text\n", @W, q(--linestyle=wrap));
    is($l[1], "| x | aaaa bbbb cccc", 'cut at the pane width, not at a word boundary');
    is($l[2], "\x{3001}dddd |", 'a closing mark may start the next line');
    like($l[3], qr/^aaaa bbbb cccc$/, 'a line of text is folded at a word boundary as before');
    my @t = split /\n/, out("a$US$line\n", @W, q(--linestyle=truncate));
    is($t[1], "| x | aaaa bbbb cccc", 'truncate: cut at the pane width');
    is(scalar @t, 2, 'truncate: the rest is dropped');
}

done_testing;
