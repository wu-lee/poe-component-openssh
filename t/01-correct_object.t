#!perl

package test;

use Test::More;
use MooseX::POE;
use POE::Component::OpenSSH;
with 'POE::Test::Helpers::MooseRole';

has 'ssh' => (
    is         => 'ro',
    isa        => 'POE::Component::OpenSSH',
    lazy_build => 1,
);

has 'args' => (
    is => 'ro',
    isa => 'ArrayRef',
);

has '+tests' => (
    default => sub { {
        START       => { count  => 1                                     },
        _build_ssh  => { count  => 1,  deps => [               'START']  },
        hello       => { count  => 1,  deps => [ '_build_ssh', 'START' ] },
        check_event => { params => [], deps => [ '_build_ssh', 'START' ] },
    } },
);

sub _build_ssh {
    my $self = $_[OBJECT];
    return POE::Component::OpenSSH->new( args  => $self->args );
}

sub START {
    my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];

    $self->ssh->capture( { event => 'hello' }, '/bin/true' );
    $kernel->alarm( 'check_event', time() + 5 );
}

event 'hello' => sub { $_[KERNEL]->alarm_remove_all() };

event 'check_event' => sub {
    # TODO: this should actually check if the password is okay
    # but it's hard to check that
    # we're only skipping one (hello) because the rest will still run
    skip 'Timing out. Probably wrong password.' => 1;
    $_[KERNEL]->stop();
};

package main;

use English '-no_match_vars';
use Test::More tests => 5;
use POE::Kernel;
use Term::ReadKey;
use Term::ReadPassword;

SKIP: {
    my ( $user, $pass );
    eval {
        local $SIG{'ALRM'} = sub { die "timeout\n"; };
        alarm 10;
        $user = getpwuid $EFFECTIVE_USER_ID;
        $pass = read_password("Local SSH Pass for $user: ");
        #ReadMode 0;
        alarm 0;
    };

    if ( $@ =~ /timeout/ ) {
        ReadMode 'normal';
        skip 'Youz a Wuss!' => 5;
    }

    $user || skip 'Got no username' => 5;
    $pass || skip 'Got no pass'     => 5;

    test->new( args => [ 'localhost', user => $user, passwd => $pass ] );

    POE::Kernel->run();
}


