package MooseX::Daemonize::WithPidFile;
use strict;
use Moose::Role;

use MooseX::Daemonize::Pid::File;

our $VERSION = 0.01;

with 'MooseX::Daemonize::Core';

requires 'init_pidfile';

has pidfile => (
    isa       => 'MooseX::Daemonize::Pid::File',
    is        => 'rw',
    lazy      => 1,
    required  => 1,
    coerce    => 1,
    predicate => 'has_pidfile',
    builder   => 'init_pidfile',
);

after 'daemonize' => sub {
    # NOTE:
    # make sure that we do not have 
    # any bad PID values stashed around
    # - SL
    (shift)->pidfile->clear_pid
};

1;

__END__

=pod

=cut