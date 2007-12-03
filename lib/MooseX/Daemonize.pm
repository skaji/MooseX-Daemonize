package MooseX::Daemonize;
use strict;    # because Kwalitee is pedantic
use Moose::Role;
use MooseX::Types::Path::Class;

our $VERSION = 0.05;

with qw[
    MooseX::Daemonize::WithPidFile    
    MooseX::Getopt
];

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

has pidbase => (
    isa      => 'Path::Class::Dir',
    is       => 'ro',
    coerce   => 1,
    required => 1,    
    lazy     => 1,
    default  => sub { Path::Class::Dir->new('var', 'run') },
);

has basedir => (
    isa      => 'Path::Class::Dir',
    is       => 'ro',
    coerce   => 1,
    required => 1,
    lazy     => 1,
    default  => sub { Path::Class::Dir->new('/') },
);

has foreground => (
    metaclass   => 'Getopt',
    cmd_aliases => 'f',
    isa         => 'Bool',
    is          => 'ro',
    default     => sub { 0 },
);

has stop_timeout => (
    isa     => 'Int',
    is      => 'rw',
    default => sub { 2 }
);

sub init_pidfile {
    my $self = shift;
    my $file = $self->pidbase . '/' . $self->progname . '.pid';
    confess "Cannot write to $file" unless (-e $file ? -w $file : -w $self->pidbase);
    MooseX::Daemonize::Pid::File->new( file => $file );
}

sub start {
    my ($self) = @_;
    
    confess "instance already running" if $self->pidfile->is_running;
    
    $self->daemonize unless $self->foreground;
    
    return unless $self->is_daemon;

    $self->pidfile->pid($$);
    
    # Avoid 'stdin reopened for output'
    # warning with newer perls
    open( NULL, '/dev/null' );
    <NULL> if (0);    

    # Change to basedir
    chdir $self->basedir;

    $self->pidfile->write;
    $self->setup_signals;
    return $$;
}

# Make _kill *really* private
my $_kill;

sub stop {
    my ( $self, %args ) = @_;
    my $pid = $self->pidfile->pid;
    $self->$_kill($pid) unless $self->foreground();
    $self->pidfile->remove;
    return 1 if $args{no_exit};
    exit;
}

sub restart {
    my ($self) = @_;
    $self->stop( no_exit => 1 );
    $self->start();
}

sub setup_signals {
    my $self = shift;
    $SIG{'INT'} = sub { $self->handle_sigint };
    $SIG{'HUP'} = sub { $self->handle_sighup };    
}

sub handle_sigint { $_[0]->stop; }
sub handle_sighup { $_[0]->restart; }

$_kill = sub {
    my ( $self, $pid ) = @_;
    return unless $pid;
    unless ( CORE::kill 0 => $pid ) {

        # warn "$pid already appears dead.";
        return;
    }

    if ( $pid eq $$ ) {

        # warn "$pid is us! Can't commit suicide.";
        return;
    }

    my $timeout = $self->stop_timeout;

    # kill 0 => $pid returns 0 if the process is dead
    # $!{EPERM} could also be true if we cant kill it (permission error)

    # Try SIGINT ... 2s ... SIGTERM ... 2s ... SIGKILL ... 3s ... UNDEAD!
    for ( [ 2, $timeout ], [15, $timeout], [9, $timeout * 1.5] ) {
        my ($signal, $timeout) = @$_;
        $timeout = int $timeout;
        
        CORE::kill($signal, $pid);
        
        last unless CORE::kill 0 => $pid or $!{EPERM};
        
        while ($timeout) {
            sleep(1);
            last unless CORE::kill 0 => $pid or $!{EPERM};
            $timeout--;
        }
    }

    return unless ( CORE::kill 0 => $pid or $!{EPERM} );

    # IF it is still running
    Carp::carp "$pid doesn't seem to want to die.";     # AHH EVIL DEAD!
};

1;
__END__

=pod

=head1 NAME

MooseX::Daemonize - provides a Role that daemonizes your Moose based 
application.

=head1 VERSION

This document describes MooseX::Daemonize version 0.04

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

Often you want to write a persistant daemon that has a pid file, and responds
appropriately to Signals.  This module helps provide the basic infrastructure
to do that.

=head1 ATTRIBUTES

=over

=item progname Path::Class::Dir | Str

The name of our daemon, defaults to $self->meta->name =~ s/::/_/;

=item pidbase Path::Class::Dir | Str

The base for our bid, defaults to /var/run/$progname

=item pidfile MooseX::Daemonize::Pid::File | Str

The file we store our PID in, defaults to /var/run/$progname

=item foreground Bool

If true, the process won't background. Useful for debugging. This option can 
be set via Getopt's -f.

=item is_daemon Bool

If true, the process is the backgrounded process. This is useful for example
in an after 'start' => sub { } block

=item stop_timeout

Number of seconds to wait for the process to stop, before trying harder to kill
it. Defaults to 2 seconds

=back

=head1 METHODS 

=over

=item start()

Setup a pidfile, fork, then setup the signal handlers.

=item stop()

Stop the process matching the pidfile, and unlinks the pidfile.

=item restart()

Litterally 

    $self->stop();
    $self->start();

=item daemonize()

Calls daemonize from MooseX::Daemonize::Core.

=item setup_signals()

Setup the signal handlers, by default it only sets up handlers for SIGINT and SIGHUP

=item handle_sigint()

Handle a INT signal, by default calls C<$self->stop()>

=item handle_sighup()

Handle a HUP signal. By default calls C<$self->restart()>

=item meta()

The C<meta()> method from L<Class::MOP::Class>

=back

=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

Obviously L<Moose>, and L<Proc::Daemon>

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

=head1 THANKS

Mike Boyko, Matt S. Trout, Stevan Little, Brandon Black, Ash Berlin and the 
#moose denzians

Some bug fixes sponsored by Takkle Inc.

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Chris Prather C<< <perigrin@cpan.org> >>. All rights 
reserved.

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

=cut
