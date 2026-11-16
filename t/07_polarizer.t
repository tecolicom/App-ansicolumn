use v5.14;
use warnings;
use utf8;
use Test::More 0.98;
use File::Spec;
use File::Temp qw(tempdir);

BEGIN {
    eval { require IO::Polarizer; 1 }
	or plan skip_all => 'IO::Polarizer is not installed';
}

# do not read the rc file of the user
$ENV{HOME} = File::Spec->rel2abs('t/home');

my $dir = tempdir(CLEANUP => 1);
for (['f1', "one\ntwo\n"], ['f2', "three\n"], ['j1', "あいう\n"]) {
    my($name, $text) = @$_;
    open my $fh, '>:utf8', "$dir/$name" or die;
    print $fh $text;
    close $fh;
}

# ansicolumn with IO::Polarizer loaded, and a converter for every file
# which makes the text upper case
my $script = "$dir/ac.pl";
{
    open my $fh, '>', $script or die;
    print $fh <<'END';
use IO::Polarizer;
IO::Polarizer::register(match => qr/./, command => ['perl', '-pe', '$_ = uc']);
use App::ansicolumn qw(ansicolumn);
exit ansicolumn(@ARGV);
END
    close $fh;
}

sub ac {
    my $args = join ' ', @_;
    my $out = qx{cd "$dir" && $^X -I"$ENV{PWD}/lib" ac.pl $args 2>&1};
    utf8::decode($out);
    $out =~ s/ +$//mgr;
}

subtest 'polarizer: converted' => sub {
    is ac(qw(-C1 f1)), "ONE\nTWO\n", 'one file';
    like ac(qw(-V f1 f2)), qr/ONE.*THREE.*\n.*TWO/, 'parallel';
};

subtest 'polarizer: header keeps the name' => sub {
    my $out = ac(qw(-V --filename f1 f2));
    like $out, qr/: f1 +: f2/, 'file names';
    unlike $out, qr{/dev/fd/}, 'no path of the temporary file';
    like $out, qr/ONE.*THREE/, 'converted';
};

subtest 'polarizer: wide characters' => sub {
    is ac(qw(-C1 j1)), "あいう\n", 'decoded as UTF-8';
};

subtest 'polarizer: stdin' => sub {
    my $out = qx{cd "$dir" && $^X -I"$ENV{PWD}/lib" ac.pl -C1 < f2 2>&1};
    is $out =~ s/ +$//mgr, "three\n", 'not converted';
};

subtest 'polarizer: missing file' => sub {
    my $out = ac(qw(-C1 none));
    like $out, qr/^none: No such file or directory/, 'error message';
};

# --polarizer loads IO::Polarizer and the converter of the name: here
# IO::Polarizer::upper, a module made for the test
{
    mkdir "$dir/lib" and mkdir "$dir/lib/IO" and mkdir "$dir/lib/IO/Polarizer" or die;
    open my $fh, '>', "$dir/lib/IO/Polarizer/upper.pm" or die;
    print $fh <<'END';
package IO::Polarizer::upper;
use IO::Polarizer;
sub setup {
    IO::Polarizer::register(match => qr/^f\d$/, command => ['perl', '-pe', '$_ = uc']);
}
1;
END
    close $fh;
}

sub ac_option {
    my $args = join ' ', @_;
    my $script = File::Spec->rel2abs('script/ansicolumn');
    my $out = qx{cd "$dir" && $^X -I"$ENV{PWD}/lib" -I"$dir/lib" "$script" $args 2>&1};
    utf8::decode($out);
    $out =~ s/ +$//mgr;
}

subtest '--polarizer' => sub {
    is ac_option(qw(-C1 f1)), "one\ntwo\n", 'not converted without it';
    is ac_option(qw(--polarizer=upper -C1 f1)), "ONE\nTWO\n", 'converted';
    is ac_option(qw(-C1 f1 --polarizer upper)), "ONE\nTWO\n", 'after the file';
    my $out = ac_option(qw(--polarizer=upper -V --filename f1 j1));
    like $out, qr/: f1 +: j1/, 'file names';
    like $out, qr/ONE.*あいう/, 'only the files of the converter';
    like ac_option(qw(--polarizer=nosuch -C1 f1)), qr/nosuch: no such converter/,
	'unknown name';
};

done_testing;

