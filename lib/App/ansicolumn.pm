package App::ansicolumn;

our $VERSION = "0.07";

use v5.14;
use warnings;
use utf8;
use open IO => 'utf8', ':std';
use Pod::Usage;
use Getopt::EX::Long;
Getopt::Long::Configure("bundling");

use Data::Dumper;
use List::Util qw(max);
use Text::Tabs qw(expand);
use Text::ANSI::Fold qw(:constants);
use Text::ANSI::Fold::Util qw(ansi_width);
use Text::ANSI::Printf qw(ansi_printf ansi_sprintf);
use App::ansicolumn::Util;

sub new {
    my $class = shift;
    bless {
	output_width     => undef,
	fillrows         => undef,
	table            => undef,
	separator        => ' ',
	output_separator => '  ',
	pagelength       => 0,
	margin           => 0,
	columnunit       => 8,
	pane             => 0,
	tabstop          => \$Text::Tabs::tabstop,
	ignore_space     => 1,
	fullwidth        => undef,
	linestyle        => '',
	boundary         => '',
	linebreak        => '',
	runin            => 4,
	runout           => 4,
	prefix           => '',
	postfix          => ' ',
	document         => undef,
    }, $class;
}

sub run {
    my $obj = shift;
    local @ARGV = @_;
    GetOptions(
	$obj,
	"output_width|output-width|c=i",
	"fillrows|x",
	"table|t",
	"separator|s=s",
	"output_separator|output-separator|o=s",
	"page|P",
	"pagelength|pl=i",
	"margin=i",
	"columnunit|cu=i",
	"pane|C=i",
	"tabstop|ts=i",
	"ignore_space|ignore-space|is!",
	"fullwidth!",
	"linestyle|ls=s",
	"boundary=s",
	"linebreak|lb=s", "runin=i", "runout=i",
	"prefix=s", "postfix=s",
	"document|D",
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
    $obj->{fullwidth} = 1 if $obj->{pane};
    ($obj->{terminal_width}, $obj->{terminal_height}) = terminal_size;

    ## -P
    if ($obj->{page}) {
	$obj->{pagelength} ||= $obj->{terminal_height} - 1;
	$obj->{linestyle}  ||= 'wrap';
    }
    ## -D
    if ($obj->{document}) {
	$obj->{fullwidth} = 1;
	$obj->{postfix}   ||= ' ';
	$obj->{linebreak} ||= 'all';
	$obj->{linestyle} ||= 'wrap';
	$obj->{boundary}  ||= 'word';
    }

    warn Dumper $obj if $obj->{debug};

    my @lines = expand <>;
    if ($obj->{table}) {
	$obj->table_out(@lines);
    } else {
	$obj->column_out(@lines);
    }
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
    my @data = @_;
    return unless @data;
    chop @data;

    use integer;
    my $width = $opt{output_width} || $obj->{terminal_width};
    my @length = map { ansi_width $_ } @data;
    my $max_length = max @length;
    my $unit = $opt{columnunit} || 1;
    my $span = ($max_length + $unit) / $unit * $unit;
    my $panes = $opt{pane} || $width / $span || 1;
    if ($opt{fullwidth}) {
	$span = $width / $panes;
    }
    $span -= length($opt{prefix}) + length($opt{postfix});
    if ($max_length > $span
	and $opt{linestyle} and $opt{linestyle} ne 'none') {
	my $width = $span;
	if ($lb_flag{$opt{linebreak}} & LINEBREAK_RUNIN) {
	    $width -= $opt{runin};
	    die "Not enough space.\n" if $width <= 0;
	}
	my $fold = Text::ANSI::Fold->new(
	    width => $width,
	    boundary => $opt{boundary},
	    linebreak => $lb_flag{$opt{linebreak}},
	    runin => $opt{runin}, runout => $opt{runout},
	    );
	my $hash = { truncate => sub { ($fold->fold($_[0]))[0] },
		     wrap     => sub { $fold->text($_[0])->chops } };
	my $sub = $hash->{$opt{linestyle}} or die "$opt{linestyle}: unknown";
	@data = map {
	    $length[$_] <= $span ? $data[$_] : $sub->($data[$_])
	} 0 .. $#data;
    }
    $opt{pagelength} ||= (@data + $panes - 1) / $panes;
    my($pre, $post) = @opt{qw(prefix postfix)};
    while (@data) {
	my @page = splice @data, 0, $opt{pagelength} * $panes;
	my @index = 0 .. $#page;
	my @lines = grep { @$_ } do {
	    if ($opt{fillrows}) {
		map { [ splice @index, 0, $panes ] } 1 .. $opt{pagelength};
	    } else {
		zip map { [ splice @index, 0, $opt{pagelength} ] } 1 .. $panes;
	    }
	};
	for my $line (@lines) {
	    my $fmt = "${pre}%-${span}s${post}" x (@$line - 1) . "${pre}%s\n";
	    ansi_printf $fmt, @page[@$line];
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
    my @format = map { sprintf "%%-%ds", $_ } @max;
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

