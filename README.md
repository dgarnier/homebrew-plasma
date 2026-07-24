# Darren's  Plasma Homebrew Tap


## How do I install these formulae?

Just install from the tap, or use the whole tap.  Given recent changes in brew, you will also need to "trust" this repository.


```sh
brew install dgarnier/plasma/<formula>
brew trust dgarnier/plasmas/<formula>
```

Or 

```sh
brew tap dgarnier/plasma
brew trust dgarnier/plasma
brew install <formula>
```

Or, in a `brew bundle` `Brewfile`:

```ruby
tap "dgarnier/plasma"
brew "<formula>"
```

## The M3D-C1 stack

[M3D-C1](https://github.com/PrincetonUniversity/M3DC1) is a PPPL extended-MHD
code for fusion plasmas. It is packaged here in two mutually-exclusive builds
that ride homebrew-core's PETSc:

- **`m3dc1`** — real / nonlinear builds (`m3dc1_2d`, `m3dc1_3d`, `m3dc1_3d_st`),
  links `petsc`.
- **`m3dc1-complex`** — complex / linear-stability build (`m3dc1_2d_complex`),
  links `petsc-complex`.

They conflict with each other because homebrew-core's `petsc` and
`petsc-complex` conflict, so install only one at a time.

Supporting formulae added for this stack:

- **`zoltan`** — Sandia parallel partitioner (built without ParMETIS; uses its
  built-in PHG partitioner).
- **`pumi`** — SCOREC/core Parallel Unstructured Mesh Infrastructure. Pinned to
  the **2.2.x** series: SCOREC v3+ switched to a handle-based PCU API that
  M3D-C1's bundled `m3dc1_scorec` does not yet support.
- **`fusion-io`** — [nferraro/fusion-io](https://github.com/nferraro/fusion-io),
  the I/O / field-line-tracing library used to post-process M3D-C1 output, plus
  its `fpy` Python bindings.
- **`netcdf-mpi`** now also builds the parallel NetCDF **Fortran** bindings
  (`libnetcdff`, needed by the 3D stellarator build).

### Limitations

- **No mesh generation.** `m3dc1_meshgen` needs the commercial Simmetrix
  SimModSuite and is not built. Generate equilibrium-fitted meshes on an HPC
  system, or build simple structured meshes with the `pumi` utilities
  (`mkmodel`, `split`, `zsplit`) and M3D-C1's `create_mesh.sh` / `part_mesh.sh`.
- **No distributed direct solves.** homebrew-core's PETSc has no MUMPS or
  SuperLU_dist. M3D-C1's 2D matrices are `MATMPIAIJ`, which the built-in
  `petsc` LU can't factor directly, so wrap it in a redundant PC
  (`-pc_type redundant -redundant_pc_type lu -redundant_pc_factor_mat_solver_type petsc`)
  instead of the `superlu_dist` / `mumps` settings in M3D-C1's stock options
  files.

### Running the regression tests

Sample cases (with pre-partitioned meshes) install to
`$(brew --prefix m3dc1)/share/m3dc1/regtest`. To run one against the brewed
binaries, e.g. KPRAD_2D on a single rank:

```sh
cd $(mktemp -d)
cp -r "$(brew --prefix m3dc1)/share/m3dc1/regtest/KPRAD_2D/base/." .
cp analytic-2K0.smb part0.smb   # m3dc1 expects part<rank>.smb
mpirun -np 1 m3dc1_2d -pc_type redundant -redundant_pc_type lu \
  -redundant_pc_factor_mat_solver_type petsc
```

## Documentation

`brew help`, `man brew` or check [Homebrew's documentation](https://docs.brew.sh).

## Development

To check for new upstream versions do:
```sh
brew livecheck --tap dgarnier/plasma
```

To bump the version of these formulas do:
```sh
brew bump --open-pr <formula>
```
and then follow up by changing the created pr to have the label "pr-pull".

### Bumping fidasim (manual)

FIDASIM has had no tagged release since 2020, so the formula pins a master
commit and `brew livecheck`/`brew bump` deliberately skip it. To bump it:

1. Find the new commit on [D3DEnergetic/FIDASIM](https://github.com/D3DEnergetic/FIDASIM/commits/master)
   and note its full SHA and commit date.
2. Get the tarball checksum:
   ```sh
   curl -sL https://github.com/D3DEnergetic/FIDASIM/archive/<full-sha>.tar.gz | shasum -a 256
   ```
3. In `Formula/fidasim.rb` update three lines:
   - `url` — the new full SHA
   - `version` — `3.0.0.devYYYYMMDD` from the commit date (also names the Python wheel)
   - `sha256` — from step 2
4. Sanity check and build:
   ```sh
   brew style dgarnier/plasma/fidasim && brew audit dgarnier/plasma/fidasim
   brew reinstall --build-from-source dgarnier/plasma/fidasim && brew test fidasim
   ```
5. Open a PR and label it "pr-pull" so CI builds the bottle.

### Bumping m3dc1 / m3dc1-complex (manual)

M3D-C1 has no tagged releases, so both formulae pin the same master commit and
skip `livecheck`. **Bump them together** — they must stay on the same commit.

1. Find the new commit on
   [PrincetonUniversity/M3DC1](https://github.com/PrincetonUniversity/M3DC1/commits/master);
   note the full SHA and commit date.
2. Checksum the tarball:
   ```sh
   curl -sL https://github.com/PrincetonUniversity/M3DC1/archive/<full-sha>.tar.gz | shasum -a 256
   ```
3. In **both** `Formula/m3dc1.rb` and `Formula/m3dc1-complex.rb` update `url`,
   `version` (`1.NN.devYYYYMMDD`, tracking `unstructured/release_version`), and
   `sha256`. If PETSc has moved to a new minor in homebrew-core, also update
   `PETSC_VERSION_DEFINE` and rebuild — the source guards on this macro and a
   too-new PETSc is the most likely break.
4. Build and test both:
   ```sh
   brew reinstall --build-from-source dgarnier/plasma/m3dc1 && brew test m3dc1
   brew uninstall petsc && brew install petsc-complex   # swap real -> complex
   brew reinstall --build-from-source dgarnier/plasma/m3dc1-complex && brew test m3dc1-complex
   ```
5. Open a PR and label it "pr-pull".

### Bumping pumi / fusion-io (manual)

`fusion-io` has no releases (pins a master commit, skips `livecheck`); follow
the same URL/version/sha256 procedure as fidasim.

`pumi` tracks the SCOREC/core **2.2.x** tags via `livecheck` — do **not** bump
it to v3.x or v4.x until M3D-C1's `m3dc1_scorec` adopts the new PCU API, or the
M3D-C1 build will fail to compile.

### Bumping the netcdf-fortran bindings

`netcdf-mpi` tracks netcdf-c via `livecheck`/`brew bump`, but the bundled
`netcdf-fortran` resource is pinned by hand. To move it, update the `resource
"netcdf-fortran"` `url`/`sha256` in `Formula/netcdf-mpi.rb` and bump the
formula `revision`.



