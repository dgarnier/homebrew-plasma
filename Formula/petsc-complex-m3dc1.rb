class PetscComplexM3dc1 < Formula
  desc "PETSc (complex) with MUMPS and SuperLU_DIST, configured for M3D-C1"
  homepage "https://petsc.org/"
  url "https://web.cels.anl.gov/projects/petsc/download/release-snapshots/petsc-3.25.3.tar.gz"
  sha256 "95ce60df2c7f9c5044d6a544c41e996a512557f91df1a60bdb690b332904ebb5"
  license "BSD-2-Clause"
  # PETSc's soname is major.minor (libpetsc.3.25.dylib), and it declares each
  # minor release ABI-incompatible. So dependents survive a PATCH bump
  # (3.25.3 -> 3.25.4) but not a MINOR one. Declaring that here lets Homebrew
  # skip rebuilding dependents across patch bumps.
  # INCREMENT THIS on every PETSc minor bump (3.25 -> 3.26), never on a patch.
  # Tracks homebrew-core, which did the same 1 -> 2 for its own 3.24 -> 3.25.
  compatibility_version 1

  livecheck do
    url "https://web.cels.anl.gov/projects/petsc/download/release-snapshots/"
    regex(/href=.*?petsc[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  bottle do
    root_url "https://github.com/dgarnier/homebrew-plasma/releases/download/petsc-complex-m3dc1-3.24.6"
    sha256 arm64_tahoe:   "944974197659ea8f68a898871cf909dae4a1ef008870533c9b367d248fb3cff3"
    sha256 arm64_sequoia: "9b6799d93c99820356b79b1472081183ddacaf91867098998afe5feb41401dee"
    sha256 arm64_sonoma:  "e2286a6707c35c9145e095ab583c66b667a9bff2cd256e825469263288633acd"
    sha256 x86_64_linux:  "0c3912d7353cf3684c99963e3ab48290325b8fea9045a5c882ae30ca6706f9fe"
  end

  # Unlike homebrew-core's petsc/petsc-complex, this build includes the
  # parallel direct solvers M3D-C1 expects (MUMPS, SuperLU_DIST). Keg-only so
  # it can coexist with core petsc, core petsc-complex and its own real
  # counterpart.
  keg_only "it is a specialised build that would shadow the `petsc-complex` formula"

  depends_on "dgarnier/plasma/mumps"
  depends_on "dgarnier/plasma/superlu-dist"
  depends_on "fftw"
  depends_on "gcc"
  depends_on "hdf5-mpi"
  depends_on "metis"
  depends_on "open-mpi"
  depends_on "scalapack"
  depends_on "scotch"

  uses_from_macos "python" => :build

  on_linux do
    depends_on "openblas"
  end

  def install
    args = %W[
      --prefix=#{prefix}
      --with-debugging=0
      --with-scalar-type=complex
      --with-x=0
      --CC=mpicc
      --CXX=mpicxx
      --F77=mpif77
      --FC=mpif90
      --with-fortran-interfaces=1
      --with-fftw-dir=#{formula_opt_prefix("fftw")}
      --with-hdf5-dir=#{formula_opt_prefix("hdf5-mpi")}
      --with-hdf5-fortran-bindings=1
      --with-metis-dir=#{formula_opt_prefix("metis")}
      --with-scalapack-dir=#{formula_opt_prefix("scalapack")}
      --with-ptscotch-dir=#{formula_opt_prefix("scotch")}
      --with-mumps-dir=#{formula_opt_prefix("dgarnier/plasma/mumps")}
      --with-superlu_dist-dir=#{formula_opt_prefix("dgarnier/plasma/superlu-dist")}
    ]

    # SuperLU_DIST can optionally use CUDA, so PETSc's configure runs its C++
    # dialect check against a CUDA compiler. Its last-resort guess is plain
    # `clang`, which on Linux resolves to Homebrew's compiler shim (there is no
    # real clang) -- that cannot compile CUDA, rejects every -std flag, and
    # configure aborts with "UNABLE to CONFIGURE with GIVEN OPTIONS".
    #
    # Note this needs --with-cudac=0 (disable the *compiler*, which skips
    # detection entirely) and not --with-cuda=0 (disable the *package*, which
    # leaves compiler detection running).
    args << "--with-cudac=0"

    # Accelerate on macOS, OpenBLAS elsewhere.
    args << if OS.mac?
      "--with-blaslapack-lib=-framework Accelerate"
    else
      "--with-blaslapack-dir=#{formula_opt_prefix("openblas")}"
    end

    system "./configure", *args, "MAKEFLAGS=$MAKEFLAGS"

    # Avoid references to Homebrew shims (must happen before `make`, or the
    # shim paths end up baked into compiled code).
    inreplace "arch-#{OS.kernel_name.downcase}-c-opt/include/petscconf.h",
              "#{Superenv.shims_path}/", ""

    system "make", "all"
    system "make", "install"

    # Avoid references to Homebrew shims
    rm(lib/"petsc/conf/configure-hash")

    if OS.mac? || File.foreach("#{lib}/petsc/conf/petscvariables").any? { |l| l[Superenv.shims_path.to_s] }
      inreplace lib/"petsc/conf/petscvariables", "#{Superenv.shims_path}/", ""
    end

    # Avoid references to cellar paths.
    gcc = Formula["gcc"]
    open_mpi = Formula["open-mpi"]
    inreplace (lib/"pkgconfig").glob("*.pc") do |s|
      s.gsub! prefix, opt_prefix
      s.gsub! gcc.prefix.realpath, gcc.opt_prefix
      s.gsub! open_mpi.prefix.realpath, open_mpi.opt_prefix
    end
  end

  test do
    # Solve a small system with each of the parallel direct solvers that
    # homebrew-core's petsc lacks -- the whole reason this formula exists.
    (testpath/"test.c").write <<~C
      static char help[] = "Solve a tiny system with a parallel direct solver.\\n";
      #include <petscksp.h>

      int main(int argc, char **argv) {
        Vec x, b;
        Mat A;
        KSP ksp;
        PetscInt i, n = 4, col[3], rstart, rend;
        PetscScalar value[3];

        PetscCall(PetscInitialize(&argc, &argv, NULL, help));
        PetscCall(MatCreate(PETSC_COMM_WORLD, &A));
        PetscCall(MatSetSizes(A, PETSC_DECIDE, PETSC_DECIDE, n, n));
        PetscCall(MatSetFromOptions(A));
        PetscCall(MatSetUp(A));
        PetscCall(MatGetOwnershipRange(A, &rstart, &rend));
        for (i = rstart; i < rend; i++) {
          if (i == 0) {
            col[0] = 0; col[1] = 1; value[0] = 2.0; value[1] = -1.0;
            PetscCall(MatSetValues(A, 1, &i, 2, col, value, INSERT_VALUES));
          } else if (i == n - 1) {
            col[0] = n - 2; col[1] = n - 1; value[0] = -1.0; value[1] = 2.0;
            PetscCall(MatSetValues(A, 1, &i, 2, col, value, INSERT_VALUES));
          } else {
            col[0] = i - 1; col[1] = i; col[2] = i + 1;
            value[0] = -1.0; value[1] = 2.0; value[2] = -1.0;
            PetscCall(MatSetValues(A, 1, &i, 3, col, value, INSERT_VALUES));
          }
        }
        PetscCall(MatAssemblyBegin(A, MAT_FINAL_ASSEMBLY));
        PetscCall(MatAssemblyEnd(A, MAT_FINAL_ASSEMBLY));

        PetscCall(MatCreateVecs(A, &x, &b));
        PetscCall(VecSet(b, 1.0));

        PetscCall(KSPCreate(PETSC_COMM_WORLD, &ksp));
        PetscCall(KSPSetOperators(ksp, A, A));
        PetscCall(KSPSetFromOptions(ksp));
        PetscCall(KSPSolve(ksp, b, x));

        /* Check the direct solve really solved it: ||Ax - b|| must be ~0. */
        Vec r;
        PetscReal rnorm;
        PetscCall(VecDuplicate(b, &r));
        PetscCall(MatMult(A, x, r));
        PetscCall(VecAXPY(r, -1.0, b));
        PetscCall(VecNorm(r, NORM_2, &rnorm));
        PetscCall(PetscPrintf(PETSC_COMM_WORLD, "residual=%s\\n",
                              rnorm < 1.0e-10 ? "ok" : "BAD"));

        PetscCall(VecDestroy(&r));
        PetscCall(VecDestroy(&x));
        PetscCall(VecDestroy(&b));
        PetscCall(MatDestroy(&A));
        PetscCall(KSPDestroy(&ksp));
        PetscCall(PetscFinalize());
        return rnorm < 1.0e-10 ? 0 : 1;
      }
    C

    flags = %W[-I#{include} -L#{lib} -lpetsc]
    flags << "-Wl,-rpath,#{lib}" if OS.linux?
    system "mpicc", "test.c", "-o", "petsc_test", *flags

    %w[mumps superlu_dist].each do |solver|
      assert_match "residual=ok", shell_output(
        "mpirun -np 1 ./petsc_test -ksp_type preonly -pc_type lu " \
        "-pc_factor_mat_solver_type #{solver}",
      )
    end
  end
end
