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
# expand_table_rows(\@rows, \@target, \@content, \@continued)
#
# Wrap cells wider than their target width and expand each logical
# row into as many physical rows as its tallest cell.  Missing cell
# lines are filled with empty strings.  Ragged rows stay ragged.
# When \@continued is given, $continued[row][col] is set for every
# cell that is the second or later line of a wrapped cell.
#
# In a column that has a cell wider than the target (its widest cell,
# $content[col], is wider), every cell wider than the target minus the
# run-in margin is wrapped, as lines are in panes, so that a cell
# fitting in the margin is not left longer than the wrapped lines.
#
sub expand_table_rows {
    my($obj, $rows, $target, $content, $continued) = @_;
    @$continued = () if $continued;
    my @limit = map {
	my($i, $w) = ($_, $target->[$_]);
	!defined $w ? undef :
	$content->[$i] > $w ? $w - $obj->table_margin($w) : $w;
    } keys @$target;
    my %fold;
    my @out;
    for my $row (@$rows) {
	my @cells = map {
	    my($cell, $w) = ($row->[$_], $target->[$_]);
	    if (defined $w and ansi_width($cell) > $limit[$_]) {
		my @chops = ($fold{$w} //= $obj->table_fold($w))->text($cell)->chops;
		s/\h+((?:\e\[[\d;]*m|\e\]8;;[^\e]*\e\\)*)$/$1/ for @chops;
		@chops ? \@chops : [ '' ];
	    } else {
		[ $cell ];
	    }
	} keys @$row;
	my $height = max(1, map { int @$_ } @cells);
	for my $k (0 .. $height - 1) {
	    push @out, [ map { $_->[$k] // '' } @cells ];
	    next unless $continued and $k;
	    $continued->[$#out][$_] = 1 for grep { defined $cells[$_][$k] } keys @cells;
	}
    }
    @out;
}

#
# fit_table_rows(\@rows, \@content, $budget, $overhead, \@fixed, $floor, \@continued)
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
# Returns the expanded rows.  \@continued is passed to
# expand_table_rows() and describes the rows returned.
#
sub fit_table_rows {
    my($obj, $rows, $content, $budget, $overhead, $fixed, $floor, $continued) = @_;
    my @fix = $fixed ? @$fixed : ();
    my @wrap;			# width each column was wrapped at
    my @out;
    while (1) {
	my $target = table_widths($content, $budget, $overhead, \@fix, $floor);
	my @width = map { $wrap[$_] // $target->[$_] } keys @$content;
	@out = $obj->expand_table_rows($rows, \@width, $content, $continued);
	my $changed = 0;
	for my $i (keys @$content) {
	    next if defined $fix[$i] or $content->[$i] <= $target->[$i];
	    my $usable = $target->[$i] - $obj->table_margin($target->[$i]);
	    my $measured = max 0, map { ansi_width($_->[$i] // q()) } @out;
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
