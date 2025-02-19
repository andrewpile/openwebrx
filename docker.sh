#!/usr/bin/env bash
set -euo pipefail

ARCH=$(uname -m)
# IMAGES="openwebrx-rtlsdr openwebrx-sdrplay openwebrx-hackrf openwebrx-airspy openwebrx-rtlsdr-soapy openwebrx-plutosdr openwebrx-limesdr openwebrx-soapyremote openwebrx-perseus openwebrx-fcdpp openwebrx-radioberry openwebrx-uhd openwebrx-rtltcp openwebrx-runds openwebrx-hpsdr openwebrx-bladerf openwebrx-full openwebrx"
IMAGES="openwebrx-rtlsdr openwebrx-hackrf openwebrx-rtlsdr-soapy openwebrx-soapyremote openwebrx-perseus openwebrx-rtltcp openwebrx-full openwebrx"
ALL_ARCHS="x86_64 armv7l aarch64"
# ALL_ARCHS="x86_64"
TAG=${TAG:-"latest"}
ARCHTAG="${TAG}-${ARCH}"

usage () {
  echo "Usage: ${0} [command]"
  echo "Available commands:"
  echo "  help       Show this usage information"
  echo "  build      Build all docker images"
  echo "  push       Push built docker images to the docker hub"
  echo "  manifest   Compile the docker hub manifest (combines arm and x86 tags into one)"
  echo "  tag        Tag a release"
}

build () {
  # build the base images
  docker build --pull -t openwebrx-base:${ARCHTAG} -f docker/Dockerfiles/Dockerfile-base .
  docker build --build-arg ARCHTAG=${ARCHTAG} -t openwebrx-soapysdr-base:${ARCHTAG} -f docker/Dockerfiles/Dockerfile-soapysdr .

  for image in ${IMAGES}; do
    i=${image:10}
    # "openwebrx" is a special image that gets tag-aliased later on
    if [[ ! -z "${i}" ]] ; then
      docker build --build-arg ARCHTAG=$ARCHTAG -t aaapppp/${image}:${ARCHTAG} -f docker/Dockerfiles/Dockerfile-${i} .
    fi
  done

  # tag openwebrx alias image
  docker tag aaapppp/openwebrx-full:${ARCHTAG} aaapppp/openwebrx:${ARCHTAG}
}

push () {
  for image in ${IMAGES}; do
    docker push aaapppp/${image}:${ARCHTAG}
  done
}

manifest () {
  for image in ${IMAGES}; do
    # there's no docker manifest rm command, and the create --amend does not work, so we have to clean up manually
    rm -rf "${HOME}/.docker/manifests/docker.io_aaapppp_${image}-${TAG}"
    IMAGE_LIST=""
    for a in ${ALL_ARCHS}; do
      IMAGE_LIST="${IMAGE_LIST} aaapppp/${image}:${TAG}-${a}"
    done
    docker manifest create aaapppp/${image}:${TAG} ${IMAGE_LIST}
    docker manifest push --purge aaapppp/${image}:${TAG}
  done
}

tag () {
  if [[ -x ${1:-} || -z ${2:-} ]] ; then
    echo "Usage: ${0} tag [SRC_TAG] [TARGET_TAG]"
    return
  fi

  local SRC_TAG=${1}
  local TARGET_TAG=${2}

  for image in ${IMAGES}; do
    # there's no docker manifest rm command, and the create --amend does not work, so we have to clean up manually
    rm -rf "${HOME}/.docker/manifests/docker.io_aaapppp_${image}-${TARGET_TAG}"
    IMAGE_LIST=""
    for a in ${ALL_ARCHS}; do
      docker pull aaapppp/${image}:${SRC_TAG}-${a}
      docker tag aaapppp/${image}:${SRC_TAG}-${a} aaapppp/${image}:${TARGET_TAG}-${a}
      docker push aaapppp/${image}:${TARGET_TAG}-${a}
      IMAGE_LIST="${IMAGE_LIST} aaapppp/${image}:${TARGET_TAG}-${a}"
    done
    docker manifest create aaapppp/${image}:${TARGET_TAG} ${IMAGE_LIST}
    docker manifest push --purge aaapppp/${image}:${TARGET_TAG}
    docker pull aaapppp/${image}:${TARGET_TAG}
  done
}

case ${1:-} in
  build)
    build
    ;;
  push)
    push
    ;;
  manifest)
    manifest
    ;;
  tag)
    tag ${@:2}
    ;;
  *)
    usage
    ;;
esac