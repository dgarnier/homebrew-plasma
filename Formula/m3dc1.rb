class M3dc1 < Formula
  desc "Extended-MHD code for fusion plasmas (M3D-C1)"
  homepage "https://sites.google.com/pppl.gov/m3d-c1"
  # No tagged releases; pin a master commit (see README for the bump procedure).
  url "https://github.com/PrincetonUniversity/M3DC1/archive/c7f9c14a26fc72dc679598609b2c424952b0300c.tar.gz"
  version "1.16.dev20260708"
  sha256 "2e414936f7059a5cbc225436855baa6e6fe1354d56656b6c6dacefcc77aca881"
  license "BSD-3-Clause"

  livecheck do
    skip "no tagged upstream releases; pinned to a master commit"
  end

  # Build with the standard environment rather than superenv. This formula
  # depends on BOTH petsc kegs, and superenv injects a -I/-L for every
  # dependency in (alphabetical) dependency order -- so petsc-complex-m3dc1
  # comes first and its petscconf.h (PETSC_USE_COMPLEX) and libpetsc win for
  # the *real* build too, silently producing NaN. brew.mk passes every path
  # explicitly, and both petsc kegs are keg-only so neither is in
  # HOMEBREW_PREFIX/include, so with :std each variant sees only its own PETSc.
  env :std

  depends_on "cmake" => :build
  depends_on "dgarnier/plasma/netcdf-fortran-mpi"
  depends_on "dgarnier/plasma/netcdf-mpi"
  depends_on "dgarnier/plasma/petsc-complex-m3dc1"
  depends_on "dgarnier/plasma/petsc-m3dc1"
  depends_on "dgarnier/plasma/pumi"
  depends_on "dgarnier/plasma/zoltan"
  depends_on "fftw"
  depends_on "gcc"
  depends_on "gsl"
  depends_on "hdf5-mpi"
  depends_on "metis"
  depends_on "open-mpi"

  on_linux do
    depends_on "openblas"
  end

  # PETSC_VERSION as used by the source's preprocessor guards (>= 39 is the
  # newest branch); 324 tracks the petsc-m3dc1 pair at 3.24.x.
  PETSC_VERSION_DEFINE = "324".freeze

  def scorec_cmake_args(complex:)
    petsc = Formula[complex ? "dgarnier/plasma/petsc-complex-m3dc1" : "dgarnier/plasma/petsc-m3dc1"]
    cflags = "-O2 -fPIC -DPETSCMASTER -DPETSC_VERSION=#{PETSC_VERSION_DEFINE}"
    pumi = formula_opt_prefix("dgarnier/plasma/pumi")
    zoltan_lib = formula_opt_lib("dgarnier/plasma/zoltan")
    metis_lib = formula_opt_lib("metis")
    [
      "-DCMAKE_C_COMPILER=mpicc",
      "-DCMAKE_CXX_COMPILER=mpicxx",
      "-DCMAKE_Fortran_COMPILER=mpif90",
      "-DCMAKE_C_FLAGS=#{cflags}",
      # m3dc1_scorec sets no C++ standard; the macos-14 runner's clang defaults
      # to a pre-C++11 mode that rejects m3dc1_scorec's nested templates
      # (`> >`). Pin C++11 to match how pumi (SCOREC 2.2.x) is built.
      "-DCMAKE_CXX_FLAGS=#{cflags} -std=c++11",
      "-DCMAKE_Fortran_FLAGS=-fPIC -fallow-argument-mismatch",
      "-DSCOREC_INCLUDE_DIR=#{pumi}/include",
      "-DSCOREC_LIB_DIR=#{pumi}/lib",
      "-DZOLTAN_LIBRARY=#{zoltan_lib}/libzoltan.a",
      "-DMETIS_LIBRARY=#{metis_lib/shared_library("libmetis")}",
      "-DPETSC_INCLUDE_DIR=#{petsc.opt_include}",
      "-DPETSC_LIB_DIR=#{petsc.opt_lib}",
      "-DENABLE_COMPLEX=#{complex ? "ON" : "OFF"}",
      "-DENABLE_TESTING=OFF",
      "-DENABLE_ZOLTAN=ON",
    ]
  end

  def install
    # Ancient cmake_minimum_required in m3dc1_scorec.
    ENV["CMAKE_POLICY_VERSION_MINIMUM"] = "3.5"

    # Find .dylib dependencies (petsc, metis, PUMI) on macOS.
    if OS.mac?
      inreplace "m3dc1_scorec/CMakeLists.txt",
                'set(CMAKE_FIND_LIBRARY_SUFFIXES ".a" ".so")',
                'set(CMAKE_FIND_LIBRARY_SUFFIXES ".a" ".so" ".dylib")'
    end

    # Our petsc does not bundle parmetis/metis inside its own keg.
    inreplace "m3dc1_scorec/cmake/FindPetsc.cmake",
              "set(PETSC_LIB_NAMES\n  petsc\n  parmetis\n  metis\n)",
              "set(PETSC_LIB_NAMES\n  petsc\n)"

    # The static variable_list's exit-time destructor aborts with libc++
    # (every run would end in SIGTRAP after a successful solve). Leak the
    # singleton instead; the OS reclaims the memory at process exit.
    inreplace "unstructured/read_namelist.cpp",
              "static variable_list variables;",
              "static variable_list& variables = *new variable_list();"

    # The M3D-C1 <-> PUMI interface library, once per scalar type. The two
    # builds produce differently-named libraries (libm3dc1_scorec and
    # libm3dc1_scorec_complex), so they share one install prefix -- the same
    # layout upstream's SCOREC_DIR has.
    [false, true].each do |complex|
      dir = complex ? "scorec-build-complex" : "scorec-build"
      system "cmake", "-S", "m3dc1_scorec", "-B", dir,
             *scorec_cmake_args(complex:),
             "-DCMAKE_INSTALL_PREFIX=#{buildpath}/scorec",
             "-DCMAKE_BUILD_TYPE=Release"
      system "cmake", "--build", dir
      system "cmake", "--install", dir
    end

    # Machine file for the unstructured/ make system (see e.g. mit_gcc.mk).
    write_brew_mk

    # The unstructured/ makefile has no Fortran module dependency tracking;
    # parallel builds race on .mod files. Pass a block: Stdenv#deparallelize
    # (used because of `env :std`) declares its block parameter non-nilable, so
    # the bare call Superenv accepts raises a TypeError under Sorbet's runtime
    # checks.
    ENV.deparallelize do
      cd "unstructured" do
        # The same variant set as upstream's `make all`, minus the OpenMP and
        # particle-in-cell builds. brew.mk switches PETSc (and the m3dc1_scorec
        # library) on COM, exactly as upstream's machine files do.
        system "make", "ARCH=brew", "OPT=1"                                 # 2D real
        system "make", "ARCH=brew", "OPT=1", "COM=1"                        # 2D complex
        system "make", "ARCH=brew", "OPT=1", "3D=1", "MAX_PTS=60"           # 3D real
        system "make", "ARCH=brew", "OPT=1", "3D=1", "MAX_PTS=125", "ST=1"  # 3D stellarator
        system "make", "ARCH=brew", "a2cc"
      end
    end

    cd "unstructured" do
      bin.install "_brew-opt-25/m3dc1_2d"
      bin.install "_brew-complex-opt-25/m3dc1_2d_complex"
      bin.install "_brew-3d-opt-60/m3dc1_3d"
      bin.install "_brew-3d-st-opt-125/m3dc1_3d_st"
      bin.install "_brew/a2cc"
      bin.install Dir["sbin/*.sh"]

      pkgshare.install "templates", "tutorials", "idl", "regtest",
                       "device_data", "release_version"
    end
  end

  def write_brew_mk
    pumi = formula_opt_prefix("dgarnier/plasma/pumi")
    zoltan = formula_opt_prefix("dgarnier/plasma/zoltan")
    netcdf = formula_opt_prefix("dgarnier/plasma/netcdf-mpi")
    netcdff = formula_opt_prefix("dgarnier/plasma/netcdf-fortran-mpi")
    petsc_real = formula_opt_prefix("dgarnier/plasma/petsc-m3dc1")
    petsc_cplx = formula_opt_prefix("dgarnier/plasma/petsc-complex-m3dc1")
    hdf5 = formula_opt_prefix("hdf5-mpi")
    fftw = formula_opt_prefix("fftw")
    gsl = formula_opt_prefix("gsl")
    openblas = formula_opt_prefix("openblas") if OS.linux?
    metis = formula_opt_prefix("metis")

    # With `env :std` Homebrew no longer injects -Wl,-rpath for dependencies, so
    # the runtime search path is ours to supply. On Linux this is load-bearing:
    # linking a shared library by absolute path records only its bare SONAME
    # (e.g. libpetsc.so.3.24), so without an rpath the loader cannot find it
    # ("error while loading shared libraries"). macOS records an absolute
    # install_name instead, which is why this only bites on Linux.
    # Skipped deliberately: zoltan and m3dc1_scorec are static archives, and the
    # latter lives in the (temporary) build directory.
    # Linux only. macOS records an absolute install_name in each library, so the
    # loader resolves them without any rpath -- and adding them actively breaks
    # bottling: for a relocatable bottle Homebrew rewrites HOMEBREW_PREFIX to a
    # longer @@HOMEBREW_PREFIX@@ placeholder inside every LC_RPATH, and with the
    # entries gfortran already emits there is not enough Mach-O header space
    # left, so install_name_tool fails ("Failed changing rpath in ...").
    rpaths = ""
    if OS.linux?
      rpath_libdirs = [pumi, hdf5, fftw, gsl, metis, openblas].map { |d| "#{d}/lib" }
      # gfortran's runtime does not live under <prefix>/lib.
      rpath_libdirs << (formula_opt_prefix("gcc")/"lib/gcc/current").to_s
      # PETSc switches with COM, so its rpath has to be a make reference.
      rpaths = "-Wl,-rpath,$(PETSC_PREFIX)/lib " \
               "#{rpath_libdirs.map { |d| "-Wl,-rpath,#{d}" }.join(" ")}"
    end

    netcdf_rpaths = if OS.linux?
      "-Wl,-rpath,#{netcdf}/lib -Wl,-rpath,#{netcdff}/lib"
    else
      ""
    end

    (buildpath/"unstructured/brew.mk").write <<~MK
      FOPTS = -c -fdefault-real-8 -fdefault-double-8 -fallow-argument-mismatch \\
              -cpp -DPETSC_VERSION=#{PETSC_VERSION_DEFINE} -DUSEBLAS -ffree-line-length-0 $(OPTS)
      CCOPTS = -c -O2 -DPETSC_VERSION=#{PETSC_VERSION_DEFINE}
      R8OPTS = -fdefault-real-8 -fdefault-double-8

      ifeq ($(OPT), 1)
        FOPTS := $(FOPTS) -w -O2
      else
        FOPTS := $(FOPTS) -g
      endif

      CC = mpicc
      CPP = mpicxx
      F90 = mpif90
      F77 = mpif77
      LOADER = mpif90

      F90OPTS = $(F90FLAGS) $(FOPTS)
      F77OPTS = $(F77FLAGS) $(FOPTS)

      SCOREC_BASE_DIR = #{pumi}
      SCOREC_UTIL_DIR = $(SCOREC_BASE_DIR)/bin
      PUMI_DIR = $(SCOREC_BASE_DIR)
      PUMI_LIB = -lpumi -lapf -lapf_zoltan -lcrv -lsam -lspr -lmth -lgmi \\
                 -lma -lmds -lparma -lpcu -lph -llion

      M3DC1_SCOREC_DIR = #{buildpath}/scorec

      # Real and complex builds use different PETSc installs and different
      # m3dc1_scorec libraries, selected here the same way upstream's machine
      # files (e.g. mit_gcc.mk) do.
      ifeq ($(COM), 1)
        PETSC_PREFIX = #{petsc_cplx}
        M3DC1_SCOREC_LIB = -lm3dc1_scorec_complex
      else
        PETSC_PREFIX = #{petsc_real}
        M3DC1_SCOREC_LIB = -lm3dc1_scorec
      endif

      SCOREC_LIB = -L$(M3DC1_SCOREC_DIR)/lib $(M3DC1_SCOREC_LIB) \\
                   -L$(PUMI_DIR)/lib $(PUMI_LIB)

      # Link libpetsc by absolute path, not -L/-lpetsc: this formula depends on
      # both petsc kegs, and Homebrew's superenv injects a -L for each, so -lpetsc
      # can bind to the wrong scalar type regardless of the order we pass.
      PETSC_WITH_EXTERNAL_LIB = $(PETSC_PREFIX)/lib/#{shared_library("libpetsc")} \\
        -L#{fftw}/lib -lfftw3_mpi -lfftw3 \\
        -L#{hdf5}/lib -lhdf5_hl_fortran -lhdf5_fortran -lhdf5_hl -lhdf5 \\
        -L#{zoltan}/lib -lzoltan \\
        -L#{metis}/lib -lmetis \\
        -L#{gsl}/lib -lgsl -lgslcblas \\
        #{OS.linux? ? "-L#{openblas}/lib -lopenblas" : "-framework Accelerate"} \\
        #{OS.mac? ? "-lc++" : "-lstdc++"}

      RPATH_FLAGS = #{rpaths}

      LIBS = $(SCOREC_LIB) \\
             $(PETSC_WITH_EXTERNAL_LIB) \\
             $(RPATH_FLAGS)

      INCLUDE = -I$(PETSC_PREFIX)/include \\
                -I#{hdf5}/include \\
                -I#{fftw}/include \\
                -I#{gsl}/include

      ifeq ($(ST), 1)
        LIBS += -L#{netcdf}/lib -lnetcdf -L#{netcdff}/lib -lnetcdff #{netcdf_rpaths}
        INCLUDE += -I#{netcdf}/include -I#{netcdff}/include
      endif

      %.o : %.c
      	$(CC)  $(CCOPTS) $(INCLUDE) $< -o $@

      %.o : %.cpp
      	$(CPP) $(CCOPTS) -std=c++11 $(INCLUDE) $< -o $@

      %.o: %.f
      	$(F77) $(F77OPTS) $(INCLUDE) $< -o $@

      %.o: %.F
      	$(F77) $(F77OPTS) $(INCLUDE) $< -o $@

      %.o: %.f90
      	$(F90) $(F90OPTS) $(INCLUDE) $< -o $@
    MK
  end

  def caveats
    <<~EOS
      Mesh generation and partitioning are NOT included: m3dc1_meshgen needs
      the commercial Simmetrix SimModSuite, and the create_smb/split_smb
      sources are not published in the upstream repository. The generic PUMI
      utilities (mkmodel, split, zsplit) cannot substitute -- they do not
      understand M3D-C1's analytic model files ("gmi failed: model file
      extension not registered").

      Use the pre-partitioned sample meshes that ship in
        #{opt_pkgshare}/regtest
      running with #ranks == #part<rank>.smb files (e.g. KPRAD_2D/mesh has 48
      parts, so `mpirun -np 48`; the base/ directory holds a single serial
      part for -np 1). For new geometries, generate and split the mesh on an
      HPC system with a full M3D-C1 installation (e.g. PPPL, NERSC) and copy
      the part files here.

      Installed solvers:
        m3dc1_2d           2D nonlinear (real)
        m3dc1_2d_complex   2D linear stability / single toroidal mode (complex)
        m3dc1_3d           3D nonlinear (real)
        m3dc1_3d_st        3D stellarator (real)

      The real and complex builds link petsc-m3dc1 and petsc-complex-m3dc1
      respectively; both are keg-only, so they coexist and all four solvers are
      available at once. Both include the parallel direct solvers (MUMPS and
      SuperLU_DIST, with Scotch/PT-Scotch orderings), so M3D-C1's stock solver
      settings and options files work as upstream intends -- including the 3D
      per-plane LU in options_bjacobi. Switch solver with:
        -pc_factor_mat_solver_type superlu_dist   (M3D-C1's 2D default)
        -pc_factor_mat_solver_type mumps

      The complex build requires linear=1 and nplanes=1 in C1input.
    EOS
  end

  test do
    # Single-rank smoke test: the base mesh is one serial part (part0.smb),
    # and for 2D (nplanes=1) #ranks must equal #mesh parts. Launching -np N>1
    # against a single part deadlocks in PUMI's pcu_group_open collective
    # barrier (ranks 1..N-1 have no part<rank>.smb).
    np_args = ["-np", "1"]

    # Exercise both scalar types. Each runs M3D-C1's own default solver path
    # (KSPPREONLY + PCLU + superlu_dist, hardcoded in m3dc1_scorec's
    # m3dc1_matrix.cc), which is exactly what the petsc-m3dc1 pair provides.
    { "m3dc1_2d" => false, "m3dc1_2d_complex" => true }.each do |exe, complex|
      dir = testpath/exe
      dir.mkpath
      cp_r Dir[pkgshare/"regtest/KPRAD_2D/base/*"], dir
      # m3dc1_scorec expands mesh_filename "part.smb" to part<rank>.smb.
      cp dir/"analytic-2K0.smb", dir/"part0.smb"
      # Shorten to a single time step for a smoke test.
      inreplace dir/"C1input", /ntimemax\s*=\s*\d+/, "ntimemax = 1"
      # The complex build refuses to run unless linear=1 (and nplanes=1).
      inreplace dir/"C1input", /linear\s*=\s*0/, "linear = 1" if complex

      output = Dir.chdir(dir) do
        shell_output("mpirun #{np_args.join(" ")} #{bin}/#{exe} -options_left no 2>&1")
      end

      # Check the physics, not just that something ran. M3D-C1 exits 0 and still
      # writes a stub C1.h5 when the solve diverges, so "it produced a file" is
      # not evidence of a working build.
      #
      # This matters: linking the wrong-scalar-type PETSc (which superenv did
      # before `env :std`) silently turns every solve into NaN while the run
      # still looks superficially fine. Assert on the failure text M3D-C1 prints
      # ("Error: solution is NaN", then "Stopped at 11" rather than 0), and on a
      # plausible output size -- a healthy single-step run writes ~320 KB, a
      # diverged one ~195 bytes.
      refute_match "solution is NaN", output
      refute_match "does not support matrix type", output
      assert_match(/Stopped at\s+0\b/, output)
      assert_path_exists dir/"C1.h5"
      assert_operator (dir/"C1.h5").size, :>, 100_000
    end
  end
end
