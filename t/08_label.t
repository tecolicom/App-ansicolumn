use v5.14;
use warnings;
use utf8;
use Test::More 0.98;
use File::Spec;
use open IO => ':utf8', ':std';

use lib './t';
use ac;

# do not read the rc file of the user
$ENV{HOME} = File::Spec->rel2abs('t/home');

# Nine lines in panes of three lines, two panes in a row: panes 1 and 2
# are on the first page, and pane 3 is on the second.
#
#   +-- 1 --++-- 2 --+
#   +-- 3 --+
#
my $stdin = join '', map "$_\n", 1 .. 9;
sub pages {
    ac->new(qw(-P5 -C2 -w30 --border), @_)->exec($stdin);
}

# the border lines, top or bottom, of all the pages
sub borders {
    my($out, $corner) = @_;
    [ grep { /^\Q$corner\E/ } split /\n/, $out ];
}
sub top    { borders(shift, '┌') }
sub bottom { borders(shift, '└') }

subtest 'totals' => sub {
    is_deeply top(pages('--label', 'N= %n/%N ')),
	[ '┌──── 1/3 ────┐┌──── 2/3 ────┐',
	  '┌──── 3/3 ────┐' ],
	'%N is the number of all the panes';
    is_deeply bottom(pages('--page-label', 'SE= %p/%P ')),
	[ '└─────────────┘└──────── 1/2 ┘',
	  '└──────── 2/2 ┘' ],
	'%P is the number of all the pages';
};

subtest 'marks' => sub {
    is_deeply top(pages('--label', 'NW= %L ', '--label', 'NE= %R ')),
	[ '┌────────── > ┐┌─ < ─────────┐',
	  '┌─────────────┐' ],
	'%L and %R: a pane on the left and on the right in the row';
    is_deeply top(pages('--label', 'N= %U ')),
	[ '┌─────────────┐┌─────────────┐',
	  '┌───── ^ ─────┐' ],
	'%U: a page above';
    is_deeply bottom(pages('--label', 'S= %D ')),
	[ '└───── v ─────┘└───── v ─────┘',
	  '└─────────────┘' ],
	'%D: a page below';
};

subtest 'marks in a page label' => sub {
    my $out = pages('--page-label', 'SW= %U%D ');
    is_deeply bottom($out),
	[ '└ v ──────────┘└─────────────┘',
	  '└ ^ ──────────┘' ],
	'%U and %D by the page';
    $out = pages('--page-label', 'SW= %L%R ');
    is_deeply bottom($out),
	[ '└─────────────┘└─────────────┘',
	  '└─────────────┘' ],
	'%L and %R are empty in a page label';
};

subtest '--mark' => sub {
    is_deeply top(pages('--label', 'NW= %L ', '--label', 'NE= %R ',
			'--mark', 'LEFT=«', '--mark', 'RIGHT=»')),
	[ '┌────────── » ┐┌─ « ─────────┐',
	  '┌─────────────┐' ],
	'LEFT and RIGHT';
    is_deeply bottom(pages('--label', 'S= %D ', '--mark', 'down=more')),
	[ '└──── more ───┘└──── more ───┘',
	  '└─────────────┘' ],
	'the name is case-insensitive, and the mark can be a word';
    like pages('--mark', 'FOO=x'), qr/FOO: unknown mark/i, 'unknown name';
};

subtest 'with other text' => sub {
    is_deeply top(pages('--label', 'NE= %n%R ')),
	[ '┌───────── 1> ┐┌────────── 2 ┐',
	  '┌────────── 3 ┐' ],
	'a mark beside the number';
};

# The files side by side: three files, two panes in a row
subtest 'parallel' => sub {
    my $out = ac->new(qw(-V -C2 -w30 --border),
		      '--label', 'NW= %L ', '--label', 'NE= %R ', '--label', 'S= %n/%N ',
		      qw(t/08_label/a t/08_label/b t/08_label/c))->exec('');
    is_deeply top($out),
	[ '┌────────── > ┐┌─ < ─────────┐',
	  '┌─────────────┐' ],
	'%L and %R';
    is_deeply bottom($out),
	[ '└──── 1/3 ────┘└──── 2/3 ────┘',
	  '└──── 3/3 ────┘' ],
	'%N is the number of the files';
};

# One pane: no mark at all
subtest 'one pane' => sub {
    my $out = ac->new(qw(-P5 -C2 -w30 --border),
		      '--label', 'NW= %L ', '--label', 'NE= %R ',
		      '--label', 'SW= %U ', '--label', 'SE= %D ')->exec("1\n2\n");
    is_deeply top($out),    [ '┌─────────────┐' ], 'top';
    is_deeply bottom($out), [ '└─────────────┘' ], 'bottom';
};

done_testing;
