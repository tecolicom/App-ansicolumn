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

# --table-group: the lines of a row of a table are joined by GROUP
# SEPARATOR (0x1D), so that --intact keeps them in one pane.  mdee
# joins the rows of a table by UNIT SEPARATOR (0x1F): --intact takes
# a line with both as lines kept intact, some of them groups.

my($US, $GS) = ("\x1F", "\x1D");

sub out {
    my($in, @opt) = @_;
    my $d = ac->new(@opt)->exec($in);
    utf8::is_utf8($d) ? $d : decode_utf8($d);
}

# a row of a table with more than one line is one line
{
    my $in = "h1|h2\nx\x{2028}y|z\nlong long long|r\n";
    my @lines = split /\n/, out($in, '-t', '-s', '|', '-o', ' ', '--table-group', '-w', '12');
    is(scalar @lines, 3, 'table-group: one line a row');
    like($lines[0], qr/^h1\s+h2$/, 'table-group: a row of one line');
    my @row = map { s/\s+$//r } split /$GS/, $lines[1];
    ok(@row == 2 && $row[0] =~ /^x\s+z$/ && $row[1] eq 'y',
       'table-group: the lines of a row with a line separator');
    is(scalar(split /$GS/, $lines[2]), 2, 'table-group: the lines of a wrapped row');
}

# without it, the lines are lines
{
    my $in = "h1|h2\nx\x{2028}y|z\n";
    my $o = out($in, '-t', '-s', '|', '-o', ' ');
    unlike($o, qr/$GS/, 'without table-group: no separator');
    is(scalar(split /\n/, $o), 3, 'without table-group: three lines');
}

# the lines of panes, 10 wide each, with no border
sub panes {
    my($out, $n) = (@_, 3);
    my @pane;
    for my $line (split /\n/, $out, -1) {
	for my $i (0 .. $n - 1) {
	    my $text = length $line > $i * 10 ? substr($line, $i * 10, 10) : '';
	    push @{$pane[$i]}, $text =~ s/ +$//r;
	}
    }
    pop @$_ for @pane;
    \@pane;
}

my @P = qw(-C3 -S10 --no-border --intact);

# --intact: lines joined by US, some of them groups joined by GS
{
    my $table = join $US, 't1', join($GS, qw(g1 g2 g3)), 't2';
    my $in = join "\n", 'a', $table, "b\n";
    my $o = out($in, @P, '--height=4');
    my $p = panes($o);
    is_deeply($p->[0], [ qw(a t1), '', '' ], 'US and GS: the group does not fit, the pane is left');
    is_deeply([ @{$p->[1]}[0..3] ], [ qw(g1 g2 g3 t2) ], 'US and GS: the group in the next pane');
    unlike($o, qr/[\x1D\x1E\x1F]/, 'US and GS: no mark in the output');
}

# the lines of a table may go over the bottom between the groups
{
    my $table = join $US, join($GS, qw(h s r1)), 'r2', 'r3', 'r4';
    my $in = join "\n", 'a', "$table\n";
    my $p = panes(out($in, @P, '--height=4'));
    is_deeply($p->[0], [ qw(a h s r1) ], 'US and GS: the first group fits');
    is_deeply([ @{$p->[1]}[0..1] ], [ qw(r2 r3) ], 'US and GS: the rest goes on');
}

done_testing;
