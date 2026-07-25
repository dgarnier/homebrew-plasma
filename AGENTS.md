# Agent instructions for dgarnier/homebrew-plasma

A personal Homebrew tap of plasma-physics and fusion codes (MDSplus, VTK/CGNS/NetCDF
with MPI, ASCOT5, FIDASIM, and the M3D-C1 extended-MHD stack). Most formulae are
MPI/Fortran scientific software, which fails in ways ordinary formulae do not.

## Skills

Step-by-step procedures live in [`.agents/skills/`](.agents/skills/) (vendor-neutral;
read them directly, they are plain Markdown):

- [`verify-formula`](.agents/skills/verify-formula/SKILL.md) — the full local
  verification sequence for a formula change, and how to diagnose a failed CI run.
  **Follow this before pushing any formula change.**

## Verifying a change — read this before claiming anything works

Two mistakes have cost real time here. Do not repeat them.

**1. `--build-from-source` does not test bottling.** CI builds bottles; that step has
its own failure modes (rpath rewriting, relocatability). Verify with:

```sh
brew uninstall --force <formula>
brew install --build-bottle <formula>   # not --build-from-source
brew bottle --verbose --json <formula>  # the step CI actually runs
brew test <formula>
```

**2. Assert on outcomes, not artifacts.** A test that checks "the output file exists"
passes while the computation is producing garbage. An `m3dc1` test once passed with
*all 48 MPI ranks emitting NaN*, which hid a scalar-type corruption through two rounds
of "verification". Scientific codes routinely exit 0 after a failed solve. Assert on
convergence markers, error strings, and plausible output size.

Also: **never trust an exit code alone.** `brew test-bot` can print
`Warning: 1 failed step ignored!` and still exit 0. Read the log.

## Testing Linux locally

Most failures in this tap are Linux-only and invisible on macOS. Do not discover them
via CI round trips:

```sh
docker/test-linux.sh <formula> [formula...]
```

This runs the same `brew test-bot --only-formulae` step as the ubuntu-24.04 CI leg, in
~3 min. See [docker/README.md](docker/README.md).

Recurring Linux-only classes:
- **Runtime library resolution.** Linux records a bare `SONAME`; without an explicit
  `-Wl,-rpath` the loader fails with `error while loading shared libraries`. macOS
  records an absolute `install_name`, so it never shows there. Test blocks linking a
  tap library need `-Wl,-rpath,#{lib}`.
- **`brew audit --online`** rejects an unreachable `homepage`. Several scientific
  project pages (e.g. NERSC's) are flaky; prefer the upstream repo URL.
- **Strict linker.** Missing `-lm` and similar are fatal on Linux, silent on macOS.

## Style and audit

```sh
brew style --fix <formula>   # also runs shfmt + shellcheck on shell scripts in the tap
brew audit --online --skip-style <formula>
```

`brew test-bot --only-tap-syntax` lints **shell scripts too**. Install `shellcheck`
locally or those checks silently skip and CI will catch them instead.

Known-benign audit failures go in
[`audit_exceptions/flat_namespace_allowlist.json`](audit_exceptions/flat_namespace_allowlist.json).
Currently `mumps` and `netcdf-fortran-mpi`: open-mpi's Fortran wrapper bakes
`-Wl,-flat_namespace` into its wrapper data and appends it *after* anything the formula
passes, so it cannot be overridden. Needs fixing upstream in open-mpi.

## Commits, PRs, CI

- Commit subject for a new formula must be exactly `<formula> (new formula)` — the
  bottle workflow parses it. Other changes use `<formula>: <description>`.
- Open a PR, let `brew test-bot` run on all four platforms, then label it `pr-pull`
  so CI builds and commits the bottles.
- The matrix has **no `fail-fast: false`**, so one Linux failure cancels the three
  macOS legs. A "failed" macOS job may just be a cancellation — check before
  diagnosing.
- Pushing a fix does not always trigger a new run. If checks look stale, close and
  reopen the PR.

## Formula-specific rules

**Commit-pinned formulae** (no upstream releases): `fidasim`, `m3dc1`, `fusion-io`.
They pin a commit, synthesise a version, and `livecheck { skip }`. `brew bump` will not
help — see the manual bump procedures in [README.md](README.md).

**`pumi` is pinned to the SCOREC/core 2.2.x series. Do not bump to v3/v4.** v3 replaced
the global PCU API with a handle-based one that M3D-C1's bundled `m3dc1_scorec` does not
support; `livecheck`'s regex is deliberately constrained to `2.x`.

**No ParMETIS anywhere.** Its license forbids redistribution, so it can never be
bottled. Parallel orderings come from core `scotch` (PT-Scotch, CeCILL-C, already
bottled). `superlu-dist` builds with `TPL_ENABLE_PARMETISLIB=OFF`; `zoltan` uses its
built-in PHG partitioner; `pumi`'s `FindZoltan` is patched to drop the hard requirement.

**`m3dc1` uses `env :std` and this is load-bearing — do not remove it.** It depends on
both `petsc-m3dc1` and `petsc-complex-m3dc1`, and superenv injects a `-I`/`-L` for every
dependency in dependency order. `petsc-complex-m3dc1` sorts first, so its `petscconf.h`
(`PETSC_USE_COMPLEX`) and `libpetsc` won for the **real** build too — turning every
solve into silent NaN. Consequences of leaving superenv, both handled in the formula:
- rpaths must be supplied explicitly, **Linux only** (on macOS extra `LC_RPATH` entries
  exhaust Mach-O header space during bottling: `Failed changing rpath in ...`);
- `ENV.deparallelize` must be called **with a block** (Stdenv's Sorbet signature
  declares it non-nilable, unlike Superenv's).

**M3D-C1 runs need #ranks == #mesh parts.** For 2D (`nplanes=1`), fewer parts than
ranks deadlocks in PUMI's collective barrier. Sample pre-split meshes ship in
`share/m3dc1/regtest`. Mesh *generation* needs commercial Simmetrix and is not included.

**Beware dirty working directories** when comparing solver behaviour: `C1input` sets
`iread_hdf5 = 1`, so leftover output changes the result. Use a fresh directory per run.
