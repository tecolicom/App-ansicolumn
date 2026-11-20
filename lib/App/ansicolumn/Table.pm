package App::ansicolumn;

use v5.14;
use warnings;
use utf8;

use List::Util qw(max min sum);

######################################################################
# Table mode: width allocation and cell wrapping
######################################################################

#
# table_widths(\@content, $budget, $overhead, \@fixed, $floor)
#
# Decide how wide the content of each table column may be.
#
#   @content  width of the widest cell in each column, as given
#   $budget   width available to all columns together: the -w width
#             minus the separators; undef when no width is requested
#   $overhead extra width every column costs for --item-format
#   @fixed    width already decided for a column (by --cell, or by a
#             previous round of fit_table_rows); undef for free
#             columns (the whole argument may be undef)
#   $floor    minimum width given to a free column
#
# Fixed columns get their fixed width.  Free columns whose widest cell
# fits get that width.  If that does not fit the budget, the free
# columns share it by the water level rule: find the largest L (not
# below $floor) such that every free column with min(content, L)
# fits the budget; columns narrower than L keep their width, the
# others are cut to L and will be wrapped.  Dividing by L leaves a
# remainder smaller than the number of cut columns; it goes to the
# cut columns one column of width each, widest content first.
#
sub table_widths {
    my($content, $budget, $overhead, $fixed, $floor) = @_;
    my @target = @$content;
    my @free;
    for my $i (keys @target) {
	if ($fixed and defined $fixed->[$i]) {
	    $target[$i] = $fixed->[$i];
	} else {
	    push @free, $i;
	}
    }
    return \@target unless defined $budget and @free;
    my $remain = $budget;
    $remain -= $target[$_] + $overhead
	for grep { $fixed and defined $fixed->[$_] } keys @target;
    my $cost = sub {
	my $level = shift;
	sum map { min($content->[$_], $level) + $overhead } @free;
    };
    return \@target if $cost->(max @$content) <= $remain;
    my $level = $floor;
    for (my $l = max(@{$content}[@free]); $l > $floor; $l--) {
	if ($cost->($l) <= $remain) {
	    $level = $l;
	    last;
	}
    }
    $target[$_] = min($content->[$_], $level) for @free;
    my $left = $remain - $cost->($level);
    if ($left > 0) {
	my @wrapped = sort { $content->[$b] <=> $content->[$a] or $a <=> $b }
	    grep { $content->[$_] > $level } @free;
	$target[$_]++ for @wrapped[0 .. min($left, scalar @wrapped) - 1];
    }
    \@target;
}

#
# parse_cell_spec($spec, \@content)
#
# Resolve --cell specification for table mode.  Entries are separated
# by comma and the last entry is repeated for remaining columns.
#
#   N      fixed width N
#   <N     upper bound: min(content, N)   (also <=N, =N, bare = or <)
#   +N -N  relative to the natural content width (minimum 1)
#   0      automatic (no constraint)
#
# Returns array reference with a width or undef for each column.
#
sub parse_cell_spec {
    my($spec, $content) = @_;
    my @entry = split /,+/, $spec;
    my @fixed;
    for my $i (keys @$content) {
	my $e = $entry[$i] // $entry[-1];
	my $w;
	if ($e eq q(0)) {
	    $w = undef;
	}
	elsif ($e =~ /^\d+$/) {
	    $w = $e;
	}
	elsif ($e =~ /^[-+]\d+$/) {
	    $w = max(1, $content->[$i] + $e);
	}
	elsif ($e =~ /^(?:<=|[<=])(\d*)$/) {
	    $w = $1 ? min($content->[$i], $1) : $content->[$i];
	}
	else {
	    die "Invalid number: $spec\n";
	}
	push @fixed, $w;
    }
    \@fixed;
}

use Text::ANSI::Fold qw(:constants);
use Text::ANSI::Fold::Util qw(ansi_width);

#
# table_fold($width)
#
# Text::ANSI::Fold object used to wrap table cells.  Word boundary
# and full line-break (kinsoku) processing are on unless the user
# chose otherwise.  Run-in characters need room, so the run-in width
# is reserved as margin (clamped below the width; Text::ANSI::Fold
# refuses margin >= width).  table_margin($width) gives that margin;
# cells are folded at $width - margin.
#
sub table_lb {
    my $obj = shift;
    $obj->linebreak ? $obj->lb_flag : LINEBREAK_ALL;
}

sub table_margin {
    my($obj, $width) = @_;
    ($obj->table_lb & LINEBREAK_RUNIN) ? max(0, min($obj->runin, $width - 1)) : 0;
}

sub table_fold {
    my($obj, $width) = @_;
    my $lb = $obj->table_lb;
    my $margin = $obj->table_margin($width);
    my $fold = Text::ANSI::Fold->new(
	width     => $width,
	margin    => $margin,
	boundary  => ($obj->boundary || 'word'),
	linebreak => $lb,
	runin     => $obj->runin,
	runout    => $obj->runout,
	ambiguous => $obj->ambiguous,
	padchar   => $obj->padchar,
	padding   => 0,
	);
    $fold->configure(discard => [ 'EL' ]) if $obj->discard_el;
    $fold;
}

#
# cell_lines($cell)
#
# The lines of a table cell: a LINE SEPARATOR (U+2028) in a cell
# breaks it into lines.  An empty cell has one empty line.  The cell
# is divided by Text::ANSI::Fold, with no width, which ends a line at
# the separator: colors and links that go on over it are closed at
# the end of the line and opened again on the next.
#
sub cell_lines {
    my $cell = shift;
    return ($cell) if not defined $cell or $cell !~ /\x{2028}/;
    state $fold = Text::ANSI::Fold->new(width => -1);
    my @lines = map { s/\x{2028}\z//r } $fold->text($cell)->chops;
    # a separator at the end leaves an empty last line
    push @lines, '' if $cell =~ /\x{2028}(?:\e\[[\d;]*m|\e\]8;;[^\e]*\e\\)*\z/;
    @lines;
}

#
# cell_width($cell)
#
# The width of a table cell: the width of its widest line.
#
sub cell_width {
    max map { ansi_width($_ // '') } cell_lines(shift);
}

#
# expand_table_rows(\@rows, \@rw, \@target, \@content, \@continued, \@ow)
#
# Wrap cells wider than their target width and expand each logical
# row into as many physical rows as its tallest cell.  A cell which
# has LINE SEPARATORs is broken into its lines first, and each line
# is wrapped on its own.  Missing cell lines are filled with empty
# strings.  Ragged rows stay ragged.
# \@rw holds the width of every cell of \@rows (of its widest line),
# and \@ow is set to the width of every cell of the rows returned, so
# that no cell is measured twice.
# When \@continued is given, $continued[row][col] is set for every
# cell that is the second or later line of a cell: 1 for a line of
# a wrapped cell, 2 for a line which starts after a LINE SEPARATOR.
# With an empty \@target, cells are only broken at LINE SEPARATORs.
#
# In a column that has a cell wider than the target (its widest cell,
# $content[col], is wider), every cell wider than the target minus the
# run-in margin is wrapped, as lines are in panes, so that a cell
# fitting in the margin is not left longer than the wrapped lines.
#
sub expand_table_rows {
    my($obj, $rows, $rw, $target, $content, $continued, $ow) = @_;
    @$continued = () if $continued;
    @$ow = ();
    my @limit = map {
	my($i, $w) = ($_, $target->[$_]);
	!defined $w ? undef :
	$content->[$i] > $w ? $w - $obj->table_margin($w) : $w;
    } keys @$target;
    my %fold;
    my @out;
    for my $r (keys @$rows) {
	my $row = $rows->[$r];
	my @widths;
	my @kinds;
	my @cells = map {
	    my($cell, $w, $cw) = ($row->[$_], $target->[$_], $rw->[$r][$_]);
	    my @lines = cell_lines($cell);
	    my(@chops, @length, @kind);
	    for my $n (keys @lines) {
		my $line = $lines[$n];
		my $lw = @lines > 1 ? ansi_width($line // '') : $cw;
		my(@c, @l);
		if (defined $w and $lw > $limit[$_]) {
		    @c = ($fold{$w} //= $obj->table_fold($w))->text($line)->chops(length => \@l);
		    for my $k (keys @c) {
			# trailing spaces are removed, and so is their width
			$c[$k] =~ s/(\h+)((?:\e\[[\d;]*m|\e\]8;;[^\e]*\e\\)*)$/$2/ or next;
			my $sp = $1;
			$l[$k] = $sp =~ /^ +$/ ? $l[$k] - length $sp : ansi_width($c[$k]);
		    }
		    @c or do { @c = (''); @l = (0) };
		} else {
		    @c = ($line);
		    @l = ($lw);
		}
		push @kind, ($n ? 2 : 0), (1) x $#c;
		push @chops, @c;
		push @length, @l;
	    }
	    $widths[$_] = \@length;
	    $kinds[$_] = \@kind;
	    \@chops;
	} keys @$row;
	my $height = max(1, map { int @$_ } @cells);
	for my $k (0 .. $height - 1) {
	    push @out, [ map { $_->[$k] // '' } @cells ];
	    push @$ow, [ map { $_->[$k] // 0 } @widths ];
	    next unless $continued and $k;
	    $continued->[$#out][$_] = $kinds[$_][$k] for grep { defined $cells[$_][$k] } keys @cells;
	}
    }
    @out;
}

#
# fit_table_rows(\@rows, \@rw, \@content, $budget, $overhead, \@fixed, $floor, \@continued, \@ow)
#
# Wrap the table into the budget.  Each round:
#
#   1. table_widths() decides the width of every column.
#   2. expand_table_rows() wraps the cells to those widths.
#   3. Measure how wide each wrapped column actually came out.
#   4. A wrapped column that left two or more columns of its width
#      unused (its lines broke at word or kinsoku boundaries before
#      the limit) is fixed at the measured width.  Its wrapped lines
#      are kept as they are.
#   5. If any column was fixed, go back to 1: the fixed column now
#      costs only what it uses, so the remaining wrapped columns get
#      more.  Otherwise stop.
#
# One column short is not "unused": a double-width character cannot
# fill an odd width.  Each round fixes at least one more column or
# stops, so the loop ends within (number of columns + 1) rounds.
#
# Returns the expanded rows.  \@rw, \@continued and \@ow are passed
# to expand_table_rows(); \@continued and \@ow describe the rows
# returned.
#
sub fit_table_rows {
    my($obj, $rows, $rw, $content, $budget, $overhead, $fixed, $floor, $continued, $ow) = @_;
    my @fix = $fixed ? @$fixed : ();
    my @wrap;			# width each column was wrapped at
    my @out;
    while (1) {
	my $target = table_widths($content, $budget, $overhead, \@fix, $floor);
	my @width = map { $wrap[$_] // $target->[$_] } keys @$content;
	@out = $obj->expand_table_rows($rows, $rw, \@width, $content, $continued, $ow);
	my $changed = 0;
	for my $i (keys @$content) {
	    next if defined $fix[$i] or $content->[$i] <= $target->[$i];
	    my $usable = $target->[$i] - $obj->table_margin($target->[$i]);
	    my $measured = max 0, map { $_->[$i] // 0 } @$ow;
	    next if $measured >= $usable - 1;
	    $fix[$i] = $measured;
	    $wrap[$i] = $target->[$i];
	    $changed++;
	}
	last unless $changed;
    }
    @out;
}

1;
