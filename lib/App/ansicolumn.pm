package App::ansicolumn;

our $VERSION = "0.01";

use v5.14;
use warnings;
use open IO => 'utf8', ':std';
use Pod::Usage;
use Getopt::EX::Long;

sub new {
    my $class = shift;
    bless {
	tab => 8,
	separator => ' ',
    }, $class;
}

sub run {
    my $obj = shift;
    local @ARGV = @_;

    my @optargs = (
	$obj,
	"column|c=i",
	"transpose|xpose|x",
	"table|t",
	"separator|s=s",
	"tab=i",
	);
    Getopt::Long::Configure("bundling");
    GetOptions(@optargs) || pod2usage();
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
    my $fields = $width / $span || 1;
    my $rows = (@item + $fields - 1) / $fields;
    my @index = 0 .. $#item;
    my @lines = do {
	if ($opt{transpose}) {
	    map { [ splice @index, 0, $fields ] } 1 .. $rows;
	} else {
	    zip map { [ splice @index, 0, $rows ] } 1 .. $fields;
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
    my $split  = qr/[\Q$obj->{separator}\E]/;
    my @lines  = map { [ grep { $_ ne '' } split $split, $_ ] } @_;
    my @length = map { [ map { ansi_width $_ } @$_ ] } @lines;
    my @max    = map { max @$_ } zip @length;
    my @format = map { sprintf "%%-%ds", $_ } @max;
    for my $line (@lines) {
	my $format = join('  ', @format[0..$#{$line}]) . "\n";
	ansi_printf $format, @$line;
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

ansicolumn - ANSI sequence aware column command

=head1 SYNOPSIS

ansicolumn [-tx] [-c columns]

=head1 DESCRIPTION

From column(1):

=over 4

The column utility formats its input into multiple columns.  Rows are
filled before columns.  Input is taken from file operands, or, by
default, from the standard input.  Empty lines are ignored.

=over 7

=item -c

Output is formatted for a display columns wide.

=item -s

Specify a set of characters to be used to delimit columns for the
-t option.

=item -t

Determine the number of columns the input contains and create a
table.  Columns are delimited with whitespace, by default, or
with the characters supplied using the -s option.  Useful for
pretty-printing displays.

=item -x

Fill columns before filling rows.

=back

=back

B<ansicolumn> is a clone which can handle ANSI terminal sequences.

=head1 AUTHOR

Kazumasa Utashiro

=head1 LICENSE

Copyright 2020 Kazumasa Utashiro.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

