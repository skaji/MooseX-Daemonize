#!/usr/bin/perl

use strict;
use warnings;

use Cwd;
use File::Spec::Functions;

use Test::More no_plan => 1;
use Test::Exception;
use Test::Moose;

BEGIN {
    use_ok('MooseX::Daemonize::Core');
    use_ok('MooseX::Daemonize::Pid');    
}

use constant DEBUG => 0;

my $CWD                = Cwd::cwd;
$ENV{MX_DAEMON_STDOUT} = catfile($CWD, 'Out.txt');
$ENV{MX_DAEMON_STDERR} = catfile($CWD, 'Err.txt');

{
    package MyFooDaemon;
    use Moose;
    
    with 'MooseX::Daemonize::Core';
    
    has 'daemon_pid' => (is => 'rw', isa => 'MooseX::Daemonize::Pid');
    
    # capture the PID from the fork
    around 'daemon_fork' => sub {
        my $next = shift;
        my $self = shift;
        if (my $pid = $self->$next(@_)) {
            $self->daemon_pid(
                MooseX::Daemonize::Pid->new(pid => $pid)
            );
        }
    };
    
    sub start {
        my $self = shift;  
        # tell it to ignore zombies ...
        $self->daemonize(
            ignore_zombies => 1,
            no_double_fork => 1,
        );
        return unless $self->is_daemon;
        # change to our local dir
        # so that we can debug easier
        chdir $CWD;
        # make it easy to find with ps
        $0 = 'test-app';
        $SIG{INT} = sub { 
            print "Got INT! Oh Noes!"; 
            exit;
        };      
        while (1) {
            print "Hello from $$\n"; 
            sleep(10);       
        }
        exit;
    }
}

my $d = MyFooDaemon->new;
isa_ok($d, 'MyFooDaemon');
does_ok($d, 'MooseX::Daemonize::Core');

lives_ok {
    $d->start;
} '... successfully daemonized from (' . $$ . ')';

my $p = $d->daemon_pid;
isa_ok($p, 'MooseX::Daemonize::Pid');

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

unlink $ENV{MX_DAEMON_STDOUT};
unlink $ENV{MX_DAEMON_STDERR};


