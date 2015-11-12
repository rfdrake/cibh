#!/usr/bin/perl

use Test::More;
eval 'use XML::LibXML; 1' or plan skip_all => 'Optional module XML::LibXML required';

use CIBH::Dia;

is(CIBH::Dia->new('data', \*DATA), undef, 'CIBH::Dia should return undef on invalid Dia file.');
done_testing();

__DATA__
feirugffffieurbfi
