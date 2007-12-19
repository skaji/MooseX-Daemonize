#!/usr/bin/perl

use strict;
use warnings;
use Cwd;
use File::Spec::Functions;

use Test::More tests => 9;
use MooseX::Daemonize;

use constant DEBUG => 0;

my $CWD                = Cwd::cwd;
my $FILENAME           = "$CWD/im_alive";
$ENV{MX_DAEMON_STDOUT} = catfile($CWD, 'Out.txt');
$ENV{MX_DAEMON_STDERR} = catfile($CWD, 'Err.txt');

{

    package FileMaker;
    use Moose;
    with qw(MooseX::Daemonize);

    has filename => ( isa => 'Str', is => 'ro' );
    
    after start => sub { 
        my $self = shift;
        if ($self->is_daemon) {
            $self->create_file( $self->filename );
        }
    };

    sub create_file {
        my ( $self, $file ) = @_;
        open( my $FILE, ">$file" ) || die $!;
        close($FILE);
    }
}

my $app = FileMaker->new(
    pidbase  => $CWD,
    filename => $FILENAME,
);

ok(!$app->status, '... the daemon is running');

diag $$ if DEBUG;

ok($app->start, '... daemon started');
sleep(1); # give it a second ...

ok($app->status, '... the daemon is running');

my $pid = $app->pidfile->pid;
isnt($pid, $$, '... the pid in our pidfile is correct (and not us)');

if (DEBUG) {
    diag `ps $pid`;
    diag "Status is: " . $app->status_message;    
}

ok( -e $app->filename, "file exists" );
ok($app->status, '... the daemon is still running');

if (DEBUG) {
    diag `ps $pid`;
    diag "Status is: " . $app->status_message;    
}

ok( $app->stop, 'app stopped' );
ok(!$app->status, '... the daemon is no longer running');

if (DEBUG) {
    diag `ps $pid`;
    diag "Status is: " . $app->status_message;    
}

ok( not(-e $app->pidfile->file) , 'pidfile gone' );

unlink $FILENAME;
unlink $ENV{MX_DAEMON_STDOUT};
unlink $ENV{MX_DAEMON_STDERR};
