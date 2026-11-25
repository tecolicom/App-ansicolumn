package App::ansicolumn;

use v5.14;
use warnings;
use utf8;

# defined in App::ansicolumn
our($GROUP_SEP, $GROUP_FIRST, $GROUP_MARK);

######################################################################
# Object interface
######################################################################

sub get_border {
    my $border = shift->{BORDER} or return "";
    $border->get(@_);
}

sub border_width {
    use List::Util qw(sum);
    my $obj = shift;
    sum map length($obj->get_border($_)), @_;
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
    $lb_flag{shift->linebreak};
}

sub runin_margin {
    my $obj = shift;
    if ($lb_flag{$obj->linebreak} & LINEBREAK_RUNIN) {
	$obj->runin;
    } else {
	0;
    }
}

sub term_size {
    @{ shift->{TERM_SIZE} //= [ terminal_size() ] };
}

sub term_width {
    (shift->term_size)[0];
}

sub term_height {
    (shift->term_size)[1];
}

sub get_width {
    my $obj = shift;
    $obj->width || $obj->term_width;
}

sub effective_height {
    my $obj = shift;
    $obj->height - $obj->border_height;
}

sub foldobj {
    my $obj = shift;
    my $width = shift;
    use Text::ANSI::Fold;
    my $fold = Text::ANSI::Fold->new(
	width     => $width,
	margin    => $obj->runin_margin,
	boundary  => $obj->boundary,
	linebreak => $obj->lb_flag,
	runin     => $obj->runin,
	runout    => $obj->runout,
	ambiguous => $obj->ambiguous,
	padchar   => $obj->padchar,
	padding   => 1,
	);
    if ($obj->discard_el) {
	$fold->configure(discard => [ 'EL' ] );
    }
    $fold;
}

sub foldsub {
    my $obj = shift;
    my $width = shift;
    my $fold = $obj->foldobj($width);
    if ((my $ls = $obj->linestyle) eq 'truncate') {
	sub { ($fold->fold($_[0]))[0] };
    } elsif ($ls eq 'wrap') {
	sub {  $fold->text($_[0])->chops };
    } else {
	undef;
    }
}

sub set_layout {
    my $obj = shift;
    my($dp, @part) = @_;
    $obj->do_space_layout($dp, @part)
        ->do_fillup($dp);
    strip_group_marks($dp) if $obj->intact;
    return $obj;
}

# The marks of the lines of a group (see prepare) are taken out after
# the layout, with --intact, where they are made.
sub strip_group_marks {
    my $dp = shift;
    s/^$GROUP_MARK// for @$dp;
}

sub do_space_layout {
    my $obj = shift;
    my($dp, @part) = @_;
    my $height = $obj->effective_height || die;
    return if $height <= 0;
    # The parts are what formfeeds divide, and each begins a pane.
    # Lay out each part by itself, so that moving lines within a part
    # never carries the break into a pane already laid out.
    @$dp = ();
    for my $i (keys @part) {
	$obj->space_layout($part[$i], $height);
	push @$dp, @{$part[$i]};
	# every part but the last ends at the bottom of a pane, and
	# takes one even without a line: an empty page
	if ($i < $#part) {
	    push @$dp, $obj->fillup_str if @{$part[$i]} == 0;
	    _fillup($dp, $height, $obj->fillup_str);
	}
    }
    return $obj;
}

sub space_layout {
    my $obj = shift;
    my($dp, $height) = @_;
    for (my $page = 0; (my $top = $page * $height) < @$dp; $page++) {
	my $moved;
	if ($height >= 4 and $top > 2 and !$obj->isolation) {
	    if ($dp->[$top - 2] !~ /\S/ and
		$dp->[$top - 1] =~ /\S/
		) {
		splice @$dp, $top - 1, 0, '';
		$moved = 1;
	    }
	}
	if (not $moved and not $obj->white_space) {
	    while ($top < @$dp and $dp->[$top] !~ /\S/) {
		splice @$dp, $top, 1;
	    }
	}
	# A group which goes over the bottom of this pane, and is not
	# higher than a pane, goes to the top of the next: empty lines
	# are put before it.
	my $bottom = $top + $height;
	for (my $i = $top + 1; $i < $bottom and $i < @$dp; $i++) {
	    $dp->[$i] =~ /^$GROUP_FIRST/ or next;
	    my $end = $i;
	    $end++ while $end < $#$dp and $dp->[$end + 1] =~ /^$GROUP_SEP/;
	    if ($end >= $bottom) {
		splice @$dp, $i, 0, ('') x ($bottom - $i) if $end - $i < $height;
		last;
	    }
	    $i = $end;
	}
    }
    return $obj;
}

sub _fillup {
    my($dp, $len, $str) = @_;
    if (my $remmant = @$dp % $len) {
	push @$dp, ($str) x ($len - $remmant);
    }
}

sub do_fillup {
    my $obj = shift;
    my $dp = shift;
    my $line = $obj->effective_height || die;
    defined $obj->fillup and $obj->fillup !~ /^(?:no|none)$/
	or return;
    $obj->{fillup} ||= 'pane';
    $line *= $obj->panes if $obj->fillup eq 'page';
    _fillup $dp, $line, $obj->fillup_str;
    return $obj;
}

######################################################################

sub newlist {
    my %arg = (count => 0);
    while (@_ and not ref $_[0]) {
	my($name, $value) = splice(@_, 0, 2);
	$arg{$name} = $value;
    }
    my @list = ($arg{default}) x $arg{count};
    while (my($index, $value) = splice(@_, 0, 2)) {
	$index = [ $index ] if not ref $index;
	@list[@$index] = ($value) x @$index;
    }
    @list;
}

sub div {
    use integer;
    my($a, $b) = @_;
    ($a + $b - 1) / $b;
}

sub roundup ($$;$) {
    use integer;
    my($a, $b, $c) = @_;
    return $a if $b == 0;
    div($a + ($c // 0), $b) * $b;
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

sub xpose {
    use List::Util 1.56 qw(zip);
    map { [ grep { defined } @$_ ] } zip @_;
}

sub insert_space {
    use List::Util qw(reduce);
    map { @$_ } reduce {
	[ @$a, (@$a && $a->[-1] ne '' && $b ne '' ? '' : ()), $b ]
    } [], @_;
}

sub decode_argv {
    map {
	utf8::is_utf8($_) ? $_ : decode('utf8', $_);
    }
    @_;
}

1;
