use v5.14;
use warnings;
use utf8;
use Test::More 0.98;
use File::Spec;
use File::Temp qw(tempdir);

BEGIN {
    eval { require Text::ANSI::Highlight::IO; 1 }
	or plan skip_all => 'Text::ANSI::Highlight::IO is not installed';
}

# do not read the rc file of the user
$ENV{HOME} = File::Spec->rel2abs('t/home');

my $dir = tempdir(CLEANUP => 1);
for (['f1', "one\ntwo\n"], ['f2', "three\n"], ['j1', "あいう\n"], ['plain', "text\n"]) {
    my($name, $text) = @$_;
    open my $fh, '>:utf8', "$dir/$name" or die;
    print $fh $text;
    close $fh;
}

# --highlight[=NAME] (--hi) shows the files in the colors of the
# highlighter of Text::ANSI::Highlight, pandoc by default:
# Text::ANSI::Highlight::IO gives it to IO::Factotum, through which
# the files are read.
# --no-highlight (--no-hi) turns it off.  Here the highlighters are
# modules made for the test, found before the real ones: they know
# the files of the names f1, f2 and j1, and put a color on each line.
{
    my $path = "$dir/lib/Text/ANSI/Highlight";
    require File::Path;
    File::Path::make_path($path);
    for (['pandoc', 31], ['sourcehighlight', 32]) {
	my($name, $color) = @$_;
	open my $fh, '>', "$path/$name.pm" or die;
	print $fh <<"END";
package Text::ANSI::Highlight::$name;
sub language { \$_[0] =~ /^(?:[fj]\\d|x)\$/ ? q(x) : undef }
sub markdown { 0 }
sub highlight { map { \$_->[1] =~ s/^(.+)\$/\\e[${color}m\$1\\e[0m/mgr } \@_ }
1;
END
	close $fh;
    }
}

sub ac {
    my $args = join ' ', @_;
    my $script = File::Spec->rel2abs('script/ansicolumn');
    my $out = qx{cd "$dir" && $^X -I"$ENV{PWD}/lib" -I"$dir/lib" "$script" $args 2>&1};
    utf8::decode($out);
    $out =~ s/ +$//mgr;
}

my $c = sub { my $n = shift; join '', map { "\e[${n}m$_\e[0m\n" } @_ };
my($pan, $gnu, $none) = ($c->(31, qw(one two)), $c->(32, qw(one two)), "one\ntwo\n");

subtest '--highlight' => sub {
    is ac(qw(-C1 f1)), $none, 'not colored without it';
    is ac(qw(--highlight -C1 f1)), $pan, '--highlight';
    is ac(qw(--hi -C1 f1)), $pan, '--hi';
    is ac(qw(-C1 f1 --highlight)), $pan, 'after the file';
    is ac(qw(--highlight=pandoc -C1 f1)), $pan, '--highlight=pandoc';
    is ac(qw(--highlight=sourcehighlight -C1 f1)), $gnu, '--highlight=sourcehighlight';
    is ac(qw(--highlight=gnu -C1 f1)), $gnu, '--highlight=gnu';
    is ac(qw(--hi=gnu -C1 f1)), $gnu, '--hi=gnu';
    is ac(qw(--no-highlight -C1 f1)), $none, '--no-highlight';
    is ac(qw(--no-hi -C1 f1)), $none, '--no-hi';
    is ac(qw(--hi --no-hi -C1 f1)), $none, '--no-hi after --hi';
    is ac(qw(--hi=gnu --no-hi -C1 f1)), $none, '--no-hi after --hi=gnu';
    is ac(qw(--no-hi --hi=gnu -C1 f1)), $gnu, '--hi=gnu after --no-hi';
    is ac(qw(--hi=gnu --hi -C1 f1)), $pan, '--hi after --hi=gnu';
    like ac(qw(--hi=nosuch -C1 f1)), qr/nosuch: no such highlighter/, 'unknown name';
};

subtest 'files' => sub {
    is ac(qw(--hi -C1 plain)), "text\n", 'a file which is not colored is as it is';
    is ac(qw(--hi -C1 j1)), $c->(31, 'あいう'), 'wide characters';
    like ac(qw(--hi -C1 nosuchfile)), qr/nosuchfile: /, 'a file which is not there';
    is ac("--hi -C1 - < f1"), $none, 'the standard input is as it is';
    my $out = ac(qw(--hi -V --filename --no-border f1 plain));
    like $out, qr/^: f1\s+: plain$/m, q(the names of the files are not changed);
    like $out, qr/\e\[31mone\e\[0m\s+text/, 'colored and not, side by side';
};

# The value is optional, and a file after the option is not taken for
# the name of a highlighter
subtest 'optional value' => sub {
    is ac(qw(--hi f1 -C1)), $pan, '--hi FILE';
    is ac(qw(-C1 --hi gnu f1)), $gnu, '--hi NAME FILE';
    is ac(qw(-C1 --hi pandoc f1)), $pan, '--hi pandoc FILE';
    like ac(qw(-V --no-border --hi f1 f2)), qr/\e\[31mone\e\[0m\s+\e\[31mthree/, '--hi FILE FILE';
    like ac(qw(-V --no-border f1 --hi f2)), qr/\e\[31mone\e\[0m\s+\e\[31mthree/,
	'FILE --hi FILE keeps the order';
};

done_testing;
