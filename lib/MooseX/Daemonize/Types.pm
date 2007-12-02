package MooseX::Daemonize::Types;

use Moose::Util::TypeConstraints;
use MooseX::Types::Path::Class;
use MooseX::Daemonize::Pid::File; # need this for the coercion below

our $VERSION = 0.01;

coerce 'MooseX::Daemonize::Pid::File' 
    => from 'Str' 
        => via { MooseX::Daemonize::Pid::File->new( file => $_ ) }
    => from 'Path::Class::File' 
        => via { MooseX::Daemonize::Pid::File->new( file => $_ ) };

1;

__END__