class FusionIo < Formula
  include Language::Python::Shebang

  desc "I/O library and field-line tracer for fusion simulation output (M3D-C1)"
  homepage "https://github.com/nferraro/fusion-io"
  # No tagged releases; pin a master commit (see README for the bump procedure).
  url "https://github.com/nferraro/fusion-io/archive/ed100545760e8401e778c79776ba6a3e238fb60b.tar.gz"
  version "1.0.0.dev20260508"
  sha256 "1d2e1a00836869e1ef662677d40669882676f5add0e99db94d40f3b69be67035"
  license "MIT"

  livecheck do
    skip "no tagged upstream releases; pinned to a master commit"
  end

  bottle do
    root_url "https://github.com/dgarnier/homebrew-plasma/releases/download/fusion-io-1.0.0.dev20260508"
    sha256 cellar: :any, arm64_tahoe:   "db025a4cd07f39349bb640e47bcdcb8f62df1bd5a5f427d409846e1e704f74cd"
    sha256 cellar: :any, arm64_sequoia: "dfe1f48664d79b192fab9f9391b5fcf8952f699da4a4f9f9baa9d6d7d00ebdf6"
    sha256 cellar: :any, arm64_sonoma:  "d0906002225d50b25ae0d9ef77dea53bc681b93a7b021e12dbed2b520b8040aa"
    sha256 cellar: :any, x86_64_linux:  "8a194fac139d17617d99ac5bea15c300f4603157f92f465e36c546031fa733dd"
  end

  depends_on "cmake" => :build
  depends_on "h5py-mpi" => :test
  depends_on "scipy" => :test
  depends_on "gcc"
  depends_on "hdf5-mpi"
  depends_on "open-mpi"
  depends_on "python@3.14"

  on_linux do
    depends_on "openblas"
  end

  def python3
    "python3.14"
  end

  def install
    site_packages = prefix/Language::Python.site_packages(python3)

    # Link the Python extension against the Module target (headers only, no
    # libpython) so it resolves Python symbols at load time instead of
    # hard-linking the framework (see `brew audit`).
    inreplace "fusion_io/CMakeLists.txt",
              "COMPONENTS Interpreter Development REQUIRED",
              "COMPONENTS Interpreter Development.Module REQUIRED"
    inreplace "fusion_io/CMakeLists.txt",
              "target_link_libraries(fio_py PUBLIC fusionio::fusionio Python3::Python)",
              "target_link_libraries(fio_py PUBLIC fusionio::fusionio Python3::Module)"

    system "cmake", "-S", ".", "-B", "build",
           "-DCMAKE_CXX_STANDARD=11",
           "-DCMAKE_C_COMPILER=mpicc",
           "-DCMAKE_CXX_COMPILER=mpicxx",
           "-DCMAKE_Fortran_COMPILER=mpif90",
           "-DPython3_EXECUTABLE=#{which(python3)}",
           "-DPYTHON_MODULE_INSTALL_PATH=#{site_packages}",
           *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"

    # Rename the trace binary to avoid naming conflicts
    mv bin/"trace", bin/"m3dc1_trace"
  end

  test do
    system python3, "-c", <<~PY
      import sys
      import os
      sys.path.insert(0, "#{prefix/Language::Python.site_packages(python3)}")
      import fpy
      print("fpy imported OK")
      os._exit(0)
    PY
    hdf5 = Formula["hdf5-mpi"]
    (testpath/"test.cpp").write <<~CPP
      #include <fusion_io.h>
      #include <hdf5.h>
      #include <iostream>
      #include <mpi.h>

      int main(int argc, char** argv) {
        // Silence HDF5 error reporting by passing NULL for both the handler and client data
        MPI_Init(&argc, &argv);
        H5Eset_auto(H5E_DEFAULT, NULL, NULL);

        fio_source *src = nullptr;
        int ierr = fio_open_source(&src, FIO_M3DC1_SOURCE, "nonexistent.h5");
        std::cout << "Return code: " << ierr << std::endl;
        int ret = ierr == FIO_SUCCESS ? 1 : 0; // opening a missing file must fail
        MPI_Finalize();
        std::_Exit(ret);
        //return ret;
      }
    CPP
    system "mpicxx", "test.cpp", "-std=c++11",
           "-I#{include}", "-I#{hdf5.opt_include}",
           "-L#{lib}", "-lfusionio_fusionio", "-lfusionio_m3dc1",
           "-L#{hdf5.opt_lib}", "-lhdf5",
           "-Wl,-rpath,#{lib}", "-Wl,-rpath,#{hdf5.opt_lib}",
           "-o", "test"
    system "mpirun", "-np", "1", "./test"
  end
end
