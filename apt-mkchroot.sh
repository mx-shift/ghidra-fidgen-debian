#!/usr/bin/env bash

set -e
set -u

APT_ARCH=$(dpkg --print-architecture)

while getopts "a:" OPT; do
    case ${OPT} in
        a)
            APT_ARCH=${OPTARG}
            ;;
        \?)
            echo "Invalid option: ${OPTARG}" >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND -1))

if [ $# -lt 1 ]; then
    echo "Usage: $(basename "$0") [-a <arch>] [-A <arch>] <dir> [<template>]" >&2
    exit 1
fi

APT_ROOT="$(realpath "$1")"
APT_TEMPLATE_ROOT="${2:+$(realpath $2)}"

if [ -e "${APT_ROOT}" ]; then
    echo "Error: ${APT_ROOT} already exists" >&2
    exit 1
fi

if ! [ -z "${APT_TEMPLATE_ROOT}" -o -d "${APT_TEMPLATE_ROOT}" ]; then
    echo "Error: Template directory does not exist: ${APT_TEMPLATE_ROOT}" >&2
    exit 1
fi

if ! [ -f "${APT_TEMPLATE_ROOT}/sources.list" -o -d "${APT_TEMPLATE_ROOT}/sources.list.d" ]; then
    echo "Error: Template directory is missing sources.list or sources.list.d" >&2
    exit 1
fi


for DIR in \
    etc/apt \
    etc/apt/apt.conf.d \
    etc/apt/preferences.d \
    etc/apt/trusted.gpg.d \
    etc/apt/sources.list.d \
    var/cache/apt/archives/partial \
    var/lib/apt/lists/partial \
    var/lib/dpkg
do
    mkdir -p "${APT_ROOT}/${DIR}"
done

cat > "${APT_ROOT}/etc/apt/sources.list" <<EOF
# Supported releases are at http://archive.ubuntu.com/ubuntu

#deb http://archive.ubuntu.com/ubuntu focal main restricted
#deb-src http://archive.ubuntu.com/ubuntu focal main restricted

# Archived released are at http://old-releases.ubuntu.com/ubuntu/.
#
# As many are signed with keys no longer in the released GPG keyrings,
# [trusted=yes] is used to implicitly disable checking of signatures

#deb [trusted=yes] http://old-releases.ubuntu.com/ubuntu/ precise main
#deb-src [trusted=yes] http://old-releases.ubuntu.com/ubuntu/ precise main
EOF

touch "${APT_ROOT}/var/lib/dpkg/status"

cat > "${APT_ROOT}/etc/apt/apt.conf" <<EOF
Dir "${APT_ROOT}";

Apt {
    Architecture "${APT_ARCH}";
    Architectures "${APT_ARCH}";
};
EOF

if [ -n "${APT_TEMPLATE_ROOT}" ]; then
    for FILE in sources.list; do
        if [ -f "${APT_TEMPLATE_ROOT}/${FILE}" ]; then
            cp "${APT_TEMPLATE_ROOT}/${FILE}" "${APT_ROOT}/etc/apt/${FILE}"
        fi
    done

    for DIR in preferences.d sources.list.d trusted.gpg.d; do
        if [ -d "${APT_TEMPLATE_ROOT}/${DIR}" ]; then
            cp -r "${APT_TEMPLATE_ROOT}/${DIR}/" "${APT_ROOT}/etc/apt/${DIR}/"
        fi
    done
fi