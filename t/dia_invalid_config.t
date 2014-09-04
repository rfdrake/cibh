#!/usr/bin/perl

use Test::More tests => 1;

use CIBH::Dia;

is(CIBH::Dia->new('data', \*DATA), undef, 'CIBH::Dia should return undef on invalid Dia file.');


__DATA__
feirugffffieurbfi
