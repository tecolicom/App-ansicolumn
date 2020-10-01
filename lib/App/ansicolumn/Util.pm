package App::ansicolumn::Util;

use v5.14;
use warnings;

use Exporter qw(import);
our @EXPORT = qw(&terminal_width &zip);

sub terminal_width {
    use Term::ReadKey;
    my $default = 80;
    my @size;
    if (open my $tty, ">", "/dev/tty") {
	# Term::ReadKey 2.31 on macOS 10.15 has a bug in argument handling
	# and the latest version 2.38 fails to install.
	# This code should work on both versions.
	@size = GetTerminalSize $tty, $tty;
    }
    $size[0] or $default;
}

sub zip {
    my @zipped;
    my @orig = map { [ @$_ ] } @_;
    while (my @l = grep { @$_ > 0 } @orig) {
	push @zipped, [ map { shift @$_ } @l ];
    }
    @zipped;
}

1;
