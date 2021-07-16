package Getopt::EX::Hashed;

=head1 NAME

Getopt::EX::Hashed - Hash store object automation

=head1 SYNOPSIS

  use Foo;
  Foo->new->run();

  package Foo;
  use Getopt::EX::Hashed;
  has start => ( spec => "=i s begin", default => 1 );
  has end   => ( spec => "=i e" );
  no Getopt::EX::Hashed;

  sub run {
      my $obj = shift;
      $obj->getopt or pod2usage();
      if ($obj->{start}) {
          ...

=head1 DESCRIPTION

This is an experimental module to automate an hash object to store
option values.  Using Getopt::Long is assumed in this implementation.
Major objective of this module is to integrate initialization and
specification into single place.

Declare option parameters in a form of:

    has option_name => ( param => value, ... );

If array reference is given, multiple names can declared at once.

    has [ 'left', 'right' ] => ( param => value, ... );

If the name start with plus (C<+>), given parameters are added to
current value.

    has '+left' => ( default => 1 );

There are following parameters:

=over 7

=item B<spec> => I<string>

Give option specification.  Option spec and alias names are separated
by white space, and can show up in any order.

Declaration

    has start => ( spec => ":i s begin" );

will be compiled into string:

    start|s|begin:i

which conform to C<Getopt::Long> definition.  Of course, you can write
this as this:

    has start => ( spec => "s|begin:i" );

If the name and aliases contain underscore (C<_>), another alias name
is defined with dash (C<->) in place of underscores.  So

    has a_to_z => ( spec => ":s" );

will be compiled into:

    a_to_z|a-to-z:s

If nothing special is necessary, give empty (or white space only)
string as a value.  Otherwise, it is not concidered as an option.

=item B<default> => I<value>

Set default value.  If no default is given, the member is initialized
as C<undef>.

Code reference can be specified, but if you want to access hash object
in the code, use next B<action> parameter.

=item B<action> => I<coderef>

Because hash object does not exist at the time of declaration, it is
impossible to access it.  So B<action> parameter takes a code
reference to receive the object and produce new code reference.

    has [ qw(left right both) ] => spec => ':i';
    has "+both" => action => sub {
        my $obj = shift;
        sub {
            $obj->{left} = $obj->{right} = $_[1];
        }
    } ;

This function is called at the time of C<new>.  You can use this for
C<< "<>" >> too.

    has ARGV => default => [];
    has "<>" => spec => '', action => sub {
        my $obj = shift;
        sub {
            push @{$obj->{ARGV}}, $_[0];
        };
    };

=back

=head1 METHOD

=over 7

=item B<new>

Return initialized hash object.

=item B<getopt>

Call C<GetOptions> function defined in caller's context with
appropriate parameters.

    $obj->getopt

is just a shortcut for:

    Getoptions($obj, $obj->optspec)

=item B<optspec>

Return option specification list which can be given to C<GetOptions>
function with the hash object.

=item B<use_keys>

Because hash keys are protected by C<Hash::Util::lock_keys>, accessing
non-existing member causes an error.  Use this function to declare new
member key before use.

    $obj->use_keys( qw(foo bar) );

If you want to access arbitrary keys, unlock the object.

    use Hash::Util 'unlock_keys';
    unlock_keys %{$obj};

=back

=head1 SEE ALSO

L<Getopt::Long>

L<Getopt::EX>

=head1 AUTHOR

Kazumasa Utashiro

=head1 COPYRIGHT

The following copyright notice applies to all the files provided in
this distribution, including binary files, unless explicitly noted
otherwise.

Copyright 2021 Kazumasa Utashiro

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use v5.14;
use warnings;
use Hash::Util qw(lock_keys lock_keys_plus unlock_keys);
use Carp;
use Data::Dumper;

use Exporter 'import';
our @EXPORT = qw(has new optspec getopt use_keys);

my %Member;

our $LOCK_KEYS = 1;
our $REPLACE_UNDERSCORE = 1;

sub has {
    my($name, %param) = @_;
    my @name = ref $name eq 'ARRAY' ? @$name : $name;
    for (@name) {
	if (s/^\+//) {
	    $Member{$_} //= {};
	    $Member{$_} = { %{$Member{$_}}, %param };
	} else {
	    $Member{$_} = \%param;
	}
    }
}

sub new {
    my $class = shift;
    my $obj = bless {}, $class;
    for my $key (keys %Member) {
	my $member = $Member{$key};
	$obj->{$key} = do {
	    if (my $action = $member->{action}) {
		_action($obj, $action);
	    } else {
		$member->{default};
	    }
	};
    }
    lock_keys %{$obj} if $LOCK_KEYS;
    $obj;
}

sub _action {
    my($obj, $action) = @_;
    ref $action eq 'CODE'
	or die "action must be coderef.\n";
    my $sub = $action->($obj);
    ref $sub eq 'CODE'
	or die "action must return coderef.\n";
    $sub;
}

sub optspec {
    my $obj = shift;
    map  { _optspec($obj, @$_) }
    grep { defined $_->[1] }
    map  { [ $_ => $Member{$_}->{spec} ] }
    keys %Member;
}

my $spec_re = qr/[!+=:]/;

sub _optspec {
    my $obj = shift;
    my($name, $args) = @_;

    my @args = split ' ', $args;
    my @spec = grep /$spec_re/, @args;
    my $spec = do {
	if    (@spec == 0) { '' }
	elsif (@spec == 1) { $spec[0] }
	else               { die }
    };
    my @alias = grep !/$spec_re/, @args;
    my @names = ($name, @alias);
    if ($REPLACE_UNDERSCORE) {
	for ($name, @alias) {
	    push @names, tr[_][-]r if /_/;
	}
    }
    join('|', @names) . $spec;
}

sub getopt {
    my $obj = shift;
    my $caller = caller;
    no strict 'refs';
    &{"$caller\::GetOptions"}($obj, $obj->optspec);
}

sub use_keys {
    my $obj = shift;
    unlock_keys %{$obj};
    lock_keys_plus %{$obj}, @_;
}

1;
