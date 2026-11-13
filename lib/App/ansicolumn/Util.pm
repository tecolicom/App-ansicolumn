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
    my($dp, @part) = @_;
    $obj->do_space_layout($dp, @part)
        ->do_fillup($dp);
    return $obj;
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
	# every part but the last ends at the bottom of a pane
	_fillup($dp, $height, $obj->fillup_str) if $i < $#part;
    }
    return $obj;
}

#
# Split text into parts at formfeeds.  A formfeed is the end of the
# part before it and the top of the next: what follows it, a newline
# as well, belongs to the next part.  No part is made after the last
# formfeed when nothing follows it.
#
# The colors just before a formfeed, and a reset just after it, are
# for the formfeed and go with it: bat gives a formfeed alone as
# "\e[38;2;...m\f\e[0m".  Colors are not carried over a formfeed, as
# they are not over a newline.
#
sub split_formfeed {
    my $text = shift;
    state $sgr = qr/\e\[[\d;:]*m/;
    # Remove the colors just before a formfeed and a reset just after
    # it.  Without this, what bat gives leaves a line of a color alone
    # at the end of the part ("\e[38;2;...m"), which is counted as a
    # line, and a line of a reset alone at the top of the next part
    # ("\e[0m"), which --no-white-space does not take as a blank line:
    # every page of "nup bat" would begin a line lower than it should.
    # A color just after a formfeed is for the text and is left.
    $text =~ s/(?:$sgr)*\f(?:\e\[0*m)*/\f/g;
    my @part = split /\f/, $text;
    @part ? @part : '';
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
