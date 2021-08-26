#!/bin/bash

set -e
set -u

if [ $# -lt 3 ]; then
	echo "Usage: $(basename $0) <import-dir> <ghidra-project-dir> <ghidra-project-name>" >&2
	exit 1
fi

while getopts "c:p:" OPT; do
	case ${OPT} in
		c)
			GHIDRA_CSPEC="${OPTARG}"
			;;
		p)
			GHIDRA_PROCESSOR="${OPTARG}"
			;;
		\?)
			echo "Invalid option: ${OPTARG}" >&2
			exit 1
			;;
	esac
done
shift $((OPTIND -1))

SCRIPT_DIR="$(realpath $(dirname $0))"
IMPORT_DIR="$1"
GHIDRA_PROJ_DIR="$2"
GHIDRA_PROJ_NAME="$3"

if [[ ! $GHIDRA_HOME ]]; then
	echo "Must set \$GHIDRA_HOME, e.g. via:"
	echo "export GHIDRA_HOME=/home/user/ghidra/ghidra_9.0.4"
	exit 1
fi

GHIDRA_HEADLESS="${GHIDRA_HOME}/support/analyzeHeadless"
GHIDRA_SCRIPTS="${GHIDRA_HOME}/Ghidra/Features/FunctionID/ghidra_scripts"

mkdir -p "${GHIDRA_PROJ_DIR}"

"${GHIDRA_HEADLESS}" \
	"${GHIDRA_PROJ_DIR}"  "${GHIDRA_PROJ_NAME}" \
	${GHIDRA_PROCESSOR:+-processor "${GHIDRA_PROCESSOR}"} \
	${GHIDRA_CSPEC:+-cspec "${GHIDRA_CSPEC}"} \
	-import "${IMPORT_DIR}" -recursive \
	-preScript FunctionIDHeadlessPrescript.java \
	-postScript FunctionIDHeadlessPostscript.java \
  | tee "${GHIDRA_PROJ_DIR}/${GHIDRA_PROJ_NAME}-headless.log"


