#!/bin/bash

if [[ -f git ]]; then
    mkdir /opt
    mv git /opt/.
fi

export PATH=$PATH:/opt/git/bin

git clone "$1" --branch "$2" --depth 1 /tmp/chekcout

# https://github.com/static-linux/static-binaries-i386