class M3dc1Complex < Formula
  desc "Extended-MHD code for fusion plasmas (M3D-C1, complex/linear variant)"
  homepage "https://sites.google.com/pppl.gov/m3d-c1"
  # No tagged releases; pin a master commit (see README for the bump procedure).
  # Keep in sync with the m3dc1 formula.
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
  depends_on "petsc-complex"

  uses_from_macos "zlib" # actually will link Accelerate framework and MacOS Blas

  on_linux do
    depends_on "openblas"
  end

  conflicts_with "m3dc1",
    because: "m3dc1 links against petsc (real) and m3dc1-complex against petsc-complex, which conflict"

  # PETSC_VERSION as used by the source's preprocessor guards (>= 39 is the
  # newest branch); 324 tracks homebrew-core petsc-complex 3.24.x.
  PETSC_VERSION_DEFINE = "324".freeze

  def install
    # Ancient cmake_minimum_required in m3dc1_scorec.
    ENV["CMAKE_POLICY_VERSION_MINIMUM"] = "3.5"

    # Find .dylib dependencies (petsc, metis, PUMI) on macOS.
    inreplace "m3dc1_scorec/CMakeLists.txt",
              'set(CMAKE_FIND_LIBRARY_SUFFIXES ".a" ".so")',
              'set(CMAKE_FIND_LIBRARY_SUFFIXES ".a" ".so" ".dylib")'

    # Homebrew's petsc-complex does not bundle parmetis/metis inside its own keg.
    inreplace "m3dc1_scorec/cmake/FindPetsc.cmake",
              "set(PETSC_LIB_NAMES\n  petsc\n  parmetis\n  metis\n)",
              "set(PETSC_LIB_NAMES\n  petsc\n)"

    # The static variable_list's exit-time destructor aborts with libc++
    # (every run would end in SIGTRAP after a successful solve). Leak the
    # singleton instead; the OS reclaims the memory at process exit.
    inreplace "unstructured/read_namelist.cpp",
              "static variable_list variables;",
              "static variable_list& variables = *new variable_list();"

    # The M3D-C1 <-> PUMI interface library (complex scalars).
    petsc = Formula["petsc-complex"]
    cflags = "-O2 -fPIC -DPETSCMASTER -DPETSC_VERSION=#{PETSC_VERSION_DEFINE}"
    system "cmake", "-S", "m3dc1_scorec", "-B", "scorec-build",
           "-DCMAKE_C_COMPILER=mpicc",
           "-DCMAKE_CXX_COMPILER=mpicxx",
           "-DCMAKE_Fortran_COMPILER=mpif90",
           "-DCMAKE_C_FLAGS=#{cflags}",
           # m3dc1_scorec sets no C++ standard; the macos-14 runner's clang
           # defaults to a pre-C++11 mode that rejects m3dc1_scorec's nested
           # templates (`> >`). Pin C++11 to match how pumi (SCOREC 2.2.x) is
           # built.
           "-DCMAKE_CXX_FLAGS=#{cflags} -std=c++11",
           "-DCMAKE_Fortran_FLAGS=-fPIC -fallow-argument-mismatch",
           "-DSCOREC_INCLUDE_DIR=#{formula_opt_include("dgarnier/plasma/pumi")}",
           "-DSCOREC_LIB_DIR=#{formula_opt_lib("dgarnier/plasma/pumi")}",
           "-DZOLTAN_LIBRARY=#{formula_opt_lib("dgarnier/plasma/zoltan")}/libzoltan.a",
           "-DMETIS_LIBRARY=#{formula_opt_lib("metis")/shared_library("libmetis")}",
           "-DPETSC_INCLUDE_DIR=#{petsc.opt_include}",
           "-DPETSC_LIB_DIR=#{petsc.opt_lib}",
           "-DENABLE_COMPLEX=ON",
           "-DENABLE_TESTING=OFF",
           "-DENABLE_ZOLTAN=ON",
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
      system "make", "ARCH=brew", "OPT=1", "COM=1"
      bin.install "_brew-complex-opt-25/m3dc1_2d_complex"
      pkgshare.install "regtest", "release_version"
    end
  end

  def write_brew_mk
    pumi = formula_opt_prefix("dgarnier/plasma/pumi")
    zoltan = formula_opt_prefix("dgarnier/plasma/zoltan")
    netcdf = formula_opt_prefix("dgarnier/plasma/netcdf-mpi")
    netcdff = formula_opt_prefix("dgarnier/plasma/netcdf-fortran-mpi")
    petsc = formula_opt_prefix("petsc-complex")
    hdf5 = formula_opt_prefix("hdf5-mpi")
    fftw = formula_opt_prefix("fftw")
    gsl = formula_opt_prefix("gsl")
    openblas = formula_opt_prefix("openblas") if OS.linux?
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
        #{OS.linux? ? "-L#{openblas}/lib -lopenblas" : "-framework Accelerate"} \\
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
      This is the complex (linear stability / single toroidal mode) build of
      M3D-C1 (m3dc1_2d_complex). For the nonlinear real builds (m3dc1_2d,
      m3dc1_3d, m3dc1_3d_st) install the `m3dc1` formula instead -- the two
      cannot be installed together because petsc and petsc-complex conflict.

      Mesh generation (m3dc1_meshgen) requires the commercial Simmetrix
      SimModSuite and is NOT included; see the m3dc1 formula caveats for the
      simple-mesh workflow using the pumi utilities.

      Homebrew's petsc-complex has no MUMPS/SuperLU_dist, so distributed
      direct solves are unavailable; use e.g.
        -pc_factor_mat_solver_type petsc
      instead of the superlu_dist/mumps settings in M3D-C1's stock options files.
    EOS
  end

  test do
    cp_r pkgshare/"regtest/KPRAD_2D/base/.", testpath
    # m3dc1_scorec expands mesh_filename "part.smb" to part<rank>.smb.
    cp testpath/"analytic-2K0.smb", testpath/"part0.smb"
    # Shorten to a single time step; the complex build requires linear=1.
    inreplace testpath/"C1input", /ntimemax\s*=\s*\d+/, "ntimemax = 1"
    inreplace testpath/"C1input", /linear\s*=\s*0/, "linear = 1"
    system "mpirun", "-np", "1", bin/"m3dc1_2d_complex",
           "-pc_factor_mat_solver_type", "petsc",
           "-options_left", "no"
    assert_path_exists testpath/"C1.h5"
  end
end
