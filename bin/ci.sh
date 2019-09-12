#!/bin/bash

if [[ -f "ci.lock" ]]; then
    # A benchmark is already running
    exit 0
fi

touch ci.lock

cd usuba/

current_commit=`git rev-parse HEAD`
git pull &>/dev/null

new_commits=`git log --pretty=%P $current_commit.. nist/`
new_head=`git rev-parse HEAD`

if [[ "$new_head" == "$current_commit" ]]; then
    # Nothing to be done
    rm -f ../ci.lock

    exit 0
fi

for commit in $new_commits $new_head; do
    short_commit=`git rev-parse --short $commit`
    branch_name="bench-$short_commit"

    echo "Benchmark commit $short_commit"

    git checkout -b $branch_name $commit

    cd ..

    make clean-all
    make
    echo $commit > results/timestamp
    git add results/timestamp
    git add results/*.dat
    git commit -m "Benchmark $short_commit"

    cd usuba/

    git checkout embedded-usuba
    git branch -D $branch_name
    
done

cd ..
git push

rm -f ci.lock
