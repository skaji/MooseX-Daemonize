use Test::More tests => 2;
use Test::MooseX::Daemonize;

##  Since a daemon will not be able to print terminal output, we
##  have a test daemon create a file, and another process test for
##  its existence.

{

    package FileMaker;
    use Moose;
    with qw(MooseX::Daemonize);

    has filename => ( isa => 'Str', is => 'ro' );

    after start => sub { $_[0]->create_file( $_[0]->filename ) };

    sub create_file {
        my ( $self, $file ) = @_;
        open( FILE, ">$file" ) || die $!;
        close(FILE);
    }

    no Moose;
}


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

