package App::ansicolumn::Command;

use v5.14;
use warnings;
use utf8;
use Carp;
use Fcntl;
use IO::File;
use Data::Dumper;

sub new {
    my $class = shift;
    my $obj = bless {
        COMMAND => [],
        STDIN   => undef,
        DATA    => '',
    }, $class;
    $obj->command(@_) if @_;
    $obj;
}

sub command {
    my $obj = shift;
    if (@_) {
        $obj->{COMMAND} = [ @_ ];
        $obj;
    } else {
        @{$obj->{COMMAND}};
    }
}

sub setstdin {
    my $obj = shift;
    my $data = shift // return $obj;
    my $stdin = $obj->{STDIN} //= do {
        my $fh = new_tmpfile IO::File or die "new_tmpfile: $!\n";
        $fh->fcntl(F_SETFD, 0) or die "fcntl F_SETFD: $!\n";
        binmode $fh, ':encoding(utf8)';
        $fh;
    };
    $stdin->seek(0, 0)  or die "seek: $!\n";
    $stdin->truncate(0) or die "truncate: $!\n";
    $stdin->print($data);
    $stdin->seek(0, 0)  or die "seek: $!\n";
    $obj;
}

sub update {
    my $obj = shift;
    my @command = $obj->command;

    # Flatten if nested array
    @command = @{$command[0]} if @command == 1 && ref $command[0] eq 'ARRAY';

    my $code = ref $command[0] eq 'CODE' ? shift @command : undef;

    if ($code) {
        $obj->_update_code($code, @command);
    } else {
        $obj->_update_exec(@command);
    }

    $obj;
}

sub _update_code {
    my($obj, $code, @args) = @_;

    my $pid = (my $fh = IO::File->new)->open('-|') // die "open: $@\n";
    if ($pid == 0) {
        if (my $stdin = $obj->{STDIN}) {
            open STDIN, "<&=", $stdin->fileno or die "open: $!\n";
            binmode STDIN, ':encoding(utf8)';
        }
        $code->(@args);
        exit;
    }
    binmode $fh, ':encoding(utf8)';
    $obj->{DATA} = do { local $/; <$fh> };
}

sub _update_exec {
    my($obj, @command) = @_;

    my $pid = (my $fh = IO::File->new)->open('-|') // die "open: $@\n";
    if ($pid == 0) {
        if (my $stdin = $obj->{STDIN}) {
            open STDIN, "<&=", $stdin->fileno or die "open: $!\n";
            binmode STDIN, ':encoding(utf8)';
        }
        exec @command;
        die "exec: $@\n";
    }
    binmode $fh, ':encoding(utf8)';
    $obj->{DATA} = do { local $/; <$fh> };
}

sub data {
    my $obj = shift;
    if (@_) {
        $obj->{DATA} = shift;
        $obj;
    } else {
        $obj->{DATA};
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

App::ansicolumn::Command - App::cdif::Command compatible interface

=head1 SYNOPSIS

    use App::ansicolumn::Command;

    # With external command
    my $obj = App::ansicolumn::Command->new;
    my $result = $obj->command('ansicolumn', '-t')
                     ->setstdin($data)
                     ->update
                     ->data;

    # With code reference (no fork)
    use App::ansicolumn qw(ansicolumn);
    my $obj = App::ansicolumn::Command->new;
    my $result = $obj->command(\&ansicolumn, '-t')
                     ->setstdin($data)
                     ->update
                     ->data;

=head1 DESCRIPTION

This module provides an L<App::cdif::Command> compatible interface.

When a code reference is passed as the first element of the command,
it is called directly without forking a new process.  This is useful
when used with L<App::Greple::tee> module's discrete mode, where the
overhead of forking multiple processes can be significant.

=head1 METHODS

=over 4

=item B<new>()

Create a new App::ansicolumn::Command object.

=item B<command>(@args)

Set the command arguments.  If the first argument is a code reference,
it will be called directly without forking.

=item B<setstdin>($data)

Set the input data to be processed.

=item B<update>()

Execute the command or code reference.

=item B<data>()

Return the processed output.

=back

=head1 SEE ALSO

L<App::ansicolumn>, L<App::cdif::Command>, L<App::Greple::tee>

=head1 AUTHOR

Kazumasa Utashiro

=head1 LICENSE

Copyright 2020- Kazumasa Utashiro.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
