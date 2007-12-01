package MooseX::Daemonize::Core;
use Moose::Role;

our $VERSION = 0.01;

use POSIX ();

has is_daemon => (
    isa     => 'Bool',
    is      => 'rw',
    default => sub { 0 },
);

sub daemon_fork { 
    my $self = shift;
    if (my $pid = fork) {
        return $pid;
    }
    else {
        $self->is_daemon(1);
        return;
    }
}
sub daemon_detach { 
    my $self = shift;
    
    return unless $self->is_daemon;
    
    (POSIX::setsid)  # set session id
        || confess "Cannot detach from controlling process";   
        
    chdir '/';      # change to root directory
    umask 0;        # clear the file creation mask            
    
    # get the max numnber of possible file descriptors
    my $openmax = POSIX::sysconf( &POSIX::_SC_OPEN_MAX );
    $openmax = 64 if !defined($openmax) || $openmax < 0;
    
    # close them all 
    POSIX::close($_) foreach (0 .. $openmax);

    open(STDIN,  "+>/dev/null");

    if (my $stdout_file = $ENV{MX_DAEMON_STDOUT}) {
        open STDOUT, ">", $stdout_file 
            or confess "Could not redirect STDOUT to $stdout_file : $!";
    }
    else {
        open(STDOUT, "+>&STDIN");
    }

    if (my $stderr_file = $ENV{MX_DAEMON_STDERR}) {    
        open STDERR, ">", "ERR.txt"
            or confess "Could not redirect STDERR to $stderr_file : $!";        
    }
    else {               
        open(STDERR, "+>&STDIN");    
    }
}

sub daemonize {
    my ($self) = @_;
    $self->daemon_fork; 
    $self->daemon_detach;
}

1;
__END__

=head1 NAME

MooseX::Daemonize::Core - provides a Role the core daemonization features

=head1 VERSION

=head1 SYNOPSIS
     
=head1 DESCRIPTION

=head2 Important Note

This method with not exit the parent process for you, it only forks 
and detaches your child (daemon) process. It is your responsibility 
to exit the parent process in some way.

=head1 ATTRIBUTES

=over

=item I<is_daemon (is => rw, isa => Bool)>

This attribute is used to signal if we are within the 
daemon process or not. 

=back

=head1 METHODS 

=over

=item B<daemon_fork>

This forks off the child process to be daemonized. Just as with 
the built in fork, it returns the child pid to the parent process, 
0 to the child process. It will also set the is_daemon flag 
appropriately.

=item B<daemon_detach>

This detaches the new child process from the terminal by doing 
the following things. If called from within the parent process
(the is_daemon flag is set to false), then it will simply return
and do nothing.

=over 4

=item Becomes a session leader 

This detaches the program from the controlling terminal, it is 
accomplished by calling POSIX::setsid.

=item Changes the current working directory to "/"

This is standard daemon behavior, if you want a different working 
directory then simply change it later in your daemons code. 

=item Clears the file creation mask.

=item Closes all open file descriptors.

=item Reopen STDERR, STDOUT & STDIN to /dev/null

This behavior can be controlled slightly though the MX_DAEMON_STDERR 
and MX_DAEMON_STDOUT environment variables. It will look for a filename
in either of these variables and redirect STDOUT and/or STDERR to those
files. This is useful for debugging and/or testing purposes.

-back

=item B<daemonize>

This will simply call C<daemon_fork> followed by C<daemon_detach>.

=item meta()

The C<meta()> method from L<Class::MOP::Class>

=back

=head1 DEPENDENCIES

L<Moose::Role>, L<POSIX>

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-acme-dahut-call@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 SEE ALSO

L<Proc::Daemon>

This code is based B<HEAVILY> on L<Proc::Daemon>, we originally 
depended on it, but we needed some more flexibility, so instead
we just stole the code. 

=head1 AUTHOR

Stevan Little  C<< <stevan.little@iinteractive.com> >>

=head1 THANKS

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Chris Prather C<< <perigrin@cpan.org> >>. All rights 
reserved.

Portions heavily borrowed from L<Proc::Daemon> which is copyright Earl Hood.

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
