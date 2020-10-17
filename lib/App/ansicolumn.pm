package App::ansicolumn;

our $VERSION = "0.10";

use v5.14;
use warnings;
use utf8;
use Encode;
use open IO => 'utf8', ':std';
use Pod::Usage;
use Getopt::EX::Long qw(:DEFAULT Configure ExConfigure);
ExConfigure BASECLASS => [ __PACKAGE__, "Getopt::EX" ];
Configure("bundling");

use Data::Dumper;
use List::Util qw(max);
use Text::Tabs qw(expand);
use Text::ANSI::Fold qw(:constants);
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
	"debug",
	"version|v",
	) || pod2usage();

    $obj->{version} and do { say $VERSION; exit };

    if ($obj->{linestyle} !~ /^(?:(wordwrap)|wrap|truncate|)$/) {
	die "$obj->{linestyle}: unknown style.\n";
    } elsif ($1) {
	$obj->{linestyle} = 'wrap';
	$obj->{boundary} = 'word';
    }
    $obj->{fullwidth} = 1 if $obj->{pane} and not $obj->{pane_width};
    ($obj->{terminal_width}, $obj->{terminal_height}) = terminal_size;

    ## -P
    if ($obj->{page}) {
	$obj->{page_height} ||= $obj->{terminal_height} - 1;
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

    warn Dumper $obj if $obj->{debug};

    my @lines = expand <>;
    if ($obj->{table}) {
	$obj->table_out(@lines);
    } else {
	$obj->column_out(@lines);
    }
}

sub border {
    my $obj = shift;
    my $border = $obj->{BORDER} or return "";
    $border->get(@_);
}

my %lb_flag = (
    ''     => LINEBREAK_NONE,
    none   => LINEBREAK_NONE,
    runin  => LINEBREAK_RUNIN,
    runout => LINEBREAK_RUNOUT,
    all    => LINEBREAK_ALL,
    );

sub column_out {
    my $obj = shift;
    my %opt = %$obj;
    my @data = @_ or return;
    chomp @data;

    use integer;
    my $width = $opt{output_width} || $obj->{terminal_width};
    my @length = map { ansi_width $_ } @data;
    my $max_length = max @length;
    my $unit = $opt{columnunit} || 1;
    my $span = $opt{pane_width} || ($max_length + $unit) / $unit * $unit;
    my $panes = $opt{pane} || $width / $span || 1;
    if ($opt{fullwidth} and not $opt{pane_width}) {
	$span = $width / $panes;
    }
    $span -= (length($obj->border("left")) + length($obj->border("right")));
    my $cell_width = $span;
    if ($lb_flag{$opt{linebreak}} & LINEBREAK_RUNIN) {
	$cell_width -= $opt{runin};
	die "Not enough space.\n" if $cell_width < 1;
    }
    if ($max_length > $cell_width and
	$opt{linestyle} and $opt{linestyle} ne 'none') {
	my $fold = Text::ANSI::Fold->new(
	    width => $cell_width,
	    boundary => $opt{boundary},
	    linebreak => $lb_flag{$opt{linebreak}},
	    runin => $opt{runin}, runout => $opt{runout},
	    );
	my $hash = { truncate => sub { ($fold->fold($_[0]))[0] },
		     wrap     => sub {  $fold->text($_[0])->chops } };
	my $sub = $hash->{$opt{linestyle}} or die "$opt{linestyle}: unknown";
	@data = map {
	    $length[$_] <= $cell_width ? $data[$_] : $sub->($data[$_])
	} 0 .. $#data;
    }
    $opt{page_height} ||= (@data + $panes - 1) / $panes;

    my $line_in_page = 0;
    my @data_index = 0 .. $#data;
    my $is_last_data = sub { $_[0] == $#data };
    for (my $page = 0; @data_index; $page++) {
	my @page = splice @data_index, 0, $opt{page_height} * $panes;
	my @index = 0 .. $#page;
	my @lines = grep { @$_ } do {
	    if ($opt{fillrows}) {
		map { [ splice @index, 0, $panes ] } 1 .. $opt{page_height};
	    } else {
		zip map { [ splice @index, 0, $opt{page_height} ] } 1 .. $panes;
	    }
	};
	my @fmt;
	my @format = (("%s%-${span}s%s") x ($panes - 1), "%s%-${span}s");
	for my $i (0.. $#lines) {
	    my $line = $lines[$i];
	    my $pos = $i == 0 ? 0 : $i == $#lines ? 2 : 1;
	    my $l = $obj->border('left',  $pos, $page);
	    my $r = $obj->border('right', $pos, $page);
	    my @panes = map {
		my $data_index = $page[${$line}[$_]];
		if ($is_last_data->($data_index)) {
		    $l = $obj->border('left',  2, $page);
		    $r = $obj->border('right', 2, $page);
		}
		ansi_sprintf $format[$_], $l, $data[$data_index], $r;
	    } 0 .. $#{$line};
	    print join '', @panes;
	    print "\n";
	}
    }
}

sub table_out {
    my $obj = shift;
    my %opt = %$obj;
    return unless @_;
    chomp @_;
    my $split = do {
	if ($opt{separator} eq ' ') {
	    $opt{ignore_space} ? ' ' : qr/ /;
	} else {
	    qr/[\Q$opt{separator}\E]/;
	}
    };
    my @lines  = map { [ split $split, $_ ] } @_;
    my @length = map { [ map { ansi_width $_ } @$_ ] } @lines;
    my @max    = map { max @$_ } zip @length;
    my @right;   map { $right[$_ - 1] = 1 } split /,/, $opt{table_right};
    my @format = map {
	sprintf '%%'.'%s'.'%ds', $right[$_] ? '' : '-', $max[$_];
    } 0 .. $#max;
    for my $line (@lines) {
	my $format = join($obj->{output_separator},
			  @format[0..$#{$line}-1], "%s\n");
	ansi_printf $format, @$line;
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

