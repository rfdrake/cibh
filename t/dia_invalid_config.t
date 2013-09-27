#!/usr/bin/perl

use Test::More tests => 1;

use CIBH::Dia;
use Data::Dumper;
print Dumper \@INC;

my $dia = CIBH::Dia->new(\*DATA);

ok($dia == undef, 'CIBH::Dia should return undef on invalid Dia file.');


__DATA__
feirugffffieurbfi
