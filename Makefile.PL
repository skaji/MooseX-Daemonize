# Load the Module::Install bundled in ./inc/
use inc::Module::Install;

# Define metadata
name 'MooseX-Daemonize';
all_from 'lib/MooseX/Daemonize.pm';

# Specific dependencies
build_requires 'Test::More' => 0;
requires 'Proc::Daemon'     => 0;
requires 'Carp'             => 0;
requires 'File::Flock'      => 0;
requires 'File::Slurp'      => 0;
requires 'Moose'            => 0.20;

no_index 'directory' => 'examples';

auto_install;
WriteAll;
