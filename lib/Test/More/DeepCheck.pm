package Test::More::DeepCheck;
use strict;
use warnings;

use Carp qw/cluck/;
use Test::More::Tools;
use Scalar::Util qw/reftype/;

use Test::Stream::ArrayBase;
BEGIN {
    accessors qw/seen stack_start/;
    Test::Stream::ArrayBase->cleanup;
}

sub init {
    $_[0]->[SEEN] ||= [{}];
}

sub check {
    my $class = shift;
    my ($got, $expect) = @_;

    tmt->_unoverload_str(\$got, \$expect);
    my $self = $class->new();

    # neither is a reference
    return tmt->is_eq($got, $expect)
        if !ref $got and !ref $expect;

    # one's a reference, one isn't
    if (!ref $got xor !ref $expect) {
        push @$self => {vals => [$got, $expect], line => __LINE__};
        return (0, $self->format_stack);
    }

    my $ok = $self->_deep_check($got, $expect);
    return ($ok, $ok ? () : $self->format_stack);
}

sub check_array {
    my $class = shift;
    my ($got, $expect) = @_;
    my $self = $class->new();
    my $ok = $self->_deep_check($got, $expect);
    return ($ok, $ok ? () : $self->format_stack);
}

sub check_hash {
    my $class = shift;
    my ($got, $expect) = @_;
    my $self = $class->new();
    my $ok = $class->_deep_check($got, $expect);
    return ($ok, $ok ? () : $self->format_stack);
}

sub check_set {
    my $class = shift;
    my ($got, $expect) = @_;
    my $self = $class->new();

    return 0 unless @$got == @$expect;

    no warnings 'uninitialized';

    # It really doesn't matter how we sort them, as long as both arrays are
    # sorted with the same algorithm.
    #
    # Ensure that references are not accidentally treated the same as a
    # string containing the reference.
    #
    # Have to inline the sort routine due to a threading/sort bug.
    # See [rt.cpan.org 6782]
    #
    # I don't know how references would be sorted so we just don't sort
    # them.  This means eq_set doesn't really work with refs.
    return $self->check_array(
        [ grep( ref, @$got ),    sort( grep( !ref, @$got ) )    ],
        [ grep( ref, @$expect ), sort( grep( !ref, @$expect ) ) ],
    );
}

my $DNE = bless [], 'Does::Not::Exist';
sub _dne {ref $_[0] eq ref $DNE}

sub _deep_check {
    my $self = shift;
    my($e1, $e2) = @_;

    tmt->_unoverload_str( \$e1, \$e2 );

    # Either they're both references or both not.
    my $same_ref = !(!ref $e1 xor !ref $e2);
    my $not_ref  =  (!ref $e1 and !ref $e2);

    return 0 if  defined $e1 xor  defined $e2;
    return 1 if !defined $e1 and !defined $e2; # Shortcut if they're both undefined.
    return 0 if    _dne($e1) xor  _dne($e2);
    return 1 if  $same_ref   and ($e1 eq $e2);

    if ($not_ref) {
        push @$self => {type => '', vals => [$e1, $e2], line => __LINE__};
        return 0;
    }

    # This avoids picking up the same referenced used twice (such as
    # [\$a, \$a]) to be considered circular.
    my $seen = {%{$self->[SEEN]->[-1]}};
    push @{$self->[SEEN]} => $seen;
    my $ok = $self->_inner_check($seen, $e1, $e2);
    pop @{$self->[SEEN]};
    return $ok;
}

sub _inner_check {
    my $self = shift;
    my ($seen, $e1, $e2) = @_;

    return $seen->{$e1} if $seen->{$e1} && $seen->{$e1} eq $e2;
    $seen->{$e1} = "$e2";

    my $type1 = reftype($e1) || '';
    my $type2 = reftype($e2) || '';
    my $diff  = $type1 ne $type2;

    if ($diff) {
        push @$self => {type => 'DIFFERENT', vals => [$e1, $e2], line => __LINE__};
        return 0;
    }

    return $self->_check_array($e1, $e2) if $type1 eq 'ARRAY';
    return $self->_check_hash($e1, $e2)  if $type1 eq 'HASH';

    if ($type1 eq 'REF' || $type1 eq 'SCALAR') {
        push @$self => {type => 'REF', vals => [$e1, $e2], line => __LINE__};
        my $ok = _deep_check($$e1, $$e2);
        pop @$self if $ok;
        return $ok;
    }

    push @$self => {type => $type1, vals => [$e1, $e2], line => __LINE__};
    return 0;
}

sub _check_array {
    my $self = shift;
    my ($a1, $a2) = @_;

    if (grep reftype($_) ne 'ARRAY', $a1, $a2) {
        cluck "_check_array passed a non-array ref";
        return 0;
    }

    return 1 if $a1 eq $a2;

    my $ok = 1;
    my $max = $#$a1 > $#$a2 ? $#$a1 : $#$a2;
    for (0 .. $max) {
        my $e1 = $_ > $#$a1 ? $DNE : $a1->[$_];
        my $e2 = $_ > $#$a2 ? $DNE : $a2->[$_];

        next if $self->_check_nonrefs($e1, $e2);

        push @$self => {type => 'ARRAY', idx => $_, vals => [$e1, $e2], line => __LINE__};
        $ok = $self->_deep_check($e1, $e2);
        pop @$self if $ok;

        last unless $ok;
    }

    return $ok;
}

sub _check_nonrefs {
    my $self = shift;
    my($e1, $e2) = @_;

    return if ref $e1 or ref $e2;

    if (defined $e1) {
        return 1 if defined $e2 and $e1 eq $e2;
    }
    else {
        return 1 if !defined $e2;
    }

    return 0;
}

sub _check_hash {
    my $self = shift;
    my ($a1, $a2) = @_;

    if (grep {(reftype($_) || '') ne 'HASH' } $a1, $a2) {
        cluck "_check_hash passed a non-hash ref";
        return 0;
    }

    return 1 if $a1 eq $a2;

    my $ok = 1;
    my $bigger = keys %$a1 > keys %$a2 ? $a1 : $a2;
    foreach my $k (keys %$bigger) {
        my $e1 = exists $a1->{$k} ? $a1->{$k} : $DNE;
        my $e2 = exists $a2->{$k} ? $a2->{$k} : $DNE;

        next if $self->_check_nonrefs($e1, $e2);

        push @$self => {type => 'HASH', idx => $k, vals => [$e1, $e2], line => __LINE__};
        $ok = $self->_deep_check($e1, $e2);
        pop @$self if $ok;

        last unless $ok;
    }

    return $ok;
}

sub format_stack {
    my $self = shift;
    my ($seen, @Stack) = @$self;

    my $var       = '$FOO';
    my $did_arrow = 0;
    for my $entry (@Stack) {
        my $type = $entry->{type} || '';
        my $idx = $entry->{'idx'};
        if ($type eq 'HASH') {
            $var .= "->" unless $did_arrow++;
            $var .= "{$idx}";
        }
        elsif ($type eq 'ARRAY') {
            $var .= "->" unless $did_arrow++;
            $var .= "[$idx]";
        }
        elsif ($type eq 'REF') {
            $var = "\${$var}";
        }
    }

    my @vals = @{$Stack[-1]{vals}}[0, 1];
    my @vars = ();
    ($vars[0] = $var) =~ s/\$FOO/     \$got/;
    ($vars[1] = $var) =~ s/\$FOO/\$expected/;

    my $out = "Structures begin differing at:\n";
    for my $idx (0 .. $#vals) {
        my $val = $vals[$idx];
        $vals[$idx] =
              !defined $val ? 'undef'
            : _dne($val)    ? "Does not exist"
            : ref $val      ? "$val"
            :                 "'$val'";
    }

    $out .= "$vars[0] = $vals[0]\n";
    $out .= "$vars[1] = $vals[1]\n";

    $out =~ s/^/    /msg;
    return $out;
}

1;
