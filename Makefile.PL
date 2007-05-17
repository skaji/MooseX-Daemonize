use inc::Module::Install;
WriteMakefile(
    NAME          => 'MooseX::Daemonize',
    AUTHOR        => 'Chris Prather <perigrin@cpan.org>',
    VERSION_FROM  => 'lib/MooseX/Daemonize.pm',
    ABSTRACT_FROM => 'lib/MooseX/Daemonize.pm',
    PL_FILES      => {},
    PREREQ_PM     => {
        'Test::More'   => 0,
        'Proc::Daemon' => 0,
        'Carp'         => 0,
        'File::Flock'  => 0,
        'File::Slurp'  => 0,
        'Moose'        => 0.20,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES    => 'MooseX-Daemonize-*' },
);
