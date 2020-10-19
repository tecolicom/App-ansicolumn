package App::ansicolumn;

use v5.14;
use warnings;

######################################################################
# Object interface
######################################################################

sub border {
    my $border = shift->{BORDER} or return "";
    $border->get(@_);
}

sub border_width {
    use List::Util qw(sum);
    my $obj = shift;
    sum map length($obj->border($_)), qw(left right);
}

use Text::ANSI::Fold qw(:constants);

my %lb_flag = (
    ''     => LINEBREAK_NONE,
    none   => LINEBREAK_NONE,
    runin  => LINEBREAK_RUNIN,
    runout => LINEBREAK_RUNOUT,
    all    => LINEBREAK_ALL,
    );

sub lb_flag {
    $lb_flag{shift->{linebreak}};
}

sub runin {
    my $obj = shift;
    return 0 if not $lb_flag{$obj->{linebreak}} & LINEBREAK_RUNIN;
    $obj->{runin};
}

sub margin_width {
    shift->runin;
}

sub term_size {
    @{ shift->{term_size} //= [ terminal_size() ] };
}

sub term_width {
    (shift->term_size)[0];
}

sub term_height {
    (shift->term_size)[1];
}

sub width {
    my $obj = shift;
    $obj->{output_width} || $obj->term_width;
}

sub foldobj {
    my $obj = shift;
    my $width = shift;
    use Text::ANSI::Fold;
    Text::ANSI::Fold->new(
	width     => $width,
	boundary  => $obj->{boundary},
	linebreak => $obj->lb_flag,
	runin     => $obj->{runin},
	runout    => $obj->{runout},
	);
}


######################################################################

sub roundup ($$;$) {
    use integer;
    my($a, $b, $c) = @_;
    ($a + $b + ($c // 0) - 1) / $b * $b;
}

sub terminal_size {
    use Term::ReadKey;
    my @default = (80, 24);
    my @size;
    if (open my $tty, ">", "/dev/tty") {
	# Term::ReadKey 2.31 on macOS 10.15 has a bug in argument handling
	# and the latest version 2.38 fails to install.
	# This code should work on both versions.
	@size = GetTerminalSize $tty, $tty;
    }
    @size ? @size : @default;
}

sub zip {
    my @zipped;
    my @orig = map { [ @$_ ] } @_;
    while (my @l = grep { @$_ > 0 } @orig) {
	push @zipped, [ map { shift @$_ } @l ];
    }
    @zipped;
}

sub insert_space {
    map { @$_ } reduce {
	[ @$a, (@$a && $a->[-1] ne '' && $b ne '' ? '' : ()), $b ]
    } [], @_;
}

sub remove_topspaces ($$) {
    my($lp, $length) = @_;
    my $page = 0;
    while (++$page * $length < @$lp) {
	my $topline = $page * $length;
	while ($lp->[$topline] eq '') {
	    splice @$lp, $topline, 1;
	}
    }
    @$lp;
}

1;
