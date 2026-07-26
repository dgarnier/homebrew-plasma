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

## MDSplus

MDSplus is packaged differently from upstream, and the differences matter.

**It is not installed in `/usr/local/mdsplus`.** That is upstream's standard location,
and MDSplus hardcodes it in a number of places. This formula installs into its Homebrew
keg instead:

```sh
brew --prefix mdsplus      # e.g. /opt/homebrew/opt/mdsplus
```

and rewrites every hardcoded `/usr/local/mdsplus` reference to point there — in
`setup.sh` / `setup.csh`, the `MDSplus` Python package (`__init__.py`, `version.py`,
`tree.py`, the `wsgi` handlers and config), `cmake/FindMDSplus.cmake`,
`macosx/mdsip.plist`, `epics/archiver/Sdd2Mds` and `TreeShrHook.py.example`.

**The formula is deliberately `keg_only`**, i.e. not symlinked into `$(brew --prefix)/bin`.
That is how MDSplus expects to be used: source its setup script rather than putting it
on `PATH` piecemeal. Add to your shell profile:

```sh
if [ -f "$(brew --prefix mdsplus)/setup.sh" ]; then
  source "$(brew --prefix mdsplus)/setup.sh"
fi
```

**Consequence: the install is not portable.** Because absolute paths are baked into
scripts and Python sources at build time, you cannot copy the tree somewhere else — or
onto a machine with a different Homebrew prefix — and expect it to work. Install it with
`brew` on each machine rather than relocating it by hand. (Note the prefix is not
constant: it is `/opt/homebrew` on Apple Silicon but `/usr/local` on Intel macOS, so
`brew --prefix mdsplus` is always the reliable way to refer to it.)

### Python bindings

The build also produces a wheel, alongside the importable package:

```sh
ls "$(brew --prefix mdsplus)/python"
# MDSplus/  mdsplus-<version>-py3-none-any.whl
```

Note that sourcing `setup.sh` is **not** enough to `import MDSplus`. It sets the MDSplus
environment (`MDSPLUS_DIR`, `PATH`, `MDS_PATH`, `IDL_PATH`, and a `PYTHONPATH` entry for
`pydevices`), but not a `PYTHONPATH` entry for the package itself. Either install the
wheel — which works in a virtualenv and is the tidier option:

```sh
pip install "$(brew --prefix mdsplus)"/python/mdsplus-*.whl
```

or add the directory to `PYTHONPATH` yourself:

```sh
export PYTHONPATH="$(brew --prefix mdsplus)/python:$PYTHONPATH"
```

## The M3D-C1 stack

[M3D-C1](https://github.com/PrincetonUniversity/M3DC1) is a PPPL extended-MHD
code for fusion plasmas. One `m3dc1` formula builds all four solvers:

| Binary | Description | Scalars |
|---|---|---|
| `m3dc1_2d` | 2D nonlinear | real |
| `m3dc1_2d_complex` | 2D linear stability / single toroidal mode | complex |
| `m3dc1_3d` | 3D nonlinear | real |
| `m3dc1_3d_st` | 3D stellarator | real |

plus `a2cc` and M3D-C1's helper scripts. The real and complex builds link
`petsc-m3dc1` and `petsc-complex-m3dc1` respectively; both are keg-only, so they
coexist and all four solvers are usable at once. This mirrors upstream's own
design, where the machine file switches PETSc on `COM` and `make all` builds
every variant from one tree.

Both PETSc builds include the parallel direct solvers homebrew-core's
`petsc`/`petsc-complex` lack (MUMPS and SuperLU_DIST, with Scotch/PT-Scotch
orderings), so M3D-C1's stock solver settings and options files work as upstream
intends -- including the 3D per-plane LU in `options_bjacobi`:

```
-pc_factor_mat_solver_type superlu_dist   # M3D-C1's 2D default
-pc_factor_mat_solver_type mumps
```

Supporting formulae: **`mumps`**, **`superlu-dist`**, **`petsc-m3dc1`**,
**`petsc-complex-m3dc1`**, **`zoltan`**, **`pumi`** (SCOREC/core, pinned to the
2.2.x series -- v3+ replaced the global PCU API that M3D-C1's bundled
`m3dc1_scorec` still uses), **`netcdf-fortran-mpi`**, and **`fusion-io`** for
post-processing. No ParMETIS anywhere: its license forbids redistribution, so
Scotch/PT-Scotch (CeCILL-C, already in core) provides the parallel orderings.

### Limitations

**No mesh generation or partitioning.** `m3dc1_meshgen` needs the commercial
Simmetrix SimModSuite, and the `create_smb`/`split_smb` sources are not published
upstream. The generic PUMI utilities cannot substitute -- they do not understand
M3D-C1's analytic model files. Use the pre-partitioned sample meshes that ship
in `$(brew --prefix m3dc1)/share/m3dc1/regtest`, or generate and split meshes on
an HPC system with a full M3D-C1 install and copy the part files over.

**Ranks must equal mesh parts.** For 2D (`nplanes=1`) the number of MPI ranks
must equal the number of `part<rank>.smb` files, or the run deadlocks in PUMI's
collective barrier.

### Running the regression tests

```sh
cd $(mktemp -d)
R=$(brew --prefix m3dc1)/share/m3dc1/regtest/KPRAD_2D
cp $R/base/{C1input,C1ke,AnalyticModel,analytic.txt,geqdsk} .
cp $R/mesh/part*.smb .            # 48 parts
mpirun -np 48 m3dc1_2d
```

A healthy single-step run writes a ~320 KB `C1.h5` and reports `Stopped at 0`;
a diverged one prints `Error: solution is NaN` and leaves a ~195 byte stub.

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



