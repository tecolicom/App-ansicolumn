package App::ansicolumn;

our $VERSION = "0.11";

use v5.14;
use warnings;
use utf8;
use Encode;
use open IO => 'utf8', ':std';
use Pod::Usage;
use Getopt::EX::Long qw(:DEFAULT Configure ExConfigure);
ExConfigure BASECLASS => [ __PACKAGE__, "Getopt::EX" ];
Configure "bundling";

use Data::Dumper;
use List::Util qw(max reduce);
use Text::Tabs qw(expand);
use Text::ANSI::Fold::Util qw(ansi_width);
use Text::ANSI::Printf qw(ansi_printf ansi_sprintf);
use App::ansicolumn::Util;
use App::ansicolumn::Border;

sub new {
    my $class = shift;
    bless {
	output_width     => undef,
	fillrows         => undef,
	table            => undef,
	table_right      => '',
	separator        => ' ',
	output_separator => '  ',
	page_height      => 0,
	columnunit       => 8,
	pane             => 0,
	pane_width       => undef,
	tabstop          => \$Text::Tabs::tabstop,
	ignore_space     => 1,
	fullwidth        => undef,
	linestyle        => '',
	boundary         => '',
	linebreak        => '',
	runin            => 2,
	runout           => 2,
	border           => undef,
	border_theme     => 'light-bar',
	document         => undef,
	insert_space     => undef,
	top_space        => 1,
	ambiguous        => 'narrow',
	colormap         => [],
	COLORHASH        => {},
	COLORLIST        => [],
    }, $class;
}

sub run {
    my $obj = shift;
    local @ARGV = map { utf8::is_utf8($_) ? $_ : decode('utf8', $_) } @_;
    GetOptions(
	$obj,
	"output_width|output-width|c=i",
	"fillrows|x",
	"table|t",
	"table_right|table-right|R=s",
	"separator|s=s",
	"output_separator|output-separator|o=s",
	"page|P",
	"page_height|page-height|ph=i",
	"columnunit|cu=i",
	"pane|C=i",
	"pane_width|pane-width|pw|S=i",
	"tabstop|ts=i",
	"ignore_space|ignore-space|is!",
	"fullwidth!",
	"linestyle|ls=s",
	"boundary=s",
	"linebreak|lb=s", "runin=i", "runout=i",
	"border!",
	"border_theme|border-theme|bt=s",
	"document|D",
	"colormap|cm=s@",
	"insert_space|insert-space!",
	"top_space|top-space!",
	"ambiguous=s",
	"debug",
	"version|v",
	) || pod2usage();
    $obj->{version} and do { say $VERSION; exit };
    $obj->setup_options;

    warn Dumper $obj if $obj->{debug};

    chomp (my @lines = expand <>);
    @lines = insert_space @lines if $obj->{insert_space};

    if ($obj->{table}) {
	$obj->table_out(@lines);
    } else {
	$obj->column_out(@lines);
    }
}

sub setup_options {
    my $obj = shift;

    if ($obj->{linestyle} !~ /^(?:|none|(wordwrap)|wrap|truncate)$/) {
	die "$obj->{linestyle}: unknown style.\n";
    } elsif ($1) {
	$obj->{linestyle} = 'wrap';
	$obj->{boundary} = 'word';
    }
    $obj->{fullwidth} = 1 if $obj->{pane} and not $obj->{pane_width};

    ## -P
    if ($obj->{page}) {
	$obj->{page_height} ||= $obj->term_height - 1;
	$obj->{linestyle}  ||= 'wrap';
	$obj->{border} //= 1;
    }
    ## -D
    if ($obj->{document}) {
	$obj->{fullwidth} = 1;
	$obj->{linebreak} ||= 'all';
	$obj->{linestyle} ||= 'wrap';
	$obj->{boundary}  ||= 'word';
    }

    ## --colormap
    use Getopt::EX::Colormap;
    my $cm = Getopt::EX::Colormap
	->new(HASH => $obj->{COLORHASH}, LIST => $obj->{COLORLIST})
	->load_params(@{$obj->{colormap}});
    $obj->{COLOR} = sub { $cm->color(@_) };

    ## --border
    if ($obj->{border}) {
	($obj->{BORDER} = App::ansicolumn::Border->new)
	    ->theme($obj->{border_theme}) // die "Unknown theme.\n";
    }

    ## --ambiguous=wide
    if ($obj->{ambiguous} eq 'wide') {
	$Text::VisualWidth::PP::EastAsian = 1;
	Text::ANSI::Fold->configure(ambiguous => 'wide');
    }

    $obj;
}

sub column_out {
    my $obj = shift;
    my @data = @_ or return;
    chomp @data;

    use integer;
    my $width = $obj->width;
    my @length = map ansi_width($_), @data;
    my $max_length = max @length;
    my $unit = $obj->{columnunit} || 1;

    my $span;
    my $panes;
    if ($obj->{fullwidth} and not $obj->{pane_width}) {
	my $min = $max_length + ($obj->border_width || 1);
	$panes = $obj->{pane} || $width / $min || 1;
	$span = $width / $panes;
    } else {
	$span = $obj->{pane_width} ||
	    roundup($max_length + ($obj->border_width || 1), $unit);
	$panes = $obj->{pane} || $width / $span || 1;
    }
    $span -= $obj->border_width;

    ## Fold long lines.
    (my $cell_width = $span - $obj->margin_width) < -1
	and die "Not enough space.\n";
    if ($max_length > $cell_width and
	$obj->{linestyle} and $obj->{linestyle} ne 'none') {
	my $sub = $obj->foldsub($cell_width) or die;
	@data = map {
	    $length[$_] <= $cell_width ? $data[$_] : $sub->($data[$_])
	} 0 .. $#data;
    }
    my $height = $obj->{page_height} || div(0+@data, $panes);

    ## --no-topspace
    if (not $obj->{top_space}) {
	remove_topspaces \@data, $height;
    }

    my @data_index = 0 .. $#data;
    my $is_last_data = sub { $_[0] == $#data };
    for (my $page = 0; @data_index; $page++) {
	my @page = splice @data_index, 0, $height * $panes;
	my @index = 0 .. $#page;
	my @lines = grep { @$_ } do {
	    if ($obj->{fillrows}) {
		map { [ splice @index, 0, $panes ] } 1 .. $height;
	    } else {
		zip map { [ splice @index, 0, $height ] } 1 .. $panes;
	    }
	};
	my @format = (("%s%-${span}s%s") x (@{$lines[0]} - 1), "%s%-${span}s");
	for my $i (0.. $#lines) {
	    my $line = $lines[$i];
	    my $pos = $i == 0 ? 0 : $i == $#lines ? 2 : 1;
	    my @bdr = map $obj->border($_, $pos, $page), qw(left right);
	    my @panes = map {
		my $data_index = $page[${$line}[$_]];
		if ($is_last_data->($data_index)) {
		    @bdr = map $obj->border($_, 2, $page), qw(left right);
		}
		ansi_sprintf $format[$_], $bdr[0], $data[$data_index], $bdr[1];
	    } 0 .. $#{$line};
	    print @panes;
	    print "\n";
	}
    }
}

sub table_out {
    my $obj = shift;
    return unless @_;
    my $split = do {
	if ($obj->{separator} eq ' ') {
	    $obj->{ignore_space} ? ' ' : qr/ /;
	} else {
	    qr/[\Q$obj->{separator}\E]/;
	}
    };
    my @lines  = map { [ split $split, $_ ] } @_;
    my @length = map { [ map { ansi_width $_ } @$_ ] } @lines;
    my @max    = map { max @$_ } zip @length;
    my @align  = newlist(count => 0+@max, default => '-',
			 [ map --$_, split /,/, $obj->{table_right} ] => '');
    my @format = map { '%' . $align[$_] . $max[$_] . 's' } 0 .. $#max;
    for my $line (@lines) {
	my @fmt = @format[0 .. $#{$line}];
	$fmt[$#{$line}] = '%s' if $align[$#{$line}] eq '-';
	my $format = join $obj->{output_separator}, @fmt;
	ansi_printf $format, @$line;
	print "\n";
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

ansicolumn - ANSI sequence aware column command

=head1 DESCRIPTION

Document is included in executable script.
Use `perldoc ansicolumn`.

=head1 AUTHOR

Kazumasa Utashiro

=head1 LICENSE

Copyright 2020 Kazumasa Utashiro.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

