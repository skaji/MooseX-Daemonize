# NAME

MooseX::Daemonize - Role for daemonizing your Moose based application

# VERSION

version 0.19

# WARNING

The maintainers of this module now recommend using [Daemon::Control](https://metacpan.org/pod/Daemon::Control) instead.

# SYNOPSIS

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

    $daemon->start   if $command eq 'start';
    $daemon->status  if $command eq 'status';
    $daemon->restart if $command eq 'restart';
    $daemon->stop    if $command eq 'stop';

    warn($daemon->status_message);
    exit($daemon->exit_code);

# DESCRIPTION

Often you want to write a persistent daemon that has a pid file, and responds
appropriately to Signals. This module provides a set of basic roles as an
infrastructure to do that.

# CAVEATS

When going into background MooseX::Daemonize closes all open file
handles. This may interfere with you logging because it may also close the log
file handle you want to write to. To prevent this you can either defer opening
the log file until after start. Alternatively, use can use the
'dont\_close\_all\_files' option either from the command line or in your .sh
script.

Assuming you want to use Log::Log4perl for example you could expand the
MooseX::Daemonize example above like this.

    after start => sub {
        my $self = shift;
        return unless $self->is_daemon;
        Log::Log4perl->init(\$log4perl_config);
        my $logger = Log::Log4perl->get_logger();
        $logger->info("Daemon started");
        # your daemon code here ...
    };

# ATTRIBUTES

This list includes attributes brought in from other roles as well
we include them here for ease of documentation. All of these attributes
are settable though [MooseX::Getopt](https://metacpan.org/pod/MooseX::Getopt)'s command line handling, with the
exception of `is_daemon`.

- _progname Path::Class::Dir | Str_

    The name of our daemon, defaults to `$package_name =~ s/::/_/`;

- _pidbase Path::Class::Dir | Str_

    The base for our PID, defaults to `/var/run/`

- _basedir Path::Class::Dir | Str_

    The directory we chdir to; defaults to `/`.

- _pidfile MooseX::Daemonize::Pid::File | Str_

    The file we store our PID in, defaults to `$pidbase/$progname.pid`

- _foreground Bool_

    If true, the process won't background. Useful for debugging. This option can
    be set via Getopt's -f.

- _no\_double\_fork Bool_

    If true, the process will not perform the typical double-fork, which is extra
    added protection from your process accidentally acquiring a controlling terminal.
    More information can be found by Googling "double fork daemonize".

- _ignore\_zombies Bool_

    If true, the process will not clean up zombie processes.
    Normally you don't want this.

- _dont\_close\_all\_files Bool_

    If true, the objects open filehandles will not be closed when daemonized.
    Normally you don't want this.

- _is\_daemon Bool_

    If true, the process is the backgrounded daemon process, if false it is the
    parent process. This is useful for example in an `after 'start' =` sub { }>
    block.

    __NOTE:__ This option is explicitly __not__ available through [MooseX::Getopt](https://metacpan.org/pod/MooseX::Getopt).

- _stop\_timeout_

    Number of seconds to wait for the process to stop, before trying harder to kill
    it. Defaults to 2 seconds.

These are the internal attributes, which are not available through MooseX::Getopt.

- _exit\_code Int_
- _status\_message Str_

# METHODS

## Daemon Control Methods

These methods can be used to control the daemon behavior. Every effort
has been made to have these methods DWIM (Do What I Mean), so that you
can focus on just writing the code for your daemon.

Extending these methods is best done with the [Moose](https://metacpan.org/pod/Moose) method modifiers,
such as `before`, `after` and `around`.

- __start__

    Setup a pidfile, fork, then setup the signal handlers.

- __stop__

    Stop the process matching the pidfile, and unlinks the pidfile.

- __restart__

    Literally this is:

        $self->stop();
        $self->start();

- __status__
- __shutdown__

## Pidfile Handling Methods

- __init\_pidfile__

    This method will create a [MooseX::Daemonize::Pid::File](https://metacpan.org/pod/MooseX::Daemonize::Pid::File) object and tell
    it to store the PID in the file `$pidbase/$progname.pid`.

- __check__

    This checks to see if the daemon process is currently running by checking
    the pidfile.

- __get\_pid__

    Returns the PID of the daemon process.

- __save\_pid__

    Write the pidfile.

- __remove\_pid__

    Removes the pidfile.

## Signal Handling Methods

- __setup\_signals__

    Setup the signal handlers, by default it only sets up handlers for SIGINT and
    SIGHUP. If you wish to add more signals just use the `after` method modifier
    and add them.

- __handle\_sigint__

    Handle a INT signal, by default calls `$self-`stop()>

- __handle\_sighup__

    Handle a HUP signal. By default calls `$self-`restart()>

## Exit Code Methods

These are overridable constant methods used for setting the exit code.

- OK

    Returns 0.

- ERROR

    Returns 1.

## Introspection

- meta()

    The `meta()` method from [Class::MOP::Class](https://metacpan.org/pod/Class::MOP::Class)

# DEPENDENCIES

[Moose](https://metacpan.org/pod/Moose), [MooseX::Getopt](https://metacpan.org/pod/MooseX::Getopt), [MooseX::Types::Path::Class](https://metacpan.org/pod/MooseX::Types::Path::Class) and [POSIX](https://metacpan.org/pod/POSIX)

# INCOMPATIBILITIES

None reported. Although obviously this will not work on Windows.

# BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
`bug-MooseX-Daemonize@rt.cpan.org`, or through the web interface at
[http://rt.cpan.org](http://rt.cpan.org).

# SEE ALSO

[Daemon::Control](https://metacpan.org/pod/Daemon::Control), [Proc::Daemon](https://metacpan.org/pod/Proc::Daemon), [Daemon::Generic](https://metacpan.org/pod/Daemon::Generic)

# AUTHORS

Chris Prather  `<chris@prather.org`

Stevan Little  `<stevan.little@iinteractive.com>`

# THANKS

Mike Boyko, Matt S. Trout, Stevan Little, Brandon Black, Ash Berlin and the
\#moose denzians

Some bug fixes sponsored by Takkle Inc.

# LICENCE AND COPYRIGHT

Copyright (c) 2007-2011, Chris Prather `<chris@prather.org>`. Some rights
reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See [perlartistic](https://metacpan.org/pod/perlartistic).

# DISCLAIMER OF WARRANTY

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
