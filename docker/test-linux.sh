#!/usr/bin/env bash
# Test this tap's formulae on Linux locally, reproducing the ubuntu-24.04 leg
# of CI. Requires Docker (or OrbStack).
#
#   docker/test-linux.sh mumps
#   docker/test-linux.sh mumps superlu-dist
#   docker/test-linux.sh --shell                 # poke around interactively
#
# Environment:
#   PLATFORM=linux/arm64   test on arm64 instead of amd64 (faster on Apple
#                          Silicon, but does not match CI's x86_64 runner)
#   REBUILD=1              force a rebuild of the image layer
set -euo pipefail

TAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLATFORM="${PLATFORM:-linux/amd64}"
IMAGE="homebrew-plasma-test:${PLATFORM##*/}"

build_args=()
[[ -n "${REBUILD:-}" ]] && build_args+=(--no-cache)

docker build --platform "$PLATFORM" -t "$IMAGE" \
  "${build_args[@]}" "$TAP_DIR/docker"

exec docker run --rm -it --platform "$PLATFORM" \
  -v "$TAP_DIR:/tap:ro" \
  "$IMAGE" "$@"
