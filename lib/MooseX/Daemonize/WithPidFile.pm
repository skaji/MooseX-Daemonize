package MooseX::Daemonize::WithPidFile;
use strict;
use Moose::Role;

use MooseX::Daemonize::Pid::File;

our $VERSION = 0.01;

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

1;

__END__

=pod

=cut