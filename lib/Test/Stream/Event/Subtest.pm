package Test::Stream::Event::Subtest;
use strict;
use warnings;

use Test::Stream::Event::Ok;
use Test::Stream::Event 'Test::Stream::Event::Ok';
use Test::Stream;
use Scalar::Util qw/blessed/;

BEGIN {
    accessors qw/state events error/;
    Test::Stream::Event->cleanup;
};

use Test::Stream::Carp qw/confess/;

sub init {
    my $self = shift;

    $self->[REAL_BOOL] = $self->[STATE]->[STATE_PASSING] && $self->[STATE]->[STATE_COUNT];
    $self->[EVENTS] ||= [];

    if (my $err = $self->[ERROR]) {
        if (blessed($err) && $err->isa('Test::Stream::Event::Plan')) {
            # Should be a snapshot now:
            my $skip = 'all';
            $skip .= ": " . $err->reason if $err->reason;
            $self->[CONTEXT]->set_skip($skip);
            $self->[REAL_BOOL] = 1;
        }
    }

    $self->SUPER::init();
}

sub to_tap {
    my $self = shift;
    my ($num, $format) = @_;

    my %parts;
    if ($format eq 'legacy') {
        my $note = Test::Stream::Event::Note->new($self->[CONTEXT], $self->[CREATED], "Subtest: " . $self->[NAME]);
        my ($h, $msg) = $note->to_tap(@_);
        push @{$parts{$h}} => $msg;

        $self->render_events($num, $format, \%parts);

        ($h, $msg) = $self->SUPER::to_tap(@_);
        push @{$parts{$h}} => $msg;
    }
    elsif ($format eq 'modern') {
        my ($h, $msg) = $self->SUPER::to_tap(@_);
        push @{$parts{$h}} => $msg;

        $self->render_events($num, $format, \%parts);

        push @{$parts{$h}} => "    # end\n";
    }

    map {($_ => join("" => @{$parts{$_}}))} keys %parts;
}

sub render_events {
    my $self = shift;
    my ($num, $format, $parts) = @_;

    my $idx = 1;
    for my $e (@{$self->[EVENTS]}) {
        my $isa_ok = $e->isa('Test::Stream::Event::Ok');
        my $isa_st = $e->isa('Test::Stream::Event::Subtest');
        $idx++ if $isa_ok;
        my @events = ($e);
        push @events => @{$e->diag} if $isa_ok && !$isa_st && $e->diag;
        for my $se (@events) {
            my %sets = $se->to_tap($idx, $format);
            for (my ($h, $msg) = each %sets) {
                $msg =~ s/^/    /mg;
                push @{$parts->{$h}} => $msg;
            }
        }
    }
}

1;

__END__

=head1 NAME

Test::Stream::Event::Subtest;

=head1 DESCRIPTION

The Subtest event type.

=head1 METHODS

See L<Test::Stream::Event> which is the base class for this module.

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 SOURCE

The source code repository for Test::More can be found at
F<http://github.com/Test-More/test-more/>.

=head1 COPYRIGHT

Copyright 2014 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>
