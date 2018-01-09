#!/bin/bash

msg="1 2 3
4 5 6"

msg=`echo "$msg" | awk '{print "\""$0"\""}'`
echo "$msg"

for i in "$msg"; do
    echo --
    echo $i
done

