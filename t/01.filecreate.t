use Test::More no_plan => 1;
use Proc::Daemon;
use Cwd;

##  Since a daemon will not be able to print terminal output, we
##  have a test daemon create a file, and another process test for
##  its existence.

{

    package FileMaker;
    use Moose;
    with qw(MooseX::Daemonize);

    sub create_file {
        my ( $self, $file ) = @_;
        open( FILE, ">$file" ) || die $!;
        close(FILE);
    }

    no Moose;
}

package main;

## Try to make sure we are in the test directory
my $cwd = Cwd::cwd();
chdir 't' if ( $cwd !~ m|/t$| );
$cwd = Cwd::cwd();

## Test filename
my $file = join( '/', $cwd, 'im_alive' );
## Parent process will check if file created.  Child becomes the daemon.
if ( my $pid = Proc::Daemon::Fork ) {
    sleep(5);    # Punt on sleep time, 5 seconds should be enough
    ok( -e $file, "$file exists");
    unlink($file);
}
else {
    my $daemon = FileMaker->new(pidbase => '.');
    $daemon->start();
    $daemon->create_file($file);
    $daemon->stop();
    exit;
}
