package Test::Stream::Event;
use strict;
use warnings;

use Carp qw/confess croak/;

use Test::Stream::ArrayBase;
BEGIN {
    accessors qw/context created/;
    Test::Stream::ArrayBase->cleanup;
};

# Haha, grody
sub cleanup {
    shift   @_;
    unshift @_ => 'Test::Stream::ArrayBase';
    goto &Test::Stream::ArrayBase::cleanup;
}

sub import {
    my $class = shift;
    my $caller = caller;

    # Cannot load it ourselves as that would cause a cycle
    croak "Test::Stream::Context does not appear to be loaded yet!"
        unless Test::Stream::Context->can('register_event');

    # @ISA must be set before we load ArrayBase
    { no strict 'refs'; push @{"$caller\::ISA"} => $class }
    Test::Stream::ArrayBase->export_to($caller);
    Test::Stream::ArrayBase->after_import($caller);
    Test::Stream::Context->register_event($caller);
}

sub init {
    confess "No context provided!" unless $_[0]->[CONTEXT];
}

sub indent {
    my $self = shift;
    my $depth = $self->[CONTEXT]->depth || return '';
    return '    ' x $depth;
}

sub encoding { $_[0]->[CONTEXT]->encoding }

1;

__END__

=head1 NAME

Test::Stream::Event - Base class for events

=head1 DESCRIPTION

Base class for all event objects that get passed through
L<Test::Stream>.

=head1 METHODS

=head2 CONSTRUCTORS

=over 4

=item $r = $class->new(...)

Create a new instance

=back

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