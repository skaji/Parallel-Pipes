#!/usr/bin/env perl
use 5.24.0;
use warnings;
use experimental 'signatures';
use lib "lib", "../lib";

use Workers;

my $workers = Workers->new(5, sub {
    my $job = shift;
    warn $job;
});

sleep;
