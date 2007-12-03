package MooseX::Daemonize;
use strict;    # because Kwalitee is pedantic
use Moose::Role;
use MooseX::Types::Path::Class;

our $VERSION = 0.05;

with 'MooseX::Daemonize::WithPidFile',
     'MooseX::Getopt';

has progname => (
    metaclass => 'Getopt',    
    isa       => 'Str',
    is        => 'ro',
    lazy      => 1,
    required  => 1,
    default   => sub {
        ( my $name = lc $_[0]->meta->name ) =~ s/::/_/g;
        return $name;
    },
);

has pidbase => (
    metaclass => 'Getopt',    
    isa       => 'Path::Class::Dir',
    is        => 'ro',
    coerce    => 1,
    required  => 1,    
    lazy      => 1,
    default   => sub { Path::Class::Dir->new('var', 'run') },
);

has basedir => (
    metaclass => 'Getopt',    
    isa       => 'Path::Class::Dir',
    is        => 'ro',
    coerce    => 1,
    required  => 1,
    lazy      => 1,
    default   => sub { Path::Class::Dir->new('/') },
);

has foreground => (
    metaclass   => 'Getopt',
    cmd_aliases => 'f',
    isa         => 'Bool',
    is          => 'ro',
    default     => sub { 0 },
);

has stop_timeout => (
    metaclass => 'Getopt',    
    isa       => 'Int',
    is        => 'rw',
    default   => sub { 2 }
);

# methods ...

## PID file related stuff ...

sub init_pidfile {
    my $self = shift;
    my $file = $self->pidbase . '/' . $self->progname . '.pid';
    confess "Cannot write to $file" unless (-e $file ? -w $file : -w $self->pidbase);
    MooseX::Daemonize::Pid::File->new( file => $file );
}

# backwards compat, 
sub check      { (shift)->pidfile->is_running }
sub save_pid   { (shift)->pidfile->write      }
sub remove_pid { (shift)->pidfile->remove     }
sub get_pid    { (shift)->pidfile->pid        }

## signal handling ...

sub setup_signals {
    my $self = shift;
    $SIG{'INT'} = sub { $self->handle_sigint };
    $SIG{'HUP'} = sub { $self->handle_sighup };    
}

sub handle_sigint { $_[0]->stop; }
sub handle_sighup { $_[0]->restart; }

## daemon control methods ...

sub start {
    my ($self) = @_;
    
    confess "instance already running" if $self->pidfile->is_running;
    
    $self->daemonize unless $self->foreground;
    
    return unless $self->is_daemon;

    $self->pidfile->pid($$);   

    # Change to basedir
    chdir $self->basedir;

    $self->pidfile->write;
    $self->setup_signals;
    return $$;
}

sub restart {
    my ($self) = @_;
    $self->stop( no_exit => 1 );
    $self->start();
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

This document describes MooseX::Daemonize version 0.05

=head1 SYNOPSIS

    package My::Daemon;
    use Moose;
    
    with qw(MooseX::Daemonize);
    
    # ... define your class ....
    
    after start => sub { 
        my $self = shift;
        return unless $self->is_daemon;
        # your daemon code here ...
    };

    # then in your script ... 
    
    my $daemon = My::Daemon->new_with_options();
    
    my ($command) = @{$daemon->extra_argv}
    defined $command || die "No command specified";
    
    $daemon->start() if $command eq 'start';
    $daemon->stop()  if $command eq 'stop';
     
=head1 DESCRIPTION

Often you want to write a persistant daemon that has a pid file, and responds
appropriately to Signals. This module provides a set of basic roles as an  
infrastructure to do that.

=head1 ATTRIBUTES

This list includes attributes brought in from other roles as well
we include them here for ease of documentation. All of these attributes
are settable though L<MooseX::Getopt>'s command line handling, with the 
exception of C<is_daemon>.

=over

=item I<progname Path::Class::Dir | Str>

The name of our daemon, defaults to C<$package_name =~ s/::/_/>;

=item I<pidbase Path::Class::Dir | Str>

The base for our bid, defaults to C</var/run/$progname>

=item I<pidfile MooseX::Daemonize::Pid::File | Str>

The file we store our PID in, defaults to C</var/run/$progname>

=item I<foreground Bool>

If true, the process won't background. Useful for debugging. This option can 
be set via Getopt's -f.

=item I<is_daemon Bool>

If true, the process is the backgrounded daemon process, if false it is the 
parent process. This is useful for example in an C<after 'start' => sub { }> 
block. 

B<NOTE:> This option is explicitly B<not> available through L<MooseX::Getopt>.

=item I<stop_timeout>

Number of seconds to wait for the process to stop, before trying harder to kill
it. Defaults to 2 seconds.

=back

=head1 METHODS 

=head2 Daemon Control Methods

These methods can be used to control the daemon behavior. Every effort 
has been made to have these methods DWIM (Do What I Mean), so that you 
can focus on just writing the code for your daemon. 

Extending these methods is best done with the L<Moose> method modifiers, 
such as C<before>, C<after> and C<around>.

=over 4

=item B<start>

Setup a pidfile, fork, then setup the signal handlers.

=item B<stop>

Stop the process matching the pidfile, and unlinks the pidfile.

=item B<restart>

Literally this is:

    $self->stop();
    $self->start();

=back

=head2 Pidfile Handling Methods

=over 4

=item B<init_pidfile>

This method will create a L<MooseX::Daemonize::Pid::File> object and tell
it to store the PID in the file C<$pidbase/$progname.pid>.

=item B<check>

This checks to see if the daemon process is currently running by checking 
the pidfile.

=item B<get_pid>

Returns the PID of the daemon process.

=item B<save_pid>

Write the pidfile.

=item B<remove_pid>

Removes the pidfile.

=back

=head2 Signal Handling Methods

=over 4

=item B<setup_signals>

Setup the signal handlers, by default it only sets up handlers for SIGINT and 
SIGHUP. If you wish to add more signals just use the C<after> method modifier
and add them.

=item B<handle_sigint>

Handle a INT signal, by default calls C<$self->stop()>

=item B<handle_sighup>

Handle a HUP signal. By default calls C<$self->restart()>

=back

=head2 Introspection

=over 4

=item meta()

The C<meta()> method from L<Class::MOP::Class>

=back

=head1 DEPENDENCIES

L<Moose>, L<MooseX::Getopt>, L<MooseX::Types::Path::Class> and L<POSIX>

=head1 INCOMPATIBILITIES

None reported. Although obviously this will not work on Windows.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-acme-dahut-call@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 SEE ALSO

L<Proc::Daemon>, L<Daemon::Generic>

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
