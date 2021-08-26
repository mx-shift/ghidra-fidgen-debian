#!/bin/bash

set -e
set -u

if [ $# -lt 3 ]; then
	echo "Usage: $(basename $0) <ghidra-project-dir> <ghidra-project-name> <langspec> <fidb-dir>" >&2
	exit 1
fi

SCRIPT_DIR="$(realpath $(dirname $0))"
GHIDRA_PROJ_DIR="$1"
GHIDRA_PROJ_NAME="$2"
GHIDRA_PROCESSOR="$3"
FIDB_DIR="$4"

if [[ ! $GHIDRA_HOME ]]; then
	echo "Must set \$GHIDRA_HOME, e.g. via:"
	echo "export GHIDRA_HOME=/home/user/ghidra/ghidra_9.0.4"
	exit 1
fi

GHIDRA_HEADLESS="${GHIDRA_HOME}/support/analyzeHeadless"
GHIDRA_SCRIPTS="${SCRIPT_DIR}/ghidra_scripts"

mkdir -p "${FIDB_DIR}"
touch "${GHIDRA_PROJ_DIR}/${GHIDRA_PROJ_NAME}-duplicates.txt"
touch "${GHIDRA_PROJ_DIR}/${GHIDRA_PROJ_NAME}-common.txt"

"${GHIDRA_HEADLESS}" \
	"${GHIDRA_PROJ_DIR}"  "${GHIDRA_PROJ_NAME}" \
	-scriptPath "${GHIDRA_SCRIPTS}" \
    -noanalysis \
	-preScript AutoCreateMultipleLibraries.java \
    "${GHIDRA_PROJ_DIR}/${GHIDRA_PROJ_NAME}-duplicates.txt" \
    true \
    "${FIDB_DIR}" \
	"${GHIDRA_PROJ_NAME}.fidb" \
    "/lib" \
    "${GHIDRA_PROJ_DIR}/${GHIDRA_PROJ_NAME}-common.txt" \
	"${GHIDRA_PROCESSOR}"

