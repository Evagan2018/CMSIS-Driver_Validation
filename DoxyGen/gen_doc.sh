#!/bin/bash
# Version: 1.1
# Date: 2022-11-07
# This bash script generates CMSIS-Driver Documentation:
#
# Pre-requisites:
# - bash shell (for Windows: install git for Windows)
# - doxygen 1.13.2
# - git

set -o pipefail

DIRNAME=$(dirname $(realpath $0))
DOXYGEN=$(which doxygen)
REQ_DXY_VERSION="1.13.2"
REQUIRED_GEN_PACK_LIB="0.11.3"

############ gen-pack library ###########

function install_lib() {
  local URL="https://github.com/Open-CMSIS-Pack/gen-pack/archive/refs/tags/v$1.tar.gz"
  echo "Downloading gen_pack lib to '$2'"
  mkdir -p "$2"
  curl -L "${URL}" -s | tar -xzf - --strip-components 1 -C "$2" || exit 1
}

function load_lib() {
  if [[ -d ${GEN_PACK_LIB} ]]; then
    . "${GEN_PACK_LIB}/gen-pack"
    return 0
  fi
  local GLOBAL_LIB="/usr/local/share/gen-pack/${REQUIRED_GEN_PACK_LIB}"
  local USER_LIB="${HOME}/.local/share/gen-pack/${REQUIRED_GEN_PACK_LIB}"
  if [[ ! -d "${GLOBAL_LIB}" && ! -d "${USER_LIB}" ]]; then
    echo "Required gen-pack lib not found!" >&2
    install_lib "${REQUIRED_GEN_PACK_LIB}" "${USER_LIB}"
  fi

  if [[ -d "${GLOBAL_LIB}" ]]; then
    . "${GLOBAL_LIB}/gen-pack"
  elif [[ -d "${USER_LIB}" ]]; then
    . "${USER_LIB}/gen-pack"
  else
    echo "Required gen-pack lib is not installed!" >&2
    exit 1
  fi
}

load_lib
find_git

#########################################

if [[ ! -f "${DOXYGEN}" ]]; then
  echo "Doxygen not found!" >&2
  echo "Did you miss to add it to PATH?"
  exit 1
else
  version=$("${DOXYGEN}" --version | sed -E 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
  echo "DOXYGEN is ${DOXYGEN} at version ${version}"
  if [[ "${version}" != "${REQ_DXY_VERSION}" ]]; then
    echo " >> Version is different from ${REQ_DXY_VERSION} !" >&2
  fi
fi

if [ -z "$VERSION" ]; then
  VERSION_FULL=$(git_describe)
  VERSION=${VERSION_FULL%+*}
else
  VERSION_FULL=${VERSION}
fi

echo "Generating documentation ..."

pushd $DIRNAME > /dev/null

rm -rf ${DIRNAME}/../Documentation/html
sed -e "s/{projectNumber}/${VERSION}/" "${DIRNAME}/CMSIS_DV.dxy.in" \
  > "${DIRNAME}/CMSIS_DV.dxy"

PACK_CHANGELOG_MODE="tag"
DEV=$(pdsc_release_desc "${DIRNAME}/../ARM.CMSIS-Driver_Validation.pdsc")
git_changelog -f html -d "${DEV}" > src/history.txt

echo "${DOXYGEN} CMSIS_DV.dxy"
"${DOXYGEN}" CMSIS_DV.dxy
popd > /dev/null

if [[ $2 != 0 ]]; then
  cp -f "${DIRNAME}/templates/search.css" "${DIRNAME}/../Documentation/html/search/"
fi

projectName=$(grep -E "PROJECT_NAME\s+=" "${DIRNAME}/CMSIS_DV.dxy" | sed -r -e 's/[^"]*"([^"]+)"/\1/')
datetime=$(date -u +'%a %b %e %Y %H:%M:%S')
year=$(date -u +'%Y')
if [[ "${year}" != "2022" ]]; then
  year="2022-${year}"
fi
sed -e "s/{datetime}/${datetime}/" "${DIRNAME}/templates/footer.js.in" \
  | sed -e "s/{year}/${year}/" \
  | sed -e "s/{projectName}/${projectName}/" \
  | sed -e "s/{projectNumber}/${VERSION}/" \
  | sed -e "s/{projectNumberFull}/${VERSION_FULL}/" \
  > "${DIRNAME}/../Documentation/html/footer.js"

exit 0