package MooseX::Daemonize::Pid::File;
use strict;    # because Kwalitee is pedantic
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Types::Path::Class;

coerce 'MooseX::Daemonize::Pid::File' 
    => from 'Str' 
        => via { MooseX::Daemonize::Pid::File->new( file => $_ ) }
    => from 'Path::Class::File' 
        => via { MooseX::Daemonize::Pid::File->new( file => $_ ) };

our $VERSION = '0.01';

extends 'MooseX::Daemonize::Pid';

has '+pid' => (
    default => sub { 
        my $self = shift;
        $self->does_file_exist
            ? $self->file->slurp(chomp => 1)
            : $$
    }
);

has 'file' => (
    is       => 'ro',
    isa      => 'Path::Class::File',
    coerce   => 1,
    required => 1,
    handles  => [ 'remove' ]
);

sub does_file_exist { -s (shift)->file }

sub write {
    my $self = shift;
    my $fh = $self->file->openw;
    $fh->print($self->pid);
    $fh->close;
}

override 'is_running' => sub {
    return 0 unless (shift)->does_file_exist;
    super();
};

1;

__END__

=pod

=head1 NAME

MooseX::Daemonize::Pid::File - PID file management for MooseX::Daemonize

=head1 SYNOPSIS
     
=head1 DESCRIPTION

=head1 ATTRIBUTES

=over

=item file Path::Class::File | Str

=back

=head1 METHODS 

=over

=item remove

=item write

=item does_file_exist

=item is_running

=item meta()

The C<meta()> method from L<Class::MOP::Class>

=back

=head1 DEPENDENCIES

Obviously L<Moose>

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-acme-dahut-call@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 AUTHOR

Stevan Little  C<< <stevan@cpan.org> >>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Chris Prather C<< <perigrin@cpan.org> >>. All rights 
reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=cut