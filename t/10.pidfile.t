#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 25;
use Test::Exception;

BEGIN {
    use_ok('MooseX::Daemonize::Pid::File');
}

{
    my $f = MooseX::Daemonize::Pid::File->new(
        file => [ 't', 'foo.pid' ]
    );
    isa_ok($f, 'MooseX::Daemonize::Pid::File');

    isa_ok($f->file, 'Path::Class::File');

    is($f->pid, $$, '... the PID is our current process');

    lives_ok {
        $f->write
    } '... writing the PID file';

    is($f->file->slurp(chomp => 1), $f->pid, '... the PID in the file is correct');
    
    ok($f->is_running, '... it is running too');

    lives_ok {
        $f->remove
    } '... removing the PID file';

    ok(!-e $f->file, '... the PID file does not exist anymore');
}

{
    my $f = MooseX::Daemonize::Pid::File->new(
        file => [ 't', 'bar.pid' ]
    );
    isa_ok($f, 'MooseX::Daemonize::Pid::File');

    isa_ok($f->file, 'Path::Class::File');

    lives_ok {
        $f->write
    } '... writing the PID file';

    is($f->file->slurp(chomp => 1), $f->pid, '... the PID in the file is correct');
    is($f->pid, $$, '... the PID is our current process');
    
    ok($f->is_running, '... it is running too');    

    lives_ok {
        $f->remove
    } '... removing the PID file';

    ok(!-e $f->file, '... the PID file does not exist anymore');
}

{
    my $PID = 9999;
    
    my $f = MooseX::Daemonize::Pid::File->new(
        file => [ 't', 'baz.pid' ],
        pid  => $PID,
    );
    isa_ok($f, 'MooseX::Daemonize::Pid::File');

    isa_ok($f->file, 'Path::Class::File');
    
    is($f->pid, $PID, '... the PID is our made up PID');

    lives_ok {
        $f->write
    } '... writing the PID file';

    is($f->file->slurp(chomp => 1), $f->pid, '... the PID in the file is correct');

    ok(!$f->is_running, '... it is not running (cause we made the PID up)');

    lives_ok {
        $f->remove
    } '... removing the PID file';

    ok(!-e $f->file, '... the PID file does not exist anymore');
}
