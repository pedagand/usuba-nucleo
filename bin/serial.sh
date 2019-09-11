#!/bin/bash

sudo cat /dev/ttyACM0 > results/bench_$1.dat &
CATPID=$!
sleep 1
# TODO: fix to kill just the one cat
sudo killall cat
