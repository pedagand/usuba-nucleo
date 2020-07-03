#!/usr/bin/perl

use feature 'say';
use strict;
use warnings;

#open my $F1, '<', 'stack_Os_ua-masked.txt' or die $!;
open my $F1, '<', 'stack_usage.txt' or die $!;
open my $F2, '<', 'stack_Os_masked_no-fusion.txt' or die $!;

my (%total,%count);
while (<$F1>) {
    my ($cipher1, $stack_size1) = /^(.*): (\d+)/;
    my $l2 = <$F2>;
    my ($cipher2, $stack_size2) = $l2 =~ /^(.*): (\d+)/;
    if ($cipher1 ne $cipher2) { die "Different ciphers" }
    printf "%21s: %7d  (opt:%6d -- no-opt:%6d)\n",$cipher1, $stack_size2 - $stack_size1, $stack_size1, $stack_size2;
    $total{$cipher1 =~ /bitslice/ ? 'bitslice' : 'vslice'} += $stack_size2 - $stack_size1;
    $count{$cipher1 =~ /bitslice/ ? 'bitslice' : 'vslice'}++;
}

printf "\nAverage per cipher bitslice   : %d\n", $total{bitslice} / $count{bitslice};
printf "Average per cipher vslice     : %d\n", $total{vslice}   / $count{vslice};
printf "Average per cipher all slicing: %d\n", ($total{vslice}+$total{bitslice}) / ($count{vslice}+$count{bitslice});
