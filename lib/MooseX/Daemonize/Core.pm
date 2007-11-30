package MooseX::Daemonize::Core;
use strict;    # because Kwalitee is pedantic
use Moose::Role;

our $VERSION = 0.01;

use POSIX ();

has is_daemon => (
    isa     => 'Bool',
    is      => 'rw',
    default => sub { 0 },
);

sub daemon_fork   { fork }
sub daemon_detach { 
    # ignore these signals
    for (qw(TSTP TTIN TTOU PIPE POLL STOP CONT CHLD)) {
        $SIG{$_} = 'IGNORE' if (exists $SIG{$_});
    }
    
    POSIX::setsid;  # set session id
    chdir '/';      # change to root directory
    umask 0;        # clear the file creation mask            
    
    # get the max numnber of possible file descriptors
    my $openmax = POSIX::sysconf( &POSIX::_SC_OPEN_MAX );
    $openmax = 64 if !defined($openmax) || $openmax < 0;
    
    # close them all 
    POSIX::close($_) foreach (0 .. $openmax);

    open(STDIN,  "+>/dev/null");
    open(STDOUT, "+>&STDIN");
    open(STDERR, "+>&STDIN");    
}

sub daemonize {
    my ($self) = @_;
    return if $self->daemon_fork;
    $self->daemon_detach;
    $self->is_daemon(1);
}

1;
__END__

=head1 NAME

MooseX::Daemonize::Core - provides a Role the core daemonization features

=head1 VERSION

=head1 SYNOPSIS
     
=head1 DESCRIPTION

=head1 ATTRIBUTES

=over

=item is_daemon Bool

If true, the process is the backgrounded process. This is useful for example
in an after 'start' => sub { } block

=back

=head1 METHODS 

=over

=item daemon_fork()

=item daemon_detach()

=item daemonize()

Calls C<Proc::Daemon::Init> to daemonize this process. 

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
