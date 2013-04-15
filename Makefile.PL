# Load the Module::Install bundled in ./inc/
use inc::Module::Install 0.75;

# Define metadata
name 'MooseX-Daemonize';
all_from 'lib/MooseX/Daemonize.pm';

# Specific dependencies
build_requires 'Test::More'   => 0;
build_requires 'Test::Moose'  => 0;

requires 'Moose'                      => 0.33;
requires 'MooseX::Getopt'             => 0.07;
requires 'MooseX::Types::Path::Class' => 0;
requires 'File::Path'                 => 2.08;
test_requires 'Test::More'            => 0.88;
test_requires 'Test::Fatal'           => 0;

no_index 'directory' => 'examples';

auto_manifest;

# r/w: gitmo@git.moose.perl.org:MooseX-Daemonize.git
repository 'git://git.moose.perl.org/MooseX-Daemonize.git';

WriteAll;
