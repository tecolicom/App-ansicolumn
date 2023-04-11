package App::ansicolumn::default;

use v5.14;
use warnings;
use utf8;

App::ansicolumn::Border->add_style(
    star   => { center => [ "★ ", "☆ " ] },
    square => { center => [ "■ ", "□ " ] },
    );

1;

__DATA__

option --color-board --bs=inner-box --cm=BORDER=$<2>,TEXT=$<shift>/$<shift>

option --white-board --color-board 000 L24
option --black-board --color-board 555 L05
option --green-board --color-board 555 (30,77,43)
option --slate-board --color-board 555 <dark_slategray>
