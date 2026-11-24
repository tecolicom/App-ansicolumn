use v5.14;
use warnings;
use utf8;
use Test::More 0.98;

use lib './t';
use ac;
use Encode qw(decode_utf8);
use File::Temp qw(tempdir);

# do not read the rc file of the user
use File::Spec;
$ENV{HOME} = File::Spec->rel2abs('t/home');

# --intact: lines joined by GROUP SEPARATOR (0x1D) are a group, kept
# as --intact keeps the lines joined by UNIT SEPARATOR, and kept in
# one pane: a group which would go over the bottom of a pane goes to
# the top of the next, unless it is higher than a pane.  The rows of
# an image in mdee are such a group.

my $GS = "\x1D";

sub out {
    my($in, @opt) = @_;
    my $d = ac->new(@opt)->exec($in);
    utf8::is_utf8($d) ? $d : decode_utf8($d);
}

# the lines of the panes, 10 wide each, with no border (the trailing
# spaces of the output are taken out by ac)
sub panes {
    my($out, $n) = (@_, 3);
    my @pane;
    for my $line (split /\n/, $out, -1) {
	for my $i (0 .. $n - 1) {
	    push @{$pane[$i]}, (substr($line, $i * 10, 10) // "") =~ s/ +$//r;
	}
    }
    pop @$_ for @pane;		# after the last newline
    \@pane;
}

sub group { join $GS, @_ }

my @P = qw(-C3 -S10 --no-border --intact);

# a group which goes over the bottom goes to the next pane
{
    my $in = join "\n", qw(a b c), group(qw(g1 g2 g3)), "d\n";
    my $o = out($in, @P, '--height=5');
    my $p = panes($o);
    is_deeply($p->[0], [ qw(a b c), '', '' ], 'group over the bottom: the pane is left');
    is_deeply([ @{$p->[1]}[0..3] ], [ qw(g1 g2 g3 d) ], 'group over the bottom: in the next pane');
    unlike($o, qr/[\x1D\x1E]/, 'group over the bottom: no mark in the output');
}

# a group which fits stays where it is
{
    my $in = join "\n", 'a', group(qw(g1 g2)), "b\n";
    my $p = panes(out($in, @P, '--height=5'));
    is_deeply([ @{$p->[0]}[0..3] ], [ qw(a g1 g2 b) ], 'group which fits: not moved');
}

# a group higher than a pane is laid out as lines
{
    my $in = join "\n", 'a', group(qw(g1 g2 g3 g4)), "b\n";
    my $p = panes(out($in, @P, '--height=3'));
    is_deeply($p->[0], [ qw(a g1 g2) ], 'group higher than a pane: not moved');
    is_deeply([ @{$p->[1]}[0..2] ], [ qw(g3 g4 b) ], 'group higher than a pane: goes on');
}

# a group after a line which the layout moved to the next pane: with
# --no-isolation, the heading before a blank line goes to the top of the
# next pane, and the group is then over the bottom of that pane
{
    my $in = join "\n", qw(p1 p2 p3), '', qw(h q1 q2), group(qw(g1 g2 g3)), "d\n";
    my $p = panes(out($in, @P, '--height=5', '--no-isolation'));
    is($p->[1][0], 'h', 'after a moved line: the heading is at the top');
    is_deeply([ @{$p->[2]}[0..3] ], [ qw(g1 g2 g3 d) ], 'after a moved line: the group in the next pane');
}

# truncated lines are kept in a group
{
    my $in = join "\n", qw(a b c), group('g1' . 'x' x 20, 'g2', 'g3'), "d\n";
    my $o = out($in, @P, '--height=5', '--linestyle=truncate');
    my $p = panes($o);
    is_deeply([ @{$p->[1]}[1..3] ], [ qw(g2 g3 d) ], 'truncate: the group in the next pane');
    unlike($o, qr/[\x1D\x1E]/, 'truncate: no mark in the output');
}

# a folded line of a group is a line of it
{
    my $in = join "\n", qw(a b c), group('g1' . 'x' x 12, 'g2'), "d\n";
    my $o = out($in, @P, '--height=5', '--linestyle=wrap');
    my $p = panes($o);
    is_deeply([ map { substr $_, 0, 2 } @{$p->[1]}[0..1] ], [ 'g1', 'xx' ],
	      'wrap: the folded line goes with its group');
    unlike($o, qr/[\x1D\x1E]/, 'wrap: no mark in the output');
}

# without --intact, the separator is left in the text
{
    my $in = join "\n", 'a', group(qw(g1 g2)), "b\n";
    like(out($in, qw(-C1 -S10 --no-border)), qr/g1${GS}g2/, 'without --intact: the separator is left');
}

# files side by side are not laid out in panes: no mark is left
{
    my $dir = tempdir(CLEANUP => 1);
    my @f = map { my $f = "$dir/$_"; open my $fh, '>', $f or die; print $fh $_[0] // ''; $f } qw(x y);
    open my $fh, '>', $f[0] or die; print $fh join("\n", 'a', group(qw(g1 g2)), "b\n"); close $fh;
    open    $fh, '>', $f[1] or die; print $fh "c\n"; close $fh;
    my $o = out(undef, qw(-V -S10 --no-border --intact), @f);
    unlike($o, qr/[\x1D\x1E]/, 'side by side: no mark in the output');
    like($o, qr/^g1\s*$/m, 'side by side: the group is lines');
}

done_testing;
