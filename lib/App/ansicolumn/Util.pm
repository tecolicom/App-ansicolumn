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
    my $dp = shift;
    $obj->do_space_layout($dp)
        ->do_fillup($dp);
    return $obj;
}

sub do_space_layout {
    my $obj = shift;
    my($dp) = @_;
    my $height = $obj->effective_height || die;
    return if $height <= 0;
    # A formfeed moves to the next pane.  Split the lines at formfeeds
    # and lay out each part by itself, so that moving lines within a
    # part never carries a formfeed into a pane already laid out.
    my @part = $obj->pagebreak ? split_formfeed(@$dp) : [ @$dp ];
    @$dp = ();
    for my $i (keys @part) {
	$obj->space_layout($part[$i], $height);
	push @$dp, @{$part[$i]};
	# every part but the last ends at the bottom of a pane
	_fillup($dp, $height, $obj->fillup_str) if $i < $#part;
    }
    return $obj;
}

#
# Split lines into parts at formfeeds.  Text before a formfeed ends
# the part and text after it begins the next part.  When the text
# before or after a formfeed is an empty string, it is not added as a
# line ("\f" alone adds no line).  Empty lines without a formfeed are
# kept.
#
sub split_formfeed {
    my @part = ([]);
    for my $line (@_) {
	if ($line !~ /\f/) {
	    push @{$part[-1]}, $line;
	    next;
	}
	my @piece = split /\f/, $line, -1;
	for my $j (keys @piece) {
	    push @part, [] if $j > 0;
	    push @{$part[-1]}, $piece[$j] if $piece[$j] ne '';
	}
    }
    @part;
}

sub space_layout {
    my $obj = shift;
    my($dp, $height) = @_;
    for (my $page = 0; (my $top = $page * $height) < @$dp; $page++) {
	if ($height >= 4 and $top > 2 and !$obj->isolation) {
	    if ($dp->[$top - 2] !~ /\S/ and
		$dp->[$top - 1] =~ /\S/
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
