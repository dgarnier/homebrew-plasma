class M3dc1 < Formula
  desc "Extended-MHD code for fusion plasmas (M3D-C1, real/nonlinear variants)"
  homepage "https://sites.google.com/pppl.gov/m3d-c1"
  # No tagged releases; pin a master commit (see README for the bump procedure).
  url "https://github.com/PrincetonUniversity/M3DC1/archive/c7f9c14a26fc72dc679598609b2c424952b0300c.tar.gz"
  version "1.16.dev20260708"
  sha256 "2e414936f7059a5cbc225436855baa6e6fe1354d56656b6c6dacefcc77aca881"
  license "BSD-3-Clause"

  livecheck do
    skip "no tagged upstream releases; pinned to a master commit"
  end

  depends_on "cmake" => :build
  depends_on "dgarnier/plasma/netcdf-fortran-mpi"
  depends_on "dgarnier/plasma/netcdf-mpi"
  depends_on "dgarnier/plasma/pumi"
  depends_on "dgarnier/plasma/zoltan"
  depends_on "fftw"
  depends_on "gcc"
  depends_on "gsl"
  depends_on "hdf5-mpi"
  depends_on "metis"
  depends_on "open-mpi"
  depends_on "petsc"

  on_linux do
    depends_on "openblas"
  end

  conflicts_with "m3dc1-complex",
    because: "m3dc1 links against petsc (real) and m3dc1-complex against petsc-complex, which conflict"

  # PETSC_VERSION as used by the source's preprocessor guards (>= 39 is the
  # newest branch); 324 tracks homebrew-core petsc 3.24.x.
  PETSC_VERSION_DEFINE = "324".freeze

  def scorec_cmake_args(complex:)
    petsc = Formula[complex ? "petsc-complex" : "petsc"]
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

    # Homebrew's petsc does not bundle parmetis/metis inside its own keg.
    inreplace "m3dc1_scorec/cmake/FindPetsc.cmake",
              "set(PETSC_LIB_NAMES\n  petsc\n  parmetis\n  metis\n)",
              "set(PETSC_LIB_NAMES\n  petsc\n)"

    # The static variable_list's exit-time destructor aborts with libc++
    # (every run would end in SIGTRAP after a successful solve). Leak the
    # singleton instead; the OS reclaims the memory at process exit.
    inreplace "unstructured/read_namelist.cpp",
              "static variable_list variables;",
              "static variable_list& variables = *new variable_list();"

    # The M3D-C1 <-> PUMI interface library (real scalars).
    system "cmake", "-S", "m3dc1_scorec", "-B", "scorec-build",
           *scorec_cmake_args(complex: false),
           "-DCMAKE_INSTALL_PREFIX=#{buildpath}/scorec",
           "-DCMAKE_BUILD_TYPE=Release"
    system "cmake", "--build", "scorec-build"
    system "cmake", "--install", "scorec-build"

    # Machine file for the unstructured/ make system (see e.g. mit_gcc.mk).
    write_brew_mk

    # The unstructured/ makefile has no Fortran module dependency tracking;
    # parallel builds race on .mod files.
    ENV.deparallelize

    cd "unstructured" do
      # 2D real, 3D real, 3D stellarator: same variant set as `make all`,
      # minus the OpenMP/particle builds.
      system "make", "ARCH=brew", "OPT=1"
      system "make", "ARCH=brew", "OPT=1", "3D=1", "MAX_PTS=60"
      system "make", "ARCH=brew", "OPT=1", "3D=1", "MAX_PTS=125", "ST=1"
      system "make", "ARCH=brew", "a2cc"

      bin.install "_brew-opt-25/m3dc1_2d"
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
    petsc = formula_opt_prefix("petsc")
    hdf5 = formula_opt_prefix("hdf5-mpi")
    fftw = formula_opt_prefix("fftw")
    gsl = formula_opt_prefix("gsl")
    openblas = formula_opt_prefix("openblas")
    metis = formula_opt_prefix("metis")

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
      ifeq ($(COM), 1)
        M3DC1_SCOREC_LIB = -lm3dc1_scorec_complex
      else
        M3DC1_SCOREC_LIB = -lm3dc1_scorec
      endif

      SCOREC_LIB = -L$(M3DC1_SCOREC_DIR)/lib $(M3DC1_SCOREC_LIB) \\
                   -L$(PUMI_DIR)/lib $(PUMI_LIB)

      PETSC_WITH_EXTERNAL_LIB = -L#{petsc}/lib -lpetsc \\
        -L#{fftw}/lib -lfftw3_mpi -lfftw3 \\
        -L#{hdf5}/lib -lhdf5_hl_fortran -lhdf5_fortran -lhdf5_hl -lhdf5 \\
        -L#{zoltan}/lib -lzoltan \\
        -L#{metis}/lib -lmetis \\
        -L#{gsl}/lib -lgsl -lgslcblas \\
        -L#{openblas}/lib -lopenblas \\
        #{OS.mac? ? "-lc++" : "-lstdc++"}

      LIBS = $(SCOREC_LIB) \\
             $(PETSC_WITH_EXTERNAL_LIB)

      INCLUDE = -I#{petsc}/include \\
                -I#{hdf5}/include \\
                -I#{fftw}/include \\
                -I#{gsl}/include

      ifeq ($(ST), 1)
        LIBS += -L#{netcdf}/lib -lnetcdf -L#{netcdff}/lib -lnetcdff
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
      Mesh generation (m3dc1_meshgen, convert_sim_sms) requires the commercial
      Simmetrix SimModSuite and is NOT included. Generate equilibrium-fitted
      meshes on an HPC system with an M3D-C1 installation (e.g. PPPL, NERSC),
      or -- unrecommended, but workable for simple geometries -- build simple
      structured meshes with the PUMI utilities (mkmodel, split, zsplit from
      the pumi formula) and the create_mesh.sh/part_mesh.sh helper scripts.
      Pre-partitioned sample meshes ship in:
        #{opt_pkgshare}/regtest

      Homebrew's petsc has no MUMPS/SuperLU_dist, so distributed direct solves
      are unavailable. For serial or per-rank block solves use PETSc's native
      LU or UMFPACK, e.g.:
        -pc_factor_mat_solver_type petsc
      instead of the superlu_dist/mumps settings in M3D-C1's stock options files.
    EOS
  end

  test do
    # Single-rank smoke test: the base mesh is one serial part (part0.smb),
    # and for 2D (nplanes=1) #ranks must equal #mesh parts. Launching -np N>1
    # against a single part deadlocks in PUMI's pcu_group_open collective
    # barrier (ranks 1..N-1 have no part<rank>.smb).
    np_args = ["-np", "1"]

    cp_r pkgshare/"regtest/KPRAD_2D/base/.", testpath
    # m3dc1_scorec expands mesh_filename "part.smb" to part<rank>.smb.
    cp testpath/"analytic-2K0.smb", testpath/"part0.smb"
    # Shorten to a single time step for a smoke test.
    inreplace testpath/"C1input", /ntimemax\s*=\s*\d+/, "ntimemax = 1"
    system "mpirun", *np_args, bin/"m3dc1_2d",
           "-pc_factor_mat_solver_type", "petsc",
           "-options_left", "no"
    assert_path_exists testpath/"C1.h5"
  end
end
