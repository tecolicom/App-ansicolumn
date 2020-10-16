package App::ansicolumn::Border;

use v5.14;
use warnings;
use utf8;
use Data::Dumper;

sub new {
    my $class = shift;
    my $theme = @_ ? shift : 'DEFAULT';
    my $obj = bless {
	DEFAULT => {
	    right  => [ '  ' ],
	    left   => [ '' ],
	    top    => [ '' ],
	    buttom => [ '' ],
	},
	none => {
	    right  => [ '' ],
	    left   => [ '' ],
	    top    => [ '' ],
	    buttom => [ '' ],
	},
	space => {
	    right  => [ ' ' ],
	},
	light_bar => {
	    right => [ "╷ " , # "\x{2577} "
		       "│ " , # "\x{2502} "
		       "╵ " ] # "\x{2575} "
	},
	heavy_bar => {
	    right => [ "╻ " , # "\x{257B} "
		       "┃ " , # "\x{2503} "
		       "╹ " ] # "\x{2579} " ]
	},
	light_heavy_bar => {
	    right => [ "\x{257F} ",
		       "\x{2502} ",
		       "\x{257D} " ],
	},
	heavy_light_bar => {
	    right => [ "\x{257D} ",
		       "\x{2503} ",
		       "\x{257F} " ],
	},
	heavy_dash_bar => {
	    right => [ "\x{257B} ",
		       "\x{254F} ",
		       "\x{2579} " ],
	},
	light_blockend => {
	    right => [ "\x{2584} ",
		       "\x{2502} ",
		       "\x{2580} " ],
	},
	heavy_blockend => {
	    right => [ "\x{2584} ",
		       "\x{2503} ",
		       "\x{2580} " ],
	},
	light_box => {
	    right  => [ "\x{250c}\x{2510}",
			"\x{2502}\x{2502}",
			"\x{2514}\x{2518}" ],
	},
	light_round_box => {
	    right => [ "\x{256D}\x{256E}",
		       "\x{2502}\x{2502}",
		       "\x{2570}\x{256F}" ],
	},
	light_double_box => {
	    right => [ "\x{2552}\x{2555}",
		       "\x{2502}\x{2502}",
		       "\x{2558}\x{255B}" ],
	},
	double_box => {
	    right => [ "╔╗" , # "\x{2554}\x{2557}"
		       "║║" , # "\x{2551}\x{2551}"
		       "╚╝" ] # "\x{255A}\x{255D}"
	},
	heavy_box => {
	    right => [ "┏┓" , # "\x{250F}\x{2513}"
		       "┃┃" , # "\x{2503}\x{2503}"
		       "┗┛" ] # "\x{2517}\x{251B}"
	},
	block_elements => {
	    right => [ "▗▖" , # "\x{2597}\x{2596}"
		       "▐▌" , # "\x{2590}\x{258C}"
		       "▝▘" ] # "\x{259D}\x{2598}"
	},
	block_elements_half => {
	    right => [ "▗ " , # "\x{2597} "
		       "▐ " , # "\x{2590} "
		       "▝ " ] # "\x{259D} "
	},
	star   => { right => [ "★ ", "☆ " ] },
	square => { right => [ "■ ", "□ " ] },
	pipe   => { right => [ "  ", "| " ] },
    }, $class;
    $obj->theme($theme);
    $obj;
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

sub get_by_theme {
    my $obj = shift;
    my $theme = shift;
    my $hash = $obj->{$theme} // return undef;
    my($place, $position, $page) = (shift, shift//0, shift//0);
    my $list = $hash->{$place} // return undef;
    @$list == 0 and return undef;
    my $target = ref $list->[0] ? $list->[$page / @$list] : $list;
    $target->[$position % @$target];
}

1;
