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
# Decide target content width for each table column.
#
#   @content  natural (unformatted) maximum width of each column
#   $budget   total allowance for content+overhead of all columns,
#             or undef when no total width is requested
#   $overhead per-column cost added by --item-format
#   @fixed    width fixed by --cell for each column, undef for free
#             columns (whole argument may be undef)
#   $floor    minimum width given to a free column
#
# Free columns whose content fits keep their natural width.  When
# the free columns do not fit, they share the remaining budget by
# the "water level" rule: find the largest L (>= $floor) such that
# sum(min(content, L) + overhead) <= remaining, and give each free
# column min(content, L).
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

1;
