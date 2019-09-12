#!/bin/bash

sudo cat /dev/ttyACM0 > results/bench_$1.dat &
sleep 1
# Get the pid of `cat` (not `sudo cat`)
CATPID=`ps --ppid $! -o pid=`
sleep 4
# Kill the cat!
sudo kill $CATPID
