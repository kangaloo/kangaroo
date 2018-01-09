#!/bin/bash

workdir="$(dirname $0)"
basedir="${workdir}/.."
libdir="${basedir}/lib"
logdir="${basedir}/log"


# source all functions
if [ -d $libdir ]; then
    source "$libdir/functions"
    source "$libdir/multiprocess"
fi

if [ ! -d $logdir ]; then
    mkdir -p $logdir
fi

logs "hello"
err "hello"

