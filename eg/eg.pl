#!/usr/bin/env perl
use 5.24.0;
use warnings;
use experimental 'signatures';
use lib "lib", "../lib";
use Data::Dump;

use Workers;

my $workers = Workers->new(5, sub {
    my $job = shift;
    dd [$$, $job];
    $$;
});


my @workers = $workers->wait;
$_->work({ 1 => 1 }) for @workers;

say  "---------";
dd $_->result for @workers;

sleep;


