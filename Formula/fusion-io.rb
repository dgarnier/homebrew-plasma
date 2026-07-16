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

      int main() {
        // Silence HDF5 error reporting by passing NULL for both the handler and client data
        H5Eset_auto(H5E_DEFAULT, NULL, NULL);

        fio_source *src = nullptr;
        int ierr = fio_open_source(&src, FIO_M3DC1_SOURCE, "nonexistent.h5");
      #{"  "}
        std::cout << "Return code: " << ierr << std::endl;

        return ierr == FIO_SUCCESS ? 1 : 0; // opening a missing file must fail
      }
    CPP
    system "mpicxx", "test.cpp", "-std=c++11",
           "-I#{include}", "-I#{hdf5.opt_include}",
           "-L#{lib}", "-lfusionio_fusionio", "-lfusionio_m3dc1",
           "-L#{hdf5.opt_lib}", "-lhdf5",
           "-Wl,-rpath,#{lib}", "-Wl,-rpath,#{hdf5.opt_lib}",
           "-o", "test"
    system "./test"
  end
end
