class SuperluDist < Formula
  desc "Distributed-memory (MPI) direct solver for large sparse linear systems"
  # The canonical NERSC project page (portal.nersc.gov/project/sparse/superlu)
  # is frequently unreachable, which fails `brew audit --online`.
  homepage "https://github.com/xiaoyeli/superlu_dist"
  url "https://github.com/xiaoyeli/superlu_dist/archive/refs/tags/v9.2.1.tar.gz"
  sha256 "c80a1c2edaaa451ee9a54e005e5f3f56dc55cabe2b0a8d7acf5a1447a648157a"
  license "BSD-3-Clause"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  depends_on "cmake" => :build
  depends_on "open-mpi"

  on_linux do
    depends_on "openblas"
  end

  def install
    # Accelerate on macOS, OpenBLAS elsewhere.
    blas = if OS.mac?
      "-framework Accelerate"
    else
      "-L#{formula_opt_lib("openblas")} -lopenblas"
    end

    system "cmake", "-S", ".", "-B", "build",
           "-DCMAKE_C_COMPILER=mpicc",
           "-DCMAKE_CXX_COMPILER=mpicxx",
           "-DBUILD_SHARED_LIBS=ON",
           "-DTPL_BLAS_LIBRARIES=#{blas}",
           # ParMETIS's license forbids redistribution, so it is deliberately
           # absent from this tap. Without it SuperLU_DIST falls back to its
           # built-in MMD_AT_PLUS_A ordering, which is fine at the scales
           # M3D-C1 runs on a workstation.
           "-DTPL_ENABLE_PARMETISLIB=OFF",
           "-DXSDK_ENABLE_Fortran=OFF",
           "-Denable_python=OFF",
           "-Denable_tests=OFF",
           "-Denable_examples=OFF",
           "-Denable_doc=OFF",
           *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    # Factor and solve a small system through the SuperLU_DIST driver.
    (testpath/"test.c").write <<~C
      #include <mpi.h>
      #include <stdio.h>
      #include <superlu_ddefs.h>

      int main(int argc, char **argv) {
        MPI_Init(&argc, &argv);

        gridinfo_t grid;
        superlu_gridinit(MPI_COMM_WORLD, 1, 1, &grid);

        /* [2 1; 1 2] x = [3; 3]  =>  x = [1; 1], in CSR (row-major) */
        int_t m = 2, n = 2, nnz = 4;
        double *nzval;
        int_t *colind, *rowptr;
        dallocateA_dist(n, nnz, &nzval, &colind, &rowptr);
        nzval[0] = 2.0; nzval[1] = 1.0; nzval[2] = 1.0; nzval[3] = 2.0;
        colind[0] = 0; colind[1] = 1; colind[2] = 0; colind[3] = 1;
        rowptr[0] = 0; rowptr[1] = 2; rowptr[2] = 4;

        SuperMatrix A;
        dCreate_CompRowLoc_Matrix_dist(&A, m, n, nnz, m, 0,
                                       nzval, colind, rowptr,
                                       SLU_NR_loc, SLU_D, SLU_GE);

        double b[2] = {3.0, 3.0};
        double berr[1];
        int info;

        superlu_dist_options_t options;
        set_default_options_dist(&options);
        options.PrintStat = NO;

        dScalePermstruct_t ScalePermstruct;
        dLUstruct_t LUstruct;
        dSOLVEstruct_t SOLVEstruct;
        SuperLUStat_t stat;
        dScalePermstructInit(m, n, &ScalePermstruct);
        dLUstructInit(n, &LUstruct);
        PStatInit(&stat);

        pdgssvx(&options, &A, &ScalePermstruct, b, m, 1, &grid,
                &LUstruct, &SOLVEstruct, berr, &stat, &info);

        printf("info=%d x=%.4f %.4f\\n", info, b[0], b[1]);

        PStatFree(&stat);
        dDestroy_LU(n, &grid, &LUstruct);
        dLUstructFree(&LUstruct);
        dScalePermstructFree(&ScalePermstruct);
        dSolveFinalize(&options, &SOLVEstruct);
        superlu_gridexit(&grid);
        MPI_Finalize();

        if (info != 0) return 1;
        return (b[0] > 0.999 && b[0] < 1.001 && b[1] > 0.999 && b[1] < 1.001) ? 0 : 1;
      }
    C
    system "mpicc", "test.c", "-I#{include}", "-L#{lib}",
           "-lsuperlu_dist", "-Wl,-rpath,#{lib}", "-o", "test"
    assert_match "x=1.0000 1.0000", shell_output("mpirun -np 1 ./test")
  end
end
