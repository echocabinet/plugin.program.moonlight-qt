#!/bin/bash

set -e

# Figure out which build is needed based on LibreELEC platform data
if [ "$PLATFORM_ARCH" = "armv7l" ]; then
  BUILD_FLAVOR="arm"
  BUILD_ARCH="arm"
elif [ "$PLATFORM_ARCH" = "aarch64" ]; then
  BUILD_FLAVOR="arm"
  BUILD_ARCH="arm64"
elif [ "$PLATFORM_ARCH" = "x86_64" ]; then
  BUILD_FLAVOR="amd64"
  BUILD_ARCH="amd64"
fi

# Use specific platform for Raspberry Pi builds, override the default ARM flavor
if [ "$PLATFORM" = "rpi" ]; then
  BUILD_FLAVOR="rpi"
fi

LOCAL_PATH=${TMP_PATH:-/tmp/moonlight-qt/${BUILD_PLATFORM}/}

if [ ! -f "Dockerfile.${BUILD_FLAVOR}" ]; then
  echo "Sorry, LibreELEC platform ${PLATFORM_ARCH} currently not supported!"
  exit 1
else
  echo "Building ${PLATFORM_ARCH} with ${BUILD_FLAVOR} using arch ${BUILD_ARCH}..."
fi

# Use older Debian releases for older LibreELEC versions
if [ "${PLATFORM_DISTRO_RELEASE%%.*}" -le 10 ]; then
  # Use Debian bullseye on LibreELEC 10 and lower
  BUILD_ARG="--build-arg DEBIAN_RELEASE=bullseye"
fi

GHCR_IMAGE="ghcr.io/echocabinet/plugin.program.moonlight-qt:latest"

# Clean up any previous container/image
docker rm --force moonlight-qt &> /dev/null || true
docker rmi --force moonlight-qt &> /dev/null || true

# Try pulling the pre-built image from GHCR — much faster than building locally.
# Falls back to a local build if the pull fails (offline, image not yet published, etc).
if docker pull --platform "linux/${BUILD_ARCH}" "$GHCR_IMAGE" 2>/dev/null; then
  echo "Using pre-built image from GHCR."
  docker tag "$GHCR_IMAGE" moonlight-qt
else
  echo "GHCR pull failed or unavailable — building locally (this will take a while)..."
  docker build --file "./Dockerfile.${BUILD_FLAVOR}" --compress --tag moonlight-qt --platform "linux/${BUILD_ARCH}" $BUILD_ARG .
fi

# Run and get files
mkdir -p "$LOCAL_PATH"
docker run --volume "$LOCAL_PATH":/tmp/moonlight-qt moonlight-qt

# Clean up
docker rm --force moonlight-qt &> /dev/null || true
docker rmi --force moonlight-qt &> /dev/null || true
docker container prune --force
docker image prune --force
