use v5.14;
use warnings;
use Test::More 0.98;

use lib './t';
use ac;

# do not read the rc file of the user
use File::Spec;
$ENV{HOME} = File::Spec->rel2abs('t/home');

# The values of --width, --height, --pane, --up and --pane-width are
# RPN expressions with the size of the terminal: a = before the value is
# taken away, as ansifold takes the expression, so -w=2/ is -w 2/.  The
# size of the terminal is not known here, so they are compared.

my $stdin = join '', map "$_\n", 1..100;

for (
    [ [ '-w=2/' ],         [ '-w', '2/' ] ],
    [ [ '--width==2/' ],   [ '--width=2/' ] ],
    [ [ '-c=40' ],         [ '-c', '40' ] ],
    [ [ '-S=2/' ],         [ '-S', '2/' ] ],
) {
    my($eq, $plain) = @$_;
    my $out = ac->new(@$plain)->exec($stdin);
    ok(length $out, "@$plain: output");
    is(ac->new(@$eq)->exec($stdin), $out, "@$eq is @$plain");
}

done_testing;
