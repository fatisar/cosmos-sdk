#!/bib/bash

set -euo pipefail

f_main() {
  local l_workdir \
    l_gitian \
    l_sdk \
    l_commit \
    l_platform

  l_platform=$1
  l_workdir=`mktemp -d gitian-build-${l_platform}-XXXXX`
  echo "Work directory: ${l_workdir}" >&2
  pushd ${l_workdir}
  git clone -b alessio/reproducible-builds git@github.com:cosmos/cosmos-sdk.git
  l_sdk="$(pwd)/cosmos-sdk"
  git clone https://github.com/devrandom/gitian-builder
  l_gitian="$(pwd)/gitian-builder"
  pushd ${l_sdk}
  l_commit=$(git rev-parse HEAD)
  popd

  f_prep_docker_image "${l_gitian}"
  f_download_go "${l_gitian}"

  f_build "${l_gitian}" "${l_sdk}" "${l_commit}" "${l_platform}"
  echo "You may find the result in ${l_gitian}/result" >&2
  return 0
}

f_prep_docker_image() {
  local l_dir=$1

  pushd ${l_dir}
  bin/make-base-vm --docker --suite bionic --arch amd64
  popd
}

f_download_go() {
  local l_dir l_gopkg

  l_dir=$1

  mkdir -p ${l_dir}/inputs
  l_gopkg=go1.12.4.linux-amd64.tar.gz
  curl -L https://dl.google.com/go/${l_gopkg} > ${l_dir}/inputs/${l_gopkg}
}

f_build() {
  local l_gitian l_sdk l_platform l_descriptor

  l_gitian=$1
  l_sdk=$2
  l_commit=$3
  l_platform=$4
  l_descriptor=$l_sdk/cmd/gaia/contrib/gitian-descriptors/gitian-${l_platform}.yml

  [ -f ${l_descriptor} ]

  cd ${l_gitian}
  export USE_DOCKER=1
  bin/gbuild $l_descriptor --commit cosmos-sdk=$l_commit
  libexec/stop-target || echo "warning: couldn't stop target" >&2
}

f_main $1