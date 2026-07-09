class Fidasim < Formula
  include Language::Python::Virtualenv

  desc "Neutral beam and fast-ion diagnostic modeling suite"
  homepage "https://d3denergetic.github.io/FIDASIM/"
  # No upstream release since v2.0.0 (2020); master is where development happens,
  # so we pin a recent commit. Bump the commit + version (commit date) manually.
  url "https://github.com/D3DEnergetic/FIDASIM/archive/ebaedfa9d4a0c3a4c5c0712de388f7ba81da037f.tar.gz"
  version "3.0.0.dev20260125"
  sha256 "2897e5bb3765c37781a1db3f9010bee2523a3cdd3111075c30bdfc1c5a37ea26"
  license "MIT"

  head "https://github.com/D3DEnergetic/FIDASIM.git", branch: "master"

  livecheck do
    skip "No tagged releases since 2020; formula pins master commits"
  end

  bottle do
    root_url "https://github.com/dgarnier/homebrew-plasma/releases/download/fidasim-3.0.0.dev20260125"
    sha256 cellar: :any, arm64_tahoe:   "c0b851476208c4a5a5fe70930ec4ec87e78aec9edd15a0f17e7b78b794b8d9da"
    sha256 cellar: :any, arm64_sequoia: "1296275f7faa574075ab876fe073b38aec96d7c576019b7dfc6efb19c3629ffc"
    sha256 cellar: :any, arm64_sonoma:  "1cc8b97f6c117efbdd0f67e1cec8ca5d8f1f8b208f582becb4b2c16a0051372c"
    sha256 cellar: :any, x86_64_linux:  "1b034ccdbf4efef4e498c23e540ef13b1a0ff935fbd069ea359d17723c2848f9"
  end

  depends_on "make" => :build
  depends_on "python@3.14" => :build # only to build the pure-python wheel
  depends_on "gcc" # gfortran must match the one hdf5-mpi was built with (.mod files)
  depends_on "hdf5-mpi"
  depends_on "open-mpi"

  # Build-time only: backend for building the fidasim wheel without network
  resource "setuptools" do
    url "https://files.pythonhosted.org/packages/5d/40/e1e72872c6354b306daef1703549e8e83b4d43cfea356311bf722a043752/setuptools-83.0.0-py3-none-any.whl"
    sha256 "29b23c360f22f414dc7336bb39178cc7bcbf6021ed2733cde173f09dba19abb3"
  end

  # Python CLI helpers shipped in the pip-installable package (see caveats)
  PYTHON_SCRIPTS = %w[
    edit_namelist
    extract_transp_fbm
    extract_transp_geqdsk
    plot_inputs
    plot_outputs
    plot_weights
    submit_fidasim
  ].freeze

  def python_wheel
    "fidasim-#{version}-py3-none-any.whl"
  end

  def install
    # src/makefile uses multi-target rules (foo.mod foo.o: foo.f90), which
    # parallel make runs once per target — two concurrent gfortran invocations
    # then race on the .mod0 -> .mod rename. Build serially; it is ~5 files.
    ENV.deparallelize

    gcc = Formula["gcc"]
    hdf5 = Formula["hdf5-mpi"]
    fc = gcc.opt_bin/"gfortran"

    # mpif90 must wrap the same gfortran
    ENV["OMPI_FC"] = fc.to_s

    # Skip FIDASIM's `deps` target (it builds a vendored HDF5 1.8.16) and point
    # the build at hdf5-mpi instead. FIDASIM only uses the serial HDF5 API, so
    # parallel HDF5 links fine for both flavors.
    # HDF5_FLAGS is overridden wholesale: the makefile's per-OS values use the
    # pre-1.10 library name (-lhdf5hl_fortran) and, on Linux, static linking —
    # which drags in hdf5-mpi's MPI symbols even for the non-MPI build.
    # CC/CXX are only sanity-checked by the makefile (all sources are Fortran),
    # but the check rejects Homebrew's `cc` shim, so name clang explicitly.
    common_args = [
      "FC=#{fc}",
      "CC=clang",
      "CXX=clang++",
      "HDF5_LIB=#{hdf5.opt_lib}",
      "HDF5_INCLUDE=#{hdf5.opt_include}",
      "HDF5_FLAGS=-L#{hdf5.opt_lib} -lhdf5_fortran -lhdf5_hl_fortran " \
      "-lhdf5_hl -lhdf5 -Wl,-rpath,#{hdf5.opt_lib}",
    ]

    # The makefile makes OpenMP and MPI mutually exclusive (USE_MPI=y forces
    # USE_OPENMP=n), so build twice and install both flavors of fidasim.
    # generate_tables is OpenMP-only by choice: tables are generated on one
    # machine, so only the first pass builds the tables target.
    system "make", "src", "tables", "USE_OPENMP=y", "USE_MPI=n", *common_args
    bin.install "fidasim"
    bin.install "tables/generate_tables"
    pkgshare.install "tables/table_settings.dat"

    system "make", "clean", *common_args
    system "make", "src", "USE_MPI=y", *common_args
    bin.install "fidasim" => "fidasim_mpi"

    # --- Python: package lib/python as a pip-installable wheel ---

    # get_fidasim_dir() walks four dirname()s up from utils.py, which is wrong
    # once the package is pip-installed into a foreign venv. Honor $FIDASIM_DIR,
    # else fall back to this formula's opt prefix.
    inreplace "lib/python/fidasim/utils.py",
              "directory = dirname(dirname(dirname(dirname(os.path.abspath(__file__)))))",
              "directory = os.environ.get('FIDASIM_DIR', '#{opt_prefix}')"

    # The CLI helpers use an `exec $FIDASIM_DIR/deps/python` shell trampoline;
    # replace it with a python shebang so pip rewrites it to the venv interpreter.
    (buildpath/"lib/python/scripts").mkpath
    PYTHON_SCRIPTS.each do |name|
      lines = File.readlines("lib/scripts/#{name}")
      lines.shift while lines.first&.start_with?("#!/bin/sh", "\"exec\"")
      script = buildpath/"lib/python/scripts"/name
      script.write "#!/usr/bin/env python3\n#{lines.join}"
      script.chmod 0755
    end

    (buildpath/"lib/python/pyproject.toml").write <<~TOML
      [build-system]
      requires = ["setuptools>=64"]
      build-backend = "setuptools.build_meta"

      [project]
      name = "fidasim"
      version = "#{version}"
      description = "Preprocessing (prefida) and utilities for FIDASIM"
      requires-python = ">=3.9"
      dependencies = ["numpy", "scipy", "h5py", "matplotlib"]

      [tool.setuptools]
      packages = ["fidasim", "efit", "vmec"]
      script-files = [
        #{PYTHON_SCRIPTS.map { |s| "\"scripts/#{s}\"" }.join(",\n  ")}
      ]
    TOML

    # Build the wheel in a throwaway venv (no network: setuptools is a resource).
    # virtualenv_create makes the venv --without-pip, so pip must be run as a
    # module via the venv python (which sees python@3.14's pip through
    # --system-site-packages).
    bvenv = virtualenv_create(buildpath/".bvenv", "python3.14")
    bvenv.pip_install resource("setuptools")
    system buildpath/".bvenv/bin/python", "-m", "pip", "wheel",
           "--no-deps", "--no-build-isolation",
           "--wheel-dir", buildpath/"wheelhouse", buildpath/"lib/python"
    pkgshare.install buildpath/"wheelhouse"/python_wheel

    # Keep the patched source tree too, for editable/source installs
    lib.install "lib/python"
    prefix.install "VERSION"

    # IDL routines as reference copies
    pkgshare.install "lib/idl"

    # One-shot atomic-table generation into var (writable, survives upgrades)
    (bin/"fidasim-generate-tables").write <<~EOS
      #!/bin/bash
      set -euo pipefail
      tables_dir="#{var}/fidasim"
      mkdir -p "$tables_dir"
      cd "$tables_dir"
      if [ ! -f table_settings.dat ]; then
        cp "#{opt_pkgshare}/table_settings.dat" .
        echo "Copied default table_settings.dat to $tables_dir (edit it and re-run to customize)"
      fi
      nthreads="${1:-$(sysctl -n hw.ncpu 2>/dev/null || nproc)}"
      echo "Generating atomic tables in $tables_dir with $nthreads threads (this takes a while)..."
      exec "#{opt_bin}/generate_tables" ./table_settings.dat "$nthreads"
    EOS
  end

  def post_install
    (var/"fidasim").mkpath
    # Expose the (user-generated) tables at $FIDASIM_DIR/tables, where the
    # python tools expect them: opt_prefix/tables -> var/fidasim
    prefix.install_symlink var/"fidasim" => "tables"
  end

  def caveats
    <<~EOS
      Two executables are installed:
        fidasim      - OpenMP (threads on one machine; the usual choice)
        fidasim_mpi  - MPI (run via mpirun; OpenMP disabled upstream in this mode)

      Atomic tables are NOT included. Generate them once (hours of CPU):
        fidasim-generate-tables [num_threads]
      This writes #{var}/fidasim/atomic_tables.h5 (linked at #{opt_prefix}/tables).
      To customize, edit #{var}/fidasim/table_settings.dat and re-run.

      To use the Python tools (prefida, plot_inputs, ...) from another project,
      install the wheel into that project's environment:
        pip install "#{opt_pkgshare}/#{python_wheel}"
    EOS
  end

  test do
    # Bare invocations print the FIDASIM banner; exit status is not part of the
    # contract, hence backticks instead of shell_output.
    assert_match "FIDASIM", `#{bin}/fidasim 2>&1`
    assert_match "FIDASIM", `#{formula_opt_bin("open-mpi")}/mpirun -np 1 #{bin}/fidasim_mpi 2>&1`

    system "python3", "-m", "venv", testpath/"venv"
    system testpath/"venv/bin/pip", "install", "--no-deps", pkgshare/python_wheel
    system testpath/"venv/bin/python", "-c",
           "import importlib.util; assert importlib.util.find_spec('fidasim')"
  end
end
