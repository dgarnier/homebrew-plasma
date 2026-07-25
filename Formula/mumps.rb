class Mumps < Formula
  desc "MUltifrontal Massively Parallel sparse direct Solver"
  homepage "https://mumps-solver.org/"
  url "https://web.cels.anl.gov/projects/petsc/download/externalpackages/MUMPS_5.9.1.tar.gz"
  sha256 "659c9b57646b5a003ac618baa1faf9dd2044e46c732b3daaccbc7158003e1b46"
  license "CECILL-C"

  livecheck do
    url "https://web.cels.anl.gov/projects/petsc/download/externalpackages/"
    regex(/href=.*?MUMPS[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  depends_on "gcc" # for gfortran
  depends_on "metis"
  depends_on "open-mpi"
  depends_on "scalapack"
  # Provides both the (PT-)Scotch orderings and the esmumps interface MUMPS
  # links against. Used instead of ParMETIS, whose license forbids
  # redistribution (so it could never be bottled).
  depends_on "scotch"

  on_linux do
    depends_on "openblas"
  end

  def install
    metis = Formula["metis"]
    scotch = Formula["scotch"]
    scalapack = Formula["scalapack"]
    # Accelerate on macOS; OpenBLAS elsewhere. Note that core scalapack always
    # links OpenBLAS, so both are present on macOS -- harmless, since the
    # two-level namespace binds each library to the BLAS it was built against.
    blas = if OS.mac?
      "-framework Accelerate"
    else
      "-L#{formula_opt_lib("openblas")} -lopenblas"
    end

    # Based on Make.inc/Makefile.debian.PAR, with PT-Scotch enabled and
    # ParMETIS deliberately absent (serial METIS + PORD + Scotch/PT-Scotch
    # cover the orderings M3D-C1 needs).
    (buildpath/"Makefile.inc").write <<~INC
      # Begin orderings
      ISCOTCH   = -I#{scotch.opt_include}
      LSCOTCH   = -L#{scotch.opt_lib} -lptesmumps -lptscotch -lptscotcherr \\
                  -lesmumps -lscotch -lscotcherr

      LPORDDIR = $(topdir)/PORD/lib/
      IPORD    = -I$(topdir)/PORD/include/
      LPORD    = -L$(LPORDDIR) -lpord$(PLAT)

      IMETIS    = -I#{metis.opt_include}
      LMETIS    = -L#{metis.opt_lib} -lmetis

      ORDERINGSF = -Dmetis -Dpord -Dscotch -Dptscotch
      ORDERINGSC = $(ORDERINGSF)

      LORDERINGS = $(LMETIS) $(LPORD) $(LSCOTCH)
      IORDERINGSF = $(ISCOTCH)
      IORDERINGSC = $(IMETIS) $(IPORD) $(ISCOTCH)
      # End orderings
      ###############################################################################

      PLAT    =
      LIBEXT_SHARED = #{OS.mac? ? ".dylib" : ".so"}
      SONAME  = #{OS.mac? ? "-install_name" : "-soname"}
      SHARED_OPT = #{OS.mac? ? "-dynamiclib" : "-shared"}
      FPIC_OPT = -fPIC
      RPATH_OPT = -Wl,-rpath,#{lib}
      LIBEXT  = .a
      OUTC    = -o#{" "}
      OUTF    = -o#{" "}
      RM      = /bin/rm -f
      CC      = mpicc
      FC      = mpif90
      FL      = mpif90
      AR      = ar vr#{" "}
      RANLIB  = ranlib

      LAPACK  = #{blas}
      SCALAP  = -L#{scalapack.opt_lib} -lscalapack

      INCPAR  =
      LIBPAR  = $(SCALAP) $(LAPACK)

      INCSEQ  = -I$(topdir)/libseq
      LIBSEQ  = $(LAPACK) -L$(topdir)/libseq -lmpiseq$(PLAT)

      LIBBLAS = #{blas}
      LIBOTHERS = -lpthread

      # Preprocessor defs for calling Fortran from C
      CDEFS   = -DAdd_

      # OpenMP is left off: MUMPS builds C with the (clang) mpicc wrapper and
      # Fortran with gfortran, and mixing their OpenMP runtimes is fragile.
      OPTF    = -O -fallow-argument-mismatch -fPIC
      OPTL    = -O -fPIC
      OPTC    = -O -fPIC

      INCS = $(INCPAR)
      LIBS = $(LIBPAR)
      LIBSEQNEEDED =
    INC

    # All four arithmetics (s/d/c/z) plus mumps_common and pord, which is what
    # PETSc's --with-mumps-dir expects to find.
    #
    # NOTE: the resulting dylibs have a flat namespace, which `brew audit`
    # flags. The cause is upstream in open-mpi, not here: its Fortran wrapper
    # data (share/openmpi/mpifort-wrapper-data.txt) bakes -Wl,-flat_namespace
    # into compiler_flags, and the wrapper appends it *after* any
    # -Wl,-twolevel_namespace we pass, so it always wins. (The C wrappers do
    # not do this.) Every gfortran-linked library in this tap is affected --
    # see also netcdf-fortran-mpi -- so this needs fixing in open-mpi rather
    # than worked around per formula. The audit warning is benign here.
    system "make", "allshared"

    lib.install Dir["lib/lib*"]
    include.install Dir["include/*"]
    pkgshare.install "examples"
    doc.install Dir["doc/*"]
  end

  test do
    # Solve a small symmetric positive definite system with dmumps, following
    # the structure of examples/dsimpletest.F.
    (testpath/"test.c").write <<~C
      #include <mpi.h>
      #include <stdio.h>
      #include <dmumps_c.h>

      #define JOB_INIT -1
      #define JOB_END -2
      #define USE_COMM_WORLD -987654

      int main(int argc, char **argv) {
        DMUMPS_STRUC_C id;
        /* 2x2 system: [2 1; 1 2] x = [3; 3]  =>  x = [1; 1] */
        MUMPS_INT n = 2, nnz = 4;
        MUMPS_INT irn[] = {1, 1, 2, 2};
        MUMPS_INT jcn[] = {1, 2, 1, 2};
        double a[] = {2.0, 1.0, 1.0, 2.0};
        double rhs[] = {3.0, 3.0};

        MPI_Init(&argc, &argv);
        id.comm_fortran = USE_COMM_WORLD;
        id.par = 1;
        id.sym = 0;
        id.job = JOB_INIT;
        dmumps_c(&id);

        id.n = n; id.nnz = nnz; id.irn = irn; id.jcn = jcn;
        id.a = a; id.rhs = rhs;
        id.icntl[0] = -1; id.icntl[1] = -1; id.icntl[2] = -1; id.icntl[3] = 0;

        id.job = 6; /* analyse + factorize + solve */
        dmumps_c(&id);
        if (id.infog[0] != 0) {
          printf("MUMPS error infog(1)=%d\\n", id.infog[0]);
          return 1;
        }

        id.job = JOB_END;
        dmumps_c(&id);
        MPI_Finalize();

        printf("%.4f %.4f\\n", rhs[0], rhs[1]);
        return (rhs[0] > 0.999 && rhs[0] < 1.001 && rhs[1] > 0.999 && rhs[1] < 1.001) ? 0 : 1;
      }
    C
    system "mpicc", "test.c", "-I#{include}", "-L#{lib}",
           "-ldmumps", "-lmumps_common", "-lpord",
           "-Wl,-rpath,#{lib}", "-o", "test"
    assert_match "1.0000 1.0000", shell_output("mpirun -np 1 ./test")
  end
end
