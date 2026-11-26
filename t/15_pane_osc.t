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

# --pane-osc: a private OSC, which terminals ignore, at the start of
# each pane, so that a program which reads the output, as ansi2pdf,
# knows where the panes are

my $OSC = "\e]7772;\e\\";

sub out {
    my($in, @opt) = @_;
    my $d = ac->new(@opt)->exec($in);
    utf8::is_utf8($d) ? $d : decode_utf8($d);
}

my $in = join '', map "$_\n", qw(a b c d e f);

{
    my @lines = split /\n/, out($in, qw(-C2 -S10 --height=4 --border=box --pane-osc));
    my @with = grep { $lines[$_] =~ /\Q$OSC/ } keys @lines;
    is_deeply(\@with, [ 1, 5 ], 'pane-osc: on the first row of the panes of each page');
    my $n = () = $lines[1] =~ /\Q$OSC/g;
    is($n, 2, 'pane-osc: one for each pane');
    like($lines[1], qr/^\S \Q$OSC\Ea +\S+ \Q$OSC\Ec/, 'pane-osc: at the start of the text of the pane, inside the border');
}

{
    unlike(out($in, qw(-C2 -S10 --height=4 --border=box)), qr/\e\]/, 'without pane-osc: none');
}

done_testing;
