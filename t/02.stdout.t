use Test::More no_plan => 1;
use Test::Builder;
use Test::MooseX::Daemonize;

my $Test = Test::Builder->new;
chdir 't' if ( Cwd::cwd() !~ m|/t$| );
my $cwd = Cwd::cwd();

my $file = join( '/', $cwd, 'results' );

{

    package TestOutput;
    use Moose;
    with qw(MooseX::Daemonize);
    with qw(Test::MooseX::Daemonize::Testable); # setup our test environment
    
    has max => ( isa => 'Int', is => 'ro', default => sub { 5 } );
    
    after start => sub {
        my ($self) = @_;
        $self->output_ok(1);
    };

    sub output_ok {
        my ( $self, $count ) = @_;
        $Test->ok( $count, "$count output_ok" );
        if ( $count++ > $self->max ) {
            $self->stop();
            return;
        }
        $self->output_ok($count);
    }
    no Moose;
}

package main;
use Cwd;

## Try to make sure we are in the test directory
chdir 't' if ( Cwd::cwd() !~ m|/t$| );
my $cwd = Cwd::cwd();

my $daemon = TestOutput->new( pidbase => $cwd, test_output => $file);

daemonize_ok( $daemon, 'child forked okay' );

open (my $stdout_in, '<', 'results');
while ( my $line = <$stdout_in> ) {
    $line =~ s/\s+\z//;
    if ( $line =~ /\A((not\s+)?ok)(?:\s+-)(?:\s+(.*))\z/ ) {
        my ( $status, $not, $text ) = ( $1, $2, $3 );
        $text ||= '';

        # We don't just call ok(!$not), because that generates diagnostics of
        # its own for failures. We only want the diagnostics from the child.
        my $num = $Test->current_test;
        $Test->current_test( ++$num );
        $Test->_print("$status $num - $label: $text\n");
    }
    elsif ( $line =~ s/\A#\s?// ) {
        $Test->diag($line);
    }
    else {
        $Test->_print_diag("$label: $line (unrecognised)\n");
    }
}

unlink($file);