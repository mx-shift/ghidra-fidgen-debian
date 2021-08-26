#!/usr/bin/env bash

set -e
set -u
# set -x

if [ $# -lt 2 ]; then
    # echo "Usage: $(basename $0) <work-dir> <apt-chroot-template> <pkg> [<pkg> ...]" >&2
    echo "Usage: $(basename $0) [-g <ghidra_dir> ] [-l <langspec> ] [-o <outfile> ] <distro> <release> <arch> <pkg> [<pkg> ...]" >&2
    exit 1
fi

SCRIPT_DIR="$(dirname $(realpath $0))"

GHIDRA_HOME=
OUTFILE=
TARGET_LANGSPEC=
while getopts "g:l:o:" OPT; do
    case ${OPT} in
        g)
            GHIDRA_HOME=${OPTARG}
            ;;
        l)
            TARGET_LANGSPEC=${OPTARG}
            ;;
        o)
            OUTFILE=${OPTARG}
            ;;
        \?)
            echo "Error: unknown option: ${OPT}" >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND - 1))

TARGET_DISTRO="$1"
TARGET_RELEASE="$2"
TARGET_ARCH="$3"
shift 3

TARGET_TUPLE=${TARGET_DISTRO}-${TARGET_RELEASE}-${TARGET_ARCH}

if [ -z "${GHIDRA_HOME}" ]; then
    GHIDRA_HOME="$(which ghidraRun || true)"
fi
if [ -z "${GHIDRA_HOME}" ]; then
    echo "Error: Unable to find Ghidra.  Please pass -g" >&2
    exit 1
fi

if [ -z "${TARGET_LANGSPEC}" ]; then
    case ${TARGET_ARCH} in
        i386)
            TARGET_LANGSPEC="x86:LE:32:default"
            ;;
        amd64)
            TARGET_LANGSPEC="x86:LE:64:default"
            ;;
        *)
            echo "Error: Ghidra langspec unknown for target architecture: ${TARGET_ARCH}" >&2
            echo "Try setting -l to a Ghidra langspec" >&2
            exit 1
            ;;
    esac
fi

if [ -z "${OUTFILE}" ]; then
    OUTFILE=${TARGET_TUPLE}.fidb
fi

DISTRO_CONFIG_DIR="${SCRIPT_DIR}/distro_config/${TARGET_DISTRO}/${TARGET_RELEASE}"
if [ ! -d "${DISTRO_CONFIG_DIR}" ]; then
    echo "Error: Unknown release \"${TARGET_RELEASE}\" of distro \"${TARGET_DISTRO}\"" >&2
    exit 1
fi

WORK_DIR="$(realpath $(mktemp -d -p . work.${TARGET_TUPLE}.XXXXXXXX))"
WORK_APT_DIR="${WORK_DIR}/apt"
WORK_DEB_DIR="${WORK_DIR}/deb"
WORK_LIB_DIR="${WORK_DIR}/lib"
WORK_GHIDRA_DIR="${WORK_DIR}/ghidra"
WORK_FIDB_DIR="${WORK_DIR}/fidb"

# Create APT chroot
${SCRIPT_DIR}/apt-mkchroot.sh -a "${TARGET_ARCH}" "${WORK_APT_DIR}" "${DISTRO_CONFIG_DIR}"

# Use APT chroot from now on
export APT_CONFIG="${WORK_APT_DIR}/etc/apt/apt.conf"

apt-get update

# Download all packages that match the globs and all their dependencies.
mkdir -p "${WORK_DEB_DIR}"
(cd ${WORK_DEB_DIR}; ${SCRIPT_DIR}/apt-rdownload.sh "$@")

# For each downloaded deb, extract only .a and .o
find "${WORK_DEB_DIR}" -name \*.deb | while read CUR_DEB; do
    CUR_DEB_NAME="$(dpkg-deb -f "${CUR_DEB}" Package)"
    CUR_DEB_VERSION="$(dpkg-deb -f "${CUR_DEB}" Version)"
    CUR_DEB_VARIANT="$(dpkg-deb -f "${CUR_DEB}" Architecture)"
    CUR_DEB_WORKDIR="${WORK_LIB_DIR}/${CUR_DEB_NAME}/${CUR_DEB_VERSION}/${CUR_DEB_VARIANT}"

    mkdir -p "${CUR_DEB_WORKDIR}"
    dpkg-deb --fsys-tarfile "${CUR_DEB}" \
        | tar \
            --wildcards \
            --no-anchor \
            --transform='s,.*/,,' \
            -C "${CUR_DEB_WORKDIR}" \
            -x \*.[ao] \
    || rmdir "${CUR_DEB_WORKDIR}"
done

# Prune any empty directories from debs that didn't have static archives or objects
find "${WORK_LIB_DIR}" -empty -type d -delete

# Clean up any symlinks
find "${WORK_LIB_DIR}" -type l -delete

# Extract .o's from .a's because Ghidra's headless importer doesn't handle them currently
find "${WORK_LIB_DIR}" -name \*.a -execdir ar x {} \; -delete

export GHIDRA_HOME

${SCRIPT_DIR}/ghidra-import.sh "${WORK_LIB_DIR}" "${WORK_GHIDRA_DIR}" "${TARGET_TUPLE}"

${SCRIPT_DIR}/ghidra-generate-fidb.sh "${WORK_GHIDRA_DIR}" "${TARGET_TUPLE}" "${TARGET_LANGSPEC}" "${WORK_FIDB_DIR}"

cp "${WORK_FIDB_DIR}/${TARGET_TUPLE}.fidb" "${OUTFILE}"
