#!/bin/bash

sudo cat -v /dev/ttyACM0 > $1 &
sleep 1
# Get the pid of `cat` (not `sudo cat`)
CATPID=`ps --ppid $! -o pid=`
timeout 20 sh -c 'while [[ `wc -l $1` < 3 ]]; do sleep 1; done'
# Kill the cat!
sudo kill $CATPID
