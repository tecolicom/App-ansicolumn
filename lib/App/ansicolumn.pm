package App::ansicolumn;

our $VERSION = "0.03";

use v5.14;
use warnings;
use open IO => 'utf8', ':std';
use Pod::Usage;
use Getopt::EX::Long;
Getopt::Long::Configure("bundling");

sub new {
    my $class = shift;
    bless {
	tab          => 8,
	pane         => 0,
	separator    => ' ',
	join         => '  ',
	ignore_space => 1,
    }, $class;
}

sub run {
    my $obj = shift;
    local @ARGV = @_;
    GetOptions(
	$obj,
	"column|c=i",
	"transpose|xpose|x",
	"table|t",
	"separator|s=s",
	"tab=i",
	"pane=i",
	"join=s",
	"ignore_space|ignore-space|is!",
	) || pod2usage();
    if ($obj->{table}) {
	$obj->table_out(<>);
    } else {
	$obj->column_out(<>);
    }
}

use Data::Dumper;
use List::Util qw(max);
use Text::ANSI::Fold::Util qw(ansi_width);
use Text::ANSI::Printf qw(ansi_printf ansi_sprintf);
use App::ansicolumn::Util;

sub column_out {
    my $obj = shift;
    my %opt = %$obj;
    my @item = @_;
    return unless @item;
    chop @item;

    use integer;
    my $width = $opt{column} || terminal_width();
    my @width = map { ansi_width $_ } @item;
    my $tab = $opt{tab} || 1;
    my $span = (max(@width) + $tab) / $tab * $tab;
    my $panes = $opt{pane} || $width / $span || 1;
    my $rows = (@item + $panes - 1) / $panes;
    my @index = 0 .. $#item;
    my @lines = do {
	if ($opt{transpose}) {
	    map { [ splice @index, 0, $panes ] } 1 .. $rows;
	} else {
	    zip map { [ splice @index, 0, $rows ] } 1 .. $panes;
	}
    };
    for my $line (@lines) {
	my $format = "%-${span}s" x (@$line - 1) . "%s\n";
	ansi_printf $format, @item[@$line];
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
	my $format = join $obj->{join}, @format[0..$#{$line}-1], "%s\n";
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

