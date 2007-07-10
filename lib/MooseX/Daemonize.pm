package MooseX::Daemonize;
use strict;    # because Kwalitee is pedantic
use Moose::Role;

our $VERSION = 0.01;
use Carp;
use Proc::Daemon;

use File::Flock;
use File::Slurp;

with qw(MooseX::Getopt);

has progname => (
    isa      => 'Str',
    is       => 'ro',
    lazy     => 1,
    required => 1,
    default  => sub {
        ( my $name = lc $_[0]->meta->name ) =~ s/::/_/g;
        return $name;
    },
);

has basedir => (
    isa     => 'Str',
    is      => 'ro',
    lazy    => 1,
    default => sub { return '/' },
);

has pidbase => (
    isa => 'Str',
    is  => 'ro',

    #    required => 1,
    lazy    => 1,
    default => sub { return '/var/run' },
);

has pidfile => (
    isa      => 'Str',
    is       => 'ro',
    lazy     => 1,
    required => 1,
    default  => sub {
        die 'Cannot write to ' . $_[0]->pidbase unless -w $_[0]->pidbase;
        $_[0]->pidbase . '/' . $_[0]->progname . '.pid';
    },
);

has foreground => (
    metaclass   => 'Getopt',
    cmd_aliases => ['f'],
    isa         => 'Bool',
    is          => 'ro',
    default     => sub { 0 },
);

sub check {
    my ($self) = @_;
    if ( my $pid = $self->get_pid ) {
        my $prog = $self->progname;
        if ( CORE::kill 0 => $pid ) {
            croak "$prog already running ($pid).";
        }
        carp "$prog not running but found pid ($pid)."
          . "Perhaps the pid file (@{ [$self->pidfile] }) is stale?";
        return 1;
    }
    return 0;
}

sub daemonize {
    my ($self) = @_;
    Proc::Daemon::Init;
}

sub start {
    my ($self) = @_;
    return if $self->check;

    $self->daemonize unless $self->foreground;

    # Avoid 'stdin reopened for output' warning with newer perls
    ## no critic
    open( NULL, '/dev/null' );
    <NULL> if (0);
    ## use critic
    
    # Change to basedir
    chdir $self->basedir;
    
    $self->save_pid;
    $self->setup_signals;
    return $$;
}

sub save_pid {
    my ($self) = @_;
    my $pidfile = $self->pidfile;
    lock( $pidfile, undef, 'nonblocking' )
      or croak "Could not lock PID file $pidfile: $!";
    write_file( $pidfile, "$$\n" );
    unlock($pidfile);
    return;
}

sub remove_pid {
    my ($self) = @_;
    my $pidfile = $self->pidfile;
    lock( $pidfile, undef, 'nonblocking' )
      or croak "Could not lock PID file $pidfile: $!";
    unlink($pidfile);
    unlock($pidfile);
    return;
}

sub get_pid {
    my ($self) = @_;
    my $pidfile = $self->pidfile;
    return unless -e $pidfile;
    chomp( my $pid = read_file($pidfile) );
    return $pid;
}

sub stop {
    my ( $self, %args ) = @_;
    my $pid = $self->get_pid;
    $self->_kill($pid) unless $self->foreground();
    $self->remove_pid;
    return 1 if $args{no_exit};
    exit;
}

sub restart {
    my ($self) = @_;
    $self->stop( noexit => 1 );
    $self->start();
}

sub setup_signals {
    my ($self) = @_;
    $SIG{INT} = sub { $self->handle_sigint; };
    $SIG{HUP} = sub { $self->handle_sighup };
}

sub handle_sigint { $_[0]->stop; }
sub handle_sighup { $_[0]->restart; }

sub _kill {
    confess "_kill isn't public" unless caller eq __PACKAGE__;
    my ( $self, $pid ) = @_;
    return unless $pid;
    unless ( CORE::kill 0 => $pid ) {

        # warn "$pid already appears dead.";
        return;
    }

    if ( $pid eq $$ ) {

        # warn "$pid is us! Can't commit suicied.";
        return;
    }

    CORE::kill( 2, $pid );    # Try SIGINT
    sleep(2) if CORE::kill( 0, $pid );

    unless ( CORE::kill 0 => $pid or $!{EPERM} ) {    # IF it is still running
        CORE::kill( 15, $pid );                       # try SIGTERM
        sleep(2) if CORE::kill( 0, $pid );
    }

    unless ( CORE::kill 0 => $pid or $!{EPERM} ) {    # IF it is still running
        CORE::kill( 9, $pid );                        # finally try SIGKILL
        sleep(2) if CORE::kill( 0, $pid );
    }

    unless ( CORE::kill 0 => $pid or $!{EPERM} ) {    # IF it is still running
        carp "$pid doesn't seem to want to die.";     # AHH EVIL DEAD!
    }

    return;
}

1;
__END__

=head1 NAME

MooseX::Daemonize - provides a Role that daemonizes your Moose based application.


=head1 VERSION

This document describes MooseX::Daemonize version 0.0.1


=head1 SYNOPSIS

    package FileMaker;
    use Moose;
    with qw(MooseX::Daemonize);

    sub create_file {
        my ( $self, $file ) = @_;
        open( FILE, ">$file" ) || die;
        close(FILE);
    }

    no Moose;

    # then in the main package ... 
    
    my $daemon = FileMaker->new();
    $daemon->start();
    $daemon->create_file($file);
    $daemon->stop();
     
=head1 DESCRIPTION

Often you want to write a persistant daemon that has a pid file, and responds appropriately to Signals. 
This module helps provide the basic infrastructure to do that.

=head1 ATTRIBUTES

=over

=item progname Str

The name of our daemon, defaults to $0

=item pidbase Str

The base for our bid, defaults to /var/run/$progname

=item pidfile Str

The file we store our PID in, defaults to /var/run/$progname/ 

=item foreground Bool

If true, the process won't background. Useful for debugging. This option can be set via Getopt's -f.

=back

=head1 METHODS 

=over

=item check()

Check to see if an instance is already running.

=item start()

Setup a pidfile, fork, then setup the signal handlers.

=item stop()

Stop the process matching the pidfile, and unlinks the pidfile.

=item restart()

Litterally 

    $self->stop();
    $self->start();

=item daemonize()

Calls C<Proc::Daemon::Init> to daemonize this process. 

=item kill($pid)

Kills the process for $pid. This will try SIGINT, and SIGTERM before falling back to SIGKILL and finally giving up.

=item setup_signals()

Setup the signal handlers, by default it only sets up handlers for SIGINT and SIGHUP

=item handle_sigint()

Handle a INT signal, by default calls C<$self->stop()>

=item handle_sighup()

Handle a HUP signal. By default calls C<$self->restart()>

=item get_pid

Lookup the pid from our pidfile.

=item save_pid

Save the current pid in our pidfile

=item remove_pid

Delete our pidfile

=item meta()

The C<meta()> method from L<Class::MOP::Class>

=back

=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

Obviously L<Moose>, also L<Carp>, L<Proc::Daemon>, L<File::Flock>, L<File::Slurp>

=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-acme-dahut-call@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 SEE ALSO

L<Proc::Daemon>, L<Daemon::Generic>, L<MooseX::Getopt>

=head1 AUTHOR

Chris Prather  C<< <perigrin@cpan.org> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Chris Prather C<< <perigrin@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
