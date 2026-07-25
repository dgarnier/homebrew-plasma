# Testing this tap on Linux locally

Several formulae in this tap have hit Linux-only CI failures (runtime library
resolution, unreachable homepages) that don't reproduce on macOS. Waiting for
GitHub Actions costs ~4 minutes per attempt. This runs the same check locally.

## Usage

```sh
docker/test-linux.sh mumps
docker/test-linux.sh mumps superlu-dist
docker/test-linux.sh --shell            # interactive poke-around
```

Exit status is 0 if every formula passed, 1 otherwise.

Requires Docker or [OrbStack](https://orbstack.dev).

### Options

| Variable | Effect |
|---|---|
| `PLATFORM=linux/arm64` | Test arm64 instead of amd64. Faster on Apple Silicon, but does **not** match CI's x86_64 runner. |
| `REBUILD=1` | Rebuild the image from scratch (e.g. to pick up newer bottles). |

## What it actually runs

`brew test-bot --only-formulae`, which is the exact CI step that fails — it
builds from source, runs the `test do` block, audits (including the `--online`
checks that catch an unreachable `homepage`), and builds a bottle.

The base image is `ghcr.io/homebrew/ubuntu24.04`, matching the `ubuntu-24.04`
leg of [`.github/workflows/tests.yml`](../.github/workflows/tests.yml), and the
environment mirrors that workflow (notably `HOMEBREW_NO_SANDBOX_LINUX=1`).

Common dependencies (`gcc`, `open-mpi`, `metis`, `scalapack`, `openblas`,
`scotch`, `hdf5-mpi`, `fftw`, `gsl`) are baked into an image layer, so iterating
on a formula does not re-pour the whole stack. They all have `x86_64_linux`
bottles in homebrew-core, so building the image is a download rather than a
compile.

The tap is mounted **read-only** at `/tap` and copied into place inside the
container, so a run can never modify your working tree — you can test
uncommitted changes freely.

## Validation

This harness was checked in both directions against the `superlu-dist` history:

- at the pre-fix commit it exits 1 and reproduces both real CI failures — the
  unreachable NERSC homepage and `libsuperlu_dist.so.9: cannot open shared
  object file`
- at the fixed version it exits 0 and completes install → test → bottle

## Caveats

- `linux/amd64` on Apple Silicon runs under emulation. It is fine for these
  formulae, but a large build (e.g. PETSc) is noticeably slower than native.
- This covers the `ubuntu-24.04` leg only. The macOS legs of CI still have to
  run on GitHub.
- Homebrew 6 refuses to load formulae from an untrusted tap, so the container
  runs `brew trust --tap dgarnier/plasma` before testing.
