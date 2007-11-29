package MooseX::Daemonize::SignalHandling;
use strict;    # because Kwalitee is pedantic
use Moose::Role;

our $VERSION = 0.01;

# NOTE:
# this would be an excellent canidate for
# a parameterized role, since we would want
# to have the ability to specify which 
# signals we want handled

requires 'handle_signal';

sub setup_signals {
    my $self = shift;
    foreach my $signal (qw[ INT HUP ]) {
        $SIG{$signal}  = sub { $self->handle_signal($signal) };
    }
}

1;

__END__

=pod

=cut