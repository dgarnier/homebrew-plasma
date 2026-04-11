class NetcdfMpi < Formula
  desc "Libraries and data formats for array-oriented scientific data"
  homepage "https://www.unidata.ucar.edu/software/netcdf/"
  url "https://github.com/Unidata/netcdf-c/archive/refs/tags/v4.10.0.tar.gz"
  sha256 "ce160f9c1483b32d1ba8b7633d7984510259e4e439c48a218b95a023dc02fd4c"
  license "BSD-3-Clause"
  compatibility_version 1
  head "https://github.com/Unidata/netcdf-c.git", branch: "main"

  livecheck do
    url :stable
    regex(/^(?:netcdf[._-])?v?(\d+(?:\.\d+)+)$/i)
  end

  bottle do
    root_url "https://github.com/dgarnier/homebrew-plasma/releases/download/netcdf-mpi-4.10.0"
    sha256 cellar: :any,                 arm64_tahoe:   "6f953225923b4b8622802343b413544df785ff4d6cd650882f5221f0dc70c752"
    sha256 cellar: :any,                 arm64_sequoia: "a48a518cc6cb53532bf4fbd8adb6cab1feb4b2d2510bf2d06cbc7d3d7cc647c0"
    sha256 cellar: :any,                 arm64_sonoma:  "72f089dea76a709ecc587ca10a2b6f24e4f822dc741e9ccb81df6a1817ff88b5"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "4f32b9aa8b99e9ca02a40db1e6eed6fc4fd40843b5e386f5f9de940ff7104831"
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
