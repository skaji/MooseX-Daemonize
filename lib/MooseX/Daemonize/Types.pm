package MooseX::Daemonize::Types;

use Moose::Util::TypeConstraints;
use MooseX::Types::Path::Class;
use MooseX::Daemonize::PidFile; # need this for the coercion below

our $VERSION = 0.01;

coerce 'MooseX::Daemonize::PidFile' 
    => from 'Str' 
        => via { MooseX::Daemonize::PidFile->new( file => $_ ) }
    => from 'Path::Class::File' 
        => via { MooseX::Daemonize::PidFile->new( file => $_ ) };

1;

__END__