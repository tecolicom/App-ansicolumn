package App::ansicolumn::Document;

=encoding utf-8

=head1 NAME

App::ansicolumn::Document - The text of a file as parts of lines

=head1 DESCRIPTION

A document is the text of a file, kept as a list of parts, each of
them a list of lines.  The parts are what form feeds divide: there is
one part when the text is not divided.  This is the only place which
knows of a form feed as a break, and of the parts as a structure.

=cut

use v5.14;
use warnings;
use utf8;
use List::Util qw(any);

#
# new(name => NAME, text => TEXT, formfeed => BOOL)
# new(name => NAME, parts => [ [ LINE, ... ], ... ])
#
# With "formfeed", the text is divided at form feeds.  Without it the
# text is one part, and a form feed is left in the lines as it is.
# With "keep_ls", a LINE SEPARATOR (U+2028) does not end a line: the
# table mode takes it as a line break in a cell.
#
sub new {
    my $class = shift;
    my %arg = @_;
    my $parts = $arg{parts} // do {
	my $text = $arg{text} // '';
	my $eol = $arg{keep_ls} ? qr/(?![\f\x{2028}])\R/ : qr/(?!\f)\R/;
	[ map { [ split $eol ] }
	  $arg{formfeed} ? _split_formfeed($text) : $text ];
    };
    bless {
	name  => $arg{name},
	parts => $parts,
	width => 0,
	span  => undef,
    }, $class;
}

sub name { $_[0]->{name} }

# the width of the longest line, which the reader sets
sub width {
    my $obj = shift;
    @_ ? ($obj->{width} = shift) : $obj->{width};
}

# the width of the pane, when it has one of its own
sub span {
    my $obj = shift;
    @_ ? ($obj->{span} = shift) : $obj->{span};
}

# the parts, each a reference to the list of its lines
sub parts { @{$_[0]->{parts}} }

# all the lines, as a copy
sub lines { map { @$_ } $_[0]->parts }

sub is_empty { not any { @$_ } $_[0]->parts }

# replace the lines of every part with what the code gives for them
sub filter {
    my $obj = shift;
    my $code = shift;
    @$_ = $code->(@$_) for $obj->parts;
    $obj;
}

# replace every line with what the code gives for it, within its part
sub replace {
    my $obj = shift;
    my $code = shift;
    $obj->filter(sub { map { $code->($_) } @_ });
}

# a document for each part
sub pages {
    my $obj = shift;
    map { ref($obj)->new(name => $obj->name, parts => [ $_ ]) } $obj->parts;
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
sub _split_formfeed {
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

1;
