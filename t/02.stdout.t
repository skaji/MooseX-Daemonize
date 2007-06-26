use Test::More no_plan => 1;
use Test::Builder;
use Test::MooseX::Daemonize;
use MooseX::Daemonize;

my $Test = Test::Builder->new;

{

    package TestOutput;
    use Moose;
    with qw(MooseX::Daemonize);
    with qw(Test::MooseX::Daemonize::Testable);    # setup our test environment

    after start => sub {
        my ($self) = @_;
        $self->output_ok();
    };

    sub output_ok {
        my ($self) = @_;
        my $count = 1;
        while (1) {
            $Test->ok( $count++, "$count output_ok" );
            sleep(1);
        }

    }
    no Moose;
}

package main;
use Cwd;

## Try to make sure we are in the test directory
chdir 't' if ( Cwd::cwd() !~ m|/t$| );
my $cwd = Cwd::cwd();
my $app = TestOutput->new(
    pidbase     => $cwd,
    test_output => join( '/', $cwd, 'results' ),
);
daemonize_ok( $app, 'child forked okay' );
sleep(5);    # give ourself a chance to produce some output
$app->stop( no_exit => 1 );

check_test_output($app);
unlink( $app->test_output );
