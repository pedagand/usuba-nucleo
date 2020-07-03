#!/usr/bin/perl

use strict;
use warnings;
use feature 'say';
use autodie qw( open close );

open my $FH_OUT, '>', 'stack_usage.txt';

for my $file (glob("usuba/nist/*/usuba/bench/masked_*_ua_*.c")) {
    system "arm-none-eabi-gcc -Wall -Wno-unused-function -mcpu=cortex-m4 -mlittle-endian -mthumb -Os -D NUCLEO -I usuba/arch -D MASKING_ORDER=64 -c $file -o t.c -fstack-usage";
    my ($cipher, $slicing) = $file =~ m{masked_(.*?)_ua_(.*?)\.c};
    open my $FH, '<', 't.su';
    my $total_stack = 0;
    while (<$FH>) {
	if (/\s+(\d+)\s+/) { $total_stack += $1 }
    }
    say "$cipher-$slicing: $total_stack";
    say $FH_OUT "$cipher-$slicing: $total_stack";
}
