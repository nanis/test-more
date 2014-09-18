package Test::Stream::Config;
use strict;
use warnings;

use Test::Stream::Threads;
use Test::Stream::Exporter;
use Test::Stream::ArrayBase;
exports qw/stream_config/;

our %DEFAULTS;

BEGIN {
    %DEFAULTS = (
        enable_fork            => (USE_THREADS ? 1 : 0),
        encoding               => 'legacy',
        modern                 => 0,
        subtest_delay          => 0,
        subtest_immediate      => 1,
        use_legacy             => 0, # Overridden by Test::Builder when loaded
        use_numbers            => 1,
        use_tap                => 1,
        verbose_diag_to_stdout => 0,
    );

    accessors sort keys %DEFAULTS;

    Test::Stream::ArrayBase->cleanup;
}

my $GLOBAL = load_config();
sub stream_config { $GLOBAL }

sub load_config {
    shift if @_ && $_[0] eq __PACKAGE__;
    my ($file) = @_;
    $file ||= 'test_stream.config';
    unless(-e $file) {
        return unless $0 =~ m{^(.*)/t/};
        $file = "$1/$file";
        return unless -e $file;
    }

    my %out;
    open(my $fh, '<', $file) || die "Could not open config file '$file': $!\n";
    my $ln = 0;
    while(my $line = <$fh>) {
        $ln++;
        chomp($line);
        next if $line =~ m/^\s*#/;
        next if $line =~ m/^\s*$/;
        my ($key, $val, $cmt) = $line =~ m/^\s*(\S+)\s*:\s*(\S+)\s*(#.*)?$/g;
        $cmt ||= '';

        # Make sure the line is somewhat valid with a key and a value
        die "invalid line in test configuration at $file line $ln:\n    $line\n" unless $key && defined $val;

        # Make sure the key is valid (found in defaults);
        die "invalid key '$key' in test configuration at $file line $ln\n" unless exists $DEFAULTS{$key};

        # Make sure the value is the same type as the default (if the default
        # has only numeric characters, then the config file must also have only
        # numeric characters.
        die "invalid value '$val' (must be numeric) in test configuration at $file line $ln\n"
            if $val =~ m/\D/ && $DEFAULTS{$key} !~ m/\D/;

        die "key '$key' listed again in test configuration at $file line $ln\n"
            if exists $out{$key};

        $out{$key} = $val;
    }
    close($fh);

    return __PACKAGE__->new_from_pairs(%DEFAULTS, %out);
}

1;
