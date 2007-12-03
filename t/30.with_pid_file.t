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
}

my $CWD                = Cwd::cwd;
my $PIDFILE            = catfile($CWD, 'test-app.pid');
$ENV{MX_DAEMON_STDOUT} = catfile($CWD, 'Out.txt');
$ENV{MX_DAEMON_STDERR} = catfile($CWD, 'Err.txt');

{
    package MyFooDaemon;
    use Moose;
    
    with 'MooseX::Daemonize::Core', 
         'MooseX::Daemonize::WithPidFile';
         
    sub init_pidfile {
        MooseX::Daemonize::Pid::File->new( file => $PIDFILE )
    }
    
    sub start {
        my $self = shift;
        
        $self->daemonize;
        return unless $self->is_daemon;
        
        $self->pidfile->write;
        
        # make it easy to find with ps
        $0 = 'test-app';
        $SIG{INT} = sub { 
            print "Got INT! Oh Noes!"; 
            $self->pidfile->remove;
            exit;
        };      
        while (1) {
            print "Hello from $$\n"; 
            sleep(10);       
        }
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
diag `ps $pid`;
diag "-------";
diag `ps -x | grep test-app`;
diag "-------";
diag "killing $pid";
kill INT => $p->pid;
diag "killed $pid";
sleep(2);
diag `ps $pid`;
diag "-------";
diag `ps -x | grep test-app`;

ok(!$p->is_running, '... the daemon process is no longer running (' . $p->pid . ')');
ok(!(-e $PIDFILE), '... the PID file has been removed');

