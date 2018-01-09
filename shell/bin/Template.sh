#!/bin/bash

# basedir=$(cd "`dirname $0`/.." && pwd) 
workdir="$(dirname $0)"
basedir="${workdir}/.."
libdir="${basedir}/lib"
logdir="${basedir}/log"

if [ ! -d $logdir ]; then
    mkdir -p $logdir
fi

# source all functions
if [ -d $libdir ]; then
    for file in $(ls $libdir); do
        source "$libdir/$file"
    done
fi

logs "hello"
err "hello"

