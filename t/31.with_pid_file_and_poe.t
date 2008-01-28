#!/usr/bin/perl

use strict;
use warnings;

use Cwd;
use File::Spec::Functions;

use Test::More;
use Test::Exception;
use Test::Moose;

BEGIN {
    eval 'use POE::Kernel;';
    plan skip_all => "POE required for this test" if $@;
    plan no_plan => 1;
    use_ok('MooseX::Daemonize::Core');
    
}

use constant DEBUG => 0;

my $CWD                = Cwd::cwd;
my $PIDFILE            = catfile($CWD, 'test-app.pid');
$ENV{MX_DAEMON_STDOUT} = catfile($CWD, 'Out.txt');
$ENV{MX_DAEMON_STDERR} = catfile($CWD, 'Err.txt');

unlink $PIDFILE; # clean up anythinf leftover by last run

{
    package MyFooDaemon;
    use Moose;
    use POE;
    
    with 'MooseX::Daemonize::WithPidFile';
         
    sub init_pidfile {
        MooseX::Daemonize::Pid::File->new( file => $PIDFILE )
    }
    
    sub start {
        my $self = shift;
        
        # this tests our bad PID 
        # cleanup functionality.
        print "Our parent PID is " . $self->pidfile->pid . "\n" if ::DEBUG;
        
        $self->daemonize;
        return unless $self->is_daemon;

        my $session = POE::Session->create(
          inline_states => {
            say_hello => sub { 
              my ($kernel, $heap) = @_[KERNEL, HEAP];

              print "Hello from $$\n";

              $heap->[0] = $kernel->delay_set('say_hello', 10);
            },
            _start => sub {
              my ($kernel, $heap) = @_[KERNEL, HEAP];
              $kernel->sig( INT => 'terminate');

              $kernel->yield('say_hello');
            },
            terminate => sub {
              my ($kernel, $heap) = @_[KERNEL, HEAP];
              $self->pidfile->remove if $self->pidfile->pid == $$;
            }
          },
          heap => [ 0 ]
        );
        
        
        # make it easy to find with ps
        $0 = 'test-app-2';
        POE::Kernel->run;
        exit;
    }
}

my $d = MyFooDaemon->new( pidfile => $PIDFILE );
isa_ok($d, 'MyFooDaemon');
does_ok($d, 'MooseX::Daemonize::Core');
does_ok($d, 'MooseX::Daemonize::WithPidFile');

ok($d->has_pidfile, '... we have a pidfile value');

{
    my $p = $d->pidfile;
    isa_ok($p, 'MooseX::Daemonize::Pid::File');
    #diag $p->dump;
}

ok(!(-e $PIDFILE), '... the PID file does not exist yet');

lives_ok {
    $d->start;
} '... successfully daemonized from (' . $$ . ')';

my $p = $d->pidfile;
isa_ok($p, 'MooseX::Daemonize::Pid::File');
#diag $p->dump;

sleep(2);

ok($p->does_file_exist, '... the PID file exists');
ok($p->is_running, '... the daemon process is running (' . $p->pid . ')');

my $pid = $p->pid;
if (DEBUG) {
    diag `ps $pid`;
    diag "-------";
    diag `ps -x | grep test-app`;
    diag "-------";
    diag "killing $pid";
}
kill INT => $p->pid;
diag "killed $pid" if DEBUG;
sleep(2);
if (DEBUG) {
    diag `ps $pid`;
    diag "-------";
    diag `ps -x | grep test-app`;
}

ok(!$p->is_running, '... the daemon process is no longer running (' . $p->pid . ')');
ok(!(-e $PIDFILE), '... the PID file has been removed');

unlink $ENV{MX_DAEMON_STDOUT};
unlink $ENV{MX_DAEMON_STDERR};
