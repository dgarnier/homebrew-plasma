class NetcdfMpi < Formula
  desc "Libraries and data formats for array-oriented scientific data"
  homepage "https://www.unidata.ucar.edu/software/netcdf/"
  url "https://github.com/Unidata/netcdf-c/archive/refs/tags/v4.10.1.tar.gz"
  sha256 "33c27231c478c3b35da7c7758fbdd02da1fe407abcb16ddfe195f69d164f930d"
  license "BSD-3-Clause"
  compatibility_version 1
  head "https://github.com/Unidata/netcdf-c.git", branch: "main"

  livecheck do
    url :stable
    regex(/^(?:netcdf[._-])?v?(\d+(?:\.\d+)+)$/i)
  end

  bottle do
    root_url "https://github.com/dgarnier/homebrew-plasma/releases/download/netcdf-mpi-4.10.1"
    sha256 cellar: :any, arm64_tahoe:   "c36721ff02804ad0e48dd784258981e941bf0878621ec30185891b5d48a9f8f6"
    sha256 cellar: :any, arm64_sequoia: "2681422433bef077c489e52cae2a6250b592730c590c23cb7ebe682ca92ef6c4"
    sha256 cellar: :any, arm64_sonoma:  "670e0fb399b909324961c707168062bf61b8fe0a13284ca41934d2242c6e29bd"
    sha256 cellar: :any, x86_64_linux:  "4a478e5b5cf3a6067b3e683e3eb00e368e00d538286c471546b2d5d50ba01912"
  end

  depends_on "cmake" => :build
  depends_on "hdf5-mpi"
  depends_on "open-mpi"

  uses_from_macos "m4" => :build
  uses_from_macos "bzip2"
  uses_from_macos "curl"
  uses_from_macos "libxml2"

  on_macos do
    depends_on "libaec"
    depends_on "zstd"
  end

  conflicts_with "netcdf", because: "both install nc-config and libraries"

  def install
    args = %w[-DNETCDF_ENABLE_TESTS=OFF -DNETCDF_ENABLE_HDF5=ON -DNETCDF_ENABLE_DOXYGEN=OFF]
    args += %w[-DCMAKE_SHARED_LINKER_FLAGS="-Wl,-undefined,dynamic_lookup,-twolevel_namespace"] if OS.mac?
    # Fixes "relocation R_X86_64_PC32 against symbol `stderr@@GLIBC_2.2.5' can not be used" on Linux
    args << "-DCMAKE_POSITION_INDEPENDENT_CODE=ON" if OS.linux?
    args << "-DNETCDF_ENABLE_PARALLEL_TESTS=ON"
    args << "-DNETCDF_MPIEXEC='mpirun'"

    ENV["CC"] = "mpicc"
    system "cmake", "-S", ".", "-B", "build_shared", *args, "-DBUILD_SHARED_LIBS=ON", *std_cmake_args
    system "cmake", "--build", "build_shared"
    system "cmake", "--install", "build_shared"
    system "cmake", "-S", ".", "-B", "build_static", *args, "-DBUILD_SHARED_LIBS=OFF", *std_cmake_args
    system "cmake", "--build", "build_static"
    lib.install "build_static/libnetcdf.a"

    # get rid of complaint about non libraries in lib
    libexec.install lib/"libnetcdf.settings"
    # Remove shim paths
    # inreplace [bin/"nc-config", lib/"pkgconfig/netcdf.pc", lib/"cmake/netCDF/netCDFConfig.cmake",
    #            lib/"libnetcdf.settings"], Superenv.shims_path/ENV.cc, ENV.cc
  end

  test do
    (testpath/"test.c").write <<~EOS
      #include <stdio.h>
      #include "netcdf_meta.h"
      int main()
      {
        printf(NC_VERSION);
        return 0;
      }
    EOS

    system "mpicc", "test.c", "-L#{lib}", "-I#{include}", "-lnetcdf",
                   "-o", "test"
    assert_equal version.to_s, `./test`
  end
end
