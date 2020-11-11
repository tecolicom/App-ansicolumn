package App::ansicolumn::Border;

=encoding utf-8

=head1 NAME

App::ansicolumn::Border - App::ansicolumn Border module

=head1 DESCRIPTION

Each item has five elements; L<right>, L<center>, L<left>, L<top>,
L<bottom>.

L<right>, L<left> and L<center> items can hold string value or list
reference.  String value is equivalent to a list of single item.  If
the list has single item, it is used on all position.  If the second
item exists, it is used on middle positions.  Third item is for bottom
position.

Class method L<add_style> can be used to add new border style.

This is experimental implementation and subject to change.

=cut

use v5.14;
use warnings;
use utf8;
use Data::Dumper;

my %template = (
    DEFAULT => {
	right  => '',
	center => '  ',
	left   => '',
	top    => '',
	bottom => '',
    },
    none => {
	right  => '',
	center => '',
	left   => '',
	top    => '',
	bottom => '',
    },
    side  => { right => ' ' , left => ' ' },
    left  => { right => ''  , left => '  ' },
    light => {
	center => "│ ", # "\x{2502} "
    },
    heavy => {
	center => "┃ ", # "\x{2503} "
    },
    light_bar => {
	center => [ "╷ "  , # "\x{2577} "
		    "│ "  , # "\x{2502} "
		    "╵ " ], # "\x{2575} "
    },
    light_fence => {
	left   => [ "╷ "  , # "\x{2577} "
		    "│ "  , # "\x{2502} "
		    "╵ " ], # "\x{2575} "
	center => [ "╷ "  , # "\x{2577} "
		    "│ "  , # "\x{2502} "
		    "╵ " ], # "\x{2575} "
	right  => [ "╷"   , # "\x{2577} "
		    "│"   , # "\x{2502} "
		    "╵"  ], # "\x{2575} "
    },
    ascii_frame => {
	top    =>   "-",
	bottom =>   "-",
	left   => [ "+-"  ,
		    "| "  ,
		    "+-" ],
	center => [ "+ +-"  ,
		    "| | "  ,
		    "+ +-" ],
	right  => [ "+"    ,
		    "|"    ,
		    "+"   ],
    },
    ascii_box => {
	top    =>    "-",
	bottom =>    "-",
	left   => [ "+-"  ,
		    "| "  ,
		    "+-" ],
	center => [ "+-"  ,
		    "| "  ,
		    "+-" ],
	right  => [ "+"   ,
		    "|"   ,
		    "+"  ],
    },
    light_frame => {
	top    =>     "─",
	bottom =>     "─",
	left   => [  "┌─"  ,
		     "│ "  ,
		     "└─" ],
	center => [ "┐┌─"  ,
		    "││ "  ,
		    "┘└─" ],
	right  => [ "┐"    ,
		    "│"    ,
		    "┘"   ],
    },
    light_box => {
	top    =>    "─",
	bottom =>    "─",
	left   => [ "┌─"  ,
		    "│ "  ,
		    "└─" ],
	center => [ "┬─"  ,
		    "│ "  ,
		    "┴─" ],
	right  => [ "┐"   ,
		    "│"   ,
		    "┘"  ],
    },
    light_box2 => {
	top    =>    "─",
	left   => [ "┌─"  ,
		    "│ "  ,
		    "│ " ],
	center => [ "┬─"  ,
		    "│ "  ,
		    "│ " ],
	right  => [ "┐"   ,
		    "│"   ,
		    "│"  ],
    },
    light_mesh => {
	top    =>   "─",
	left   => [ "┼"  ,
		    "│"  ,
		    "│" ],
	center => [ "┼"  ,
		    "│"  ,
		    "│" ],
	right  => [ "┼"  ,
		    "│"  ,
		    "│" ],
    },
    heavy_bar => {
	center => [ "╻ "  , # "\x{257B} "
		    "┃ "  , # "\x{2503} "
		    "╹ " ], # "\x{2579} "
    },
    light_heavy => {
	center => [ "╿ "  , # "\x{257F} "
		    "│ "  , # "\x{2502} "
		    "╽ " ], # "\x{257D} "
    },
    heavy_light => {
	center => [ "╽ "  , # "\x{257D} "
		    "┃ "  , # "\x{2503} "
		    "╿ " ], # "\x{257F} "
    },
    heavydash_bar => {
	center => [ "╻ "  , # "\x{257B} "
		    "╏ "  , # "\x{254F} "
		    "╹ " ], # "\x{2579} "
    },
    light_block => {
	center => [ "▄ "  , # "\x{2584} "
		    "│ "  , # "\x{2502} "
		    "▀ " ], # "\x{2580} "
    },
    heavy_block => {
	center => [ "▄ "  , # "\x{2584} "
		    "┃ "  , # "\x{2503} "
		    "▀ " ], # "\x{2580} "
    },
    light_tape => {
	center => [ "┌┐ "  , # "\x{250c}\x{2510}"
		    "││ "  , # "\x{2502}\x{2502}"
		    "└┘ " ], # "\x{2514}\x{2518}"
	left => ' ',
    },
    light_roundtape => {
	center => [ "╭╮"  , # "\x{256D}\x{256E}"
		    "││"  , # "\x{2502}\x{2502}"
		    "╰╯" ], # "\x{2570}\x{256F}"
    },
    light_doubletape => {
	center => [ "╒╕"  , # "\x{2552}\x{2555}"
		    "││"  , # "\x{2502}\x{2502}"
		    "╘╛" ], # "\x{2558}\x{255B}"
    },
    double_tape => {
	center => [ "╔╗"  , # "\x{2554}\x{2557}"
		    "║║"  , # "\x{2551}\x{2551}"
		    "╚╝" ], # "\x{255A}\x{255D}"
    },
    heavy_tape => {
	center => [ "┏┓"  , # "\x{250F}\x{2513}"
		    "┃┃"  , # "\x{2503}\x{2503}"
		    "┗┛" ], # "\x{2517}\x{251B}"
    },
    block_element => {
	center => [ "▄ "  , # "\x{2584} "
		    "█ "  , # "\x{2588} "
		    "▀ " ], # "\x{2580} "
    },
    block_element_half => {
	center => [ "▗ "  , # "\x{2597} "
		    "▐ "  , # "\x{2590} "
		    "▝ " ], # "\x{259D} "
    },
    );

sub new {
    my $class = shift;
    my $style = @_ ? shift : 'DEFAULT';
    (bless { %template }, $class)->style($style);
}

sub style {
    my $obj = shift;
    my $style = do {
	if (@_) {
	    $obj->{__STYLE__} = +shift =~ tr[-][_]r;
	} else {
	    return $obj->{__STYLE__};
	}
    };
    $obj->{$style} or return undef;
    $obj->{CURRENT} //= {};
    # %{$obj->{CURRENT}} = %{$obj->{$style}}
    %{$obj->{CURRENT}} =
	map { $_ => $obj->{$style}->{$_} } keys %{$obj->{$style}};
    $obj;
}

sub get {
    my $obj = shift;
    $obj->get_by_style('CURRENT', @_) // $obj->get_by_style('DEFAULT', @_)
	// die;
}

sub add_style {
    my $obj = shift;
    die if @_ % 2;
    while (my($name, $style) = splice @_, 0, 2) {
	$template{$name} = $style;
    }
    $obj;
}

sub get_by_style ($ $$;$$) {
    my $obj = shift;
    my($style, $place, $position, $page) = (shift, shift, shift//0, shift//0);
    my $hash = $obj->{$style} // return undef;
    my $entry = $hash->{$place} // return undef;
    if (not ref $entry) {
	return $entry;
    } elsif (@$entry == 0) {
	return undef;
    } else {
	my $target = ref $entry->[0] ? $entry->[$page / @$entry] : $entry;
	return $target->[$position % @$target];
    }
}

1;
