use strict;

package Test::MooseX::Daemonize;
use Proc::Daemon;
use File::Slurp;

# BEGIN CARGO CULTING
use Sub::Exporter;
use Test::Builder;
our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:PERIGRIN';

my @exports = qw[
  daemonize_ok
  check_test_output
];

Sub::Exporter::setup_exporter(
    {
        exports => \@exports,
        groups  => { default => \@exports }
    }
);

our $Test = Test::Builder->new;

sub daemonize_ok {
    my ( $daemon, $msg ) = @_;
    unless ( my $pid = Proc::Daemon::Fork ) {
        $daemon->start();
        exit;
    }
    else {
        sleep(1);    # Punt on sleep time, 1 seconds should be enough
        $Test->ok( -e $daemon->pidfile->file, $msg )
          || $Test->diag( 'Pidfile (' . $daemon->pidfile->file . ') not found.' );
    }
}

sub check_test_output {
    my ($app) = @_;
    open( my $stdout_in, '<', $app->test_output )
      or die "can't open test output: $!";
    while ( my $line = <$stdout_in> ) {
        $line =~ s/\s+\z//;
        my $label;
        if ( $line =~ /\A((not\s+)?ok)(?:\s+-)(?:\s+(.*))\z/ ) {
            my ( $status, $not, $text ) = ( $1, $2, $3 );
            $text ||= '';

           # We don't just call ok(!$not), because that generates diagnostics of
           # its own for failures. We only want the diagnostics from the child.
            my $num = $Test->current_test;
            $Test->current_test( ++$num );
            $Test->_print("$status $num - $text\n");
        }
        elsif ( $line =~ s/\A#\s?// ) {
            $Test->diag($line);
        }
        else {
            $Test->_print_diag("$label: $line (unrecognised)\n");
        }
    }
}

package Test::MooseX::Daemonize::Testable;
use Moose::Role;

has test_output => (
    isa      => 'Str',
    is       => 'ro',
    required => 1,
);

after daemonize => sub {
    $Test->use_numbers(0);
    $Test->no_ending(1);
    open my $out, '>', $_[0]->test_output or die "Cannot open test output: $!";
    my $fileno = fileno $out;
    open STDERR, ">&=", $fileno
      or die "Can't redirect STDERR";

    open STDOUT, ">&=", $fileno
      or die "Can't redirect STDOUT";

    $Test->output($out);
    $Test->failure_output($out);
    $Test->todo_output($out);
};

1;
__END__


=head1 NAME

Test::MooseX::Daemonize - provides a Role that daemonizes your Moose based application.


=head1 VERSION

This document describes MooseX::Daemonize version 0.0.1


=head1 SYNOPSIS
    
    package main;
    use Cwd;

    ## Try to make sure we are in the test directory
    chdir 't' if ( Cwd::cwd() !~ m|/t$| );
    my $cwd = Cwd::cwd();

    my $file = join( '/', $cwd, 'im_alive' );
    my $daemon = FileMaker->new( pidbase => '.', filename => $file );

    daemonize_ok( $daemon, 'child forked okay' );
    ok( -e $file, "$file exists" );
    unlink($file);

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

Handle a INT signal, by default calls C<$self->stop()>;

=item handle_sighup()

Handle a HUP signal. Nothing is done by default.

=item meta()

the C<meta()> method from L<Class::MOP::Class>

=item daemonize_ok()

=item check_test_output()

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
