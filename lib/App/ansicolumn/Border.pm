package App::ansicolumn::Border;

use v5.14;
use warnings;
use utf8;
use Data::Dumper;

my %template = (
    DEFAULT => {
	right  => '  ',
	left   => '',
	top    => '',
	buttom => '',
    },
    none => {
	right  => '',
	left   => '',
	top    => '',
	buttom => '',
    },
    right => { right => '  ' },
    side  => { right => ' ' , left => ' ' },
    left  => { right => ''  , left => '  ' },
    light => {
	right => "│ ", # "\x{2502} "
    },
    heavy => {
	right => "┃ ", # "\x{2503} "
    },
    light_bar => {
	right => [ "╷ "  , # "\x{2577} "
		   "│ "  , # "\x{2502} "
		   "╵ " ], # "\x{2575} "
    },
    heavy_bar => {
	right => [ "╻ "  , # "\x{257B} "
		   "┃ "  , # "\x{2503} "
		   "╹ " ], # "\x{2579} " ]
    },
    light_heavy => {
	right => [ "╿ "  , # "\x{257F} "
		   "│ "  , # "\x{2502} "
		   "╽ " ], # "\x{257D} "
    },
    heavy_light => {
	right => [ "╽ "  , # "\x{257D} "
		   "┃ "  , # "\x{2503} "
		   "╿ " ], # "\x{257F} "
    },
    heavydash_bar => {
	right => [ "╻ "  , # "\x{257B} "
		   "╏ "  , # "\x{254F} "
		   "╹ " ], # "\x{2579} "
    },
    light_block => {
	right => [ "▄ "  , # "\x{2584} "
		   "│ "  , # "\x{2502} "
		   "▀ " ], # "\x{2580} "
    },
    heavy_block => {
	right => [ "▄ "  , # "\x{2584} "
		   "┃ "  , # "\x{2503} "
		   "▀ " ], # "\x{2580} "
    },
    light_box => {
	right => [ "┌┐"  , # "\x{250c}\x{2510}"
		   "││"  , # "\x{2502}\x{2502}"
		   "└┘" ], # "\x{2514}\x{2518}"
    },
    light_roundbox => {
	right => [ "╭╮"  , # "\x{256D}\x{256E}"
		   "││"  , # "\x{2502}\x{2502}"
		   "╰╯" ], # "\x{2570}\x{256F}"
    },
    light_doublebox => {
	right => [ "╒╕"  , # "\x{2552}\x{2555}"
		   "││"  , # "\x{2502}\x{2502}"
		   "╘╛" ], # "\x{2558}\x{255B}"
    },
    double_box => {
	right => [ "╔╗"  , # "\x{2554}\x{2557}"
		   "║║"  , # "\x{2551}\x{2551}"
		   "╚╝" ], # "\x{255A}\x{255D}"
    },
    heavy_box => {
	right => [ "┏┓"  , # "\x{250F}\x{2513}"
		   "┃┃"  , # "\x{2503}\x{2503}"
		   "┗┛" ], # "\x{2517}\x{251B}"
    },
    block_element => {
	right => [ "▄ "  , # "\x{2584} "
		   "█ "  , # "\x{2588} "
		   "▀ " ], # "\x{2580} "
    },
    block_element_half => {
	right => [ "▗ "  , # "\x{2597} "
		   "▐ "  , # "\x{2590} "
		   "▝ " ], # "\x{259D} "
    },
    star   => { right => [ "★ ", "☆ " ] },
    square => { right => [ "■ ", "□ " ] },
    pipe   => { right => [ "  ", "| " ] },
    );

sub new {
    my $class = shift;
    my $theme = @_ ? shift : 'DEFAULT';
    (bless { %template }, $class)->theme($theme);
}

sub theme {
    my $obj = shift;
    my $theme = do {
	if (@_) {
	    $obj->{__THEME__} = +shift =~ tr[-][_]r;
	} else {
	    return $obj->{__THEME__};
	}
    };
    $obj->{CURRENT} = $obj->{$theme} // return undef;
    $obj;
}

sub get {
    my $obj = shift;
    $obj->get_by_theme('CURRENT', @_) // $obj->get_by_theme('DEFAULT', @_)
	// die;
}

sub get_by_theme ($ $$;$$) {
    my $obj = shift;
    my($theme, $place, $position, $page) = (shift, shift, shift//0, shift//0);
    my $hash = $obj->{$theme} // return undef;
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
