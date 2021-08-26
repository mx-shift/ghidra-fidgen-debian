#!/usr/bin/env bash

set -e
set -u

if [ $# -lt 1 ]; then
    echo "Usage: $(basename $0) <pkg-glob> [<pkg-glob> ...]" >&2
    exit 1
fi

for PKG in $(apt-cache show "$@" | grep-dctrl -s Package -n - | xargs apt-rdepends -s=None | sort -u); do
    for VERSION in $(apt-cache show ${PKG} | grep-dctrl -s Version -n -); do
        apt-get download ${PKG}=${VERSION}
    done
done