use v5.14;
use warnings;
use utf8;
use Test::More 0.98;
use File::Spec;
use File::Temp qw(tempdir);

BEGIN {
    eval { require IO::Factotum; 1 }
	or plan skip_all => 'IO::Factotum is not installed';
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

# ansicolumn with IO::Factotum loaded, and a converter for every file
# which makes the text upper case
my $script = "$dir/ac.pl";
{
    open my $fh, '>', $script or die;
    print $fh <<'END';
use IO::Factotum;
IO::Factotum::register(match => qr/./, command => ['perl', '-pe', '$_ = uc']);
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

subtest 'factotum: converted' => sub {
    is ac(qw(-C1 f1)), "ONE\nTWO\n", 'one file';
    like ac(qw(-V f1 f2)), qr/ONE.*THREE.*\n.*TWO/, 'parallel';
};

subtest 'factotum: header keeps the name' => sub {
    my $out = ac(qw(-V --filename f1 f2));
    like $out, qr/: f1 +: f2/, 'file names';
    unlike $out, qr{/dev/fd/}, 'no path of the temporary file';
    like $out, qr/ONE.*THREE/, 'converted';
};

subtest 'factotum: wide characters' => sub {
    is ac(qw(-C1 j1)), "あいう\n", 'decoded as UTF-8';
};

subtest 'factotum: stdin' => sub {
    my $out = qx{cd "$dir" && $^X -I"$ENV{PWD}/lib" ac.pl -C1 < f2 2>&1};
    is $out =~ s/ +$//mgr, "three\n", 'not converted';
};

subtest 'factotum: missing file' => sub {
    my $out = ac(qw(-C1 none));
    like $out, qr/^none: No such file or directory/, 'error message';
};

# --factotum loads IO::Factotum and the converter of the name: here
# IO::Factotum::upper, a module made for the test
{
    mkdir "$dir/lib" and mkdir "$dir/lib/IO" and mkdir "$dir/lib/IO/Factotum" or die;
    open my $fh, '>', "$dir/lib/IO/Factotum/upper.pm" or die;
    print $fh <<'END';
package IO::Factotum::upper;
use IO::Factotum;
sub setup {
    IO::Factotum::register(match => qr/^f\d$/, command => ['perl', '-pe', '$_ = uc']);
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

subtest '--factotum' => sub {
    is ac_option(qw(-C1 f1)), "one\ntwo\n", 'not converted without it';
    is ac_option(qw(--factotum=upper -C1 f1)), "ONE\nTWO\n", 'converted';
    is ac_option(qw(-C1 f1 --factotum upper)), "ONE\nTWO\n", 'after the file';
    my $out = ac_option(qw(--factotum=upper -V --filename f1 j1));
    like $out, qr/: f1 +: j1/, 'file names';
    like $out, qr/ONE.*あいう/, 'only the files of the converter';
    like ac_option(qw(--factotum=nosuch -C1 f1)), qr/nosuch: no such converter/,
	'unknown name';
};

# --highlight and --hilite are --factotum=skylighting: here with a
# module of that name made for the test, found before the real one
subtest '--highlight' => sub {
    open my $fh, '>', "$dir/lib/IO/Factotum/skylighting.pm" or die;
    print $fh <<'END';
package IO::Factotum::skylighting;
use IO::Factotum;
sub setup {
    IO::Factotum::register(match => qr/^f\d$/, command => ['perl', '-pe', '$_ = "<$_"']);
}
1;
END
    close $fh;
    is ac_option(qw(--highlight -C1 f1)), "<one\n<two\n", '--highlight';
    is ac_option(qw(--hilite -C1 f1)), "<one\n<two\n", '--hilite';
    is ac_option(qw(-C1 f1 --highlight)), "<one\n<two\n", 'after the file';
};

done_testing;


