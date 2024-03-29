package App::ansicolumn;

use v5.14;
use warnings;
use utf8;

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
    my $dp = shift;
    $obj->do_pagebreak($dp)
        ->do_space_layout($dp)
        ->do_fillup($dp);
    return $obj;
}

sub do_space_layout {
    my $obj = shift;
    my($dp) = @_;
    my $height = $obj->effective_height || die;
    return if $height <= 0;
    for (my $page = 0; (my $top = $page * $height) < @$dp; $page++) {
	if ($height >= 4 and $top > 2 and !$obj->isolation) {
	    if ($dp->[$top - 2] !~ /\S/ and
		$dp->[$top - 1] =~ /\S/ and
		$dp->[$top    ] =~ /\S/
		) {
		splice @$dp, $top - 1, 0, '';
		next;
	    }
	}
	if (not $obj->white_space) {
	    while ($top < @$dp and $dp->[$top] !~ /\S/) {
		splice @$dp, $top, 1;
	    }
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

sub do_pagebreak {
    my $obj = shift;
    $obj->pagebreak or return;
    my $dp = shift;
    my $height = $obj->effective_height || die;
    my @up;
    use List::Util qw(first);
    while (defined(my $i = first { $dp->[$_] =~ /\f/ } keys @$dp)) {
	push @up, splice @$dp, 0, $i;
	$dp->[0] =~ s/^([^\f]*)\f// or die;
	push @up, $1, if $1 ne '';
	_fillup \@up, $height, $obj->fillup_str;
    }
    unshift @$dp, @up if @up;
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
