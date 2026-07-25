#!/usr/bin/env bash
# Runs inside the container. Copies the read-only tap mount into Homebrew's
# Taps directory (so the host repo is never modified), then runs the same
# test-bot step that CI runs.
set -euo pipefail

TAP_USER=dgarnier
TAP_REPO=homebrew-plasma
TAP_PATH="$(brew --repository)/Library/Taps/${TAP_USER}/${TAP_REPO}"

if [[ ! -d /tap ]]
then
  echo "error: expected the tap to be mounted read-only at /tap" >&2
  exit 1
fi

mkdir -p "$(dirname "${TAP_PATH}")"
rm -rf "${TAP_PATH}"
cp -R /tap "${TAP_PATH}"
git config --global --add safe.directory "${TAP_PATH}" 2>/dev/null || true

# Homebrew refuses to load formulae from a third-party tap until it is trusted.
brew trust --tap "${TAP_USER}/plasma"

if [[ $# -eq 0 ]]
then
  echo "usage: docker/test-linux.sh <formula> [formula...]" >&2
  echo "   or: docker/test-linux.sh --shell        (interactive shell)" >&2
  exit 2
fi

if [[ "$1" == "--shell" ]]
then
  exec bash -l
fi

status=0
for f in "$@"
do
  echo
  echo "════════════════════════════════════════════════════════════════"
  echo "  ${TAP_USER}/plasma/${f}"
  echo "════════════════════════════════════════════════════════════════"
  log="/tmp/test-bot-${f}.log"

  # Mirrors `brew test-bot --only-formulae` in CI: build from source, run the
  # test block, and audit (including the --online checks that catch things like
  # an unreachable homepage).
  rc=0
  brew test-bot --only-formulae --skip-dependents "${TAP_USER}/plasma/${f}" \
    2>&1 | tee "${log}" || rc=$?

  # test-bot's exit status alone is not trustworthy: it can report
  # "Warning: 1 failed step ignored!" and still exit 0, which would look like a
  # pass. Scan the output for the failure markers it prints as well.
  if grep -qE "did not build|failed step|^Error: |==> FAILED" "${log}"
  then
    rc=1
  fi

  if [[ ${rc} -ne 0 ]]
  then
    echo "==> FAILED: ${f}"
    status=1
  else
    echo "==> PASSED: ${f}"
  fi
done

echo
if [[ ${status} -eq 0 ]]
then
  echo "All formulae passed."
else
  echo "One or more formulae FAILED."
fi
exit "${status}"
