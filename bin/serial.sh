#!/bin/bash

sudo cat -v /dev/ttyACM0 > $1 &
sleep 1
# Get the pid of `cat` (not `sudo cat`)
CATPID=`ps --ppid $! -o pid=`
sleep 4
# Kill the cat!
sudo kill $CATPID
