#!perl -T

use Test::More tests => 2;

BEGIN {
	use_ok( 'Wx::Perl::Packager::PDKWindow' );
}

my $win = Wx::Perl::Packager::PDKWindow->new(undef,-1);

isa_ok( $win, "Wx::Perl::Packager::PDKWindow" );

1;
