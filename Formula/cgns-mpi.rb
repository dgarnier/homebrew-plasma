class CgnsMpi < Formula
  desc "CFD General Notation System"
  homepage "https://cgns.github.io/"
  url "https://github.com/CGNS/CGNS/archive/refs/tags/v4.5.2.tar.gz"
  sha256 "95075e1fd0b51d97b1b96b73ebe03b1a551fbcc9cd2b2b6f487ccccedcff5964"
  license "BSD-3-Clause"
  compatibility_version 1
  head "https://github.com/CGNS/CGNS.git", branch: "develop"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  bottle do
    root_url "https://github.com/dgarnier/homebrew-plasma/releases/download/cgns-mpi-4.5.1"
    rebuild 1
    sha256               arm64_tahoe:   "3652f854e5be3ab947b5e113be9d64fb215b6945763074c5ccddec8baf12bab8"
    sha256               arm64_sequoia: "d2a63c94013e8b00d52612e6159048135ce62fb3b91a5de5c2d467437bed7dd0"
    sha256               arm64_sonoma:  "f66c7145b4cc602ae7b9a2ff03f8ccb22394b96d6b23c890b8a661545a90a8ad"
    sha256 cellar: :any, x86_64_linux:  "cd15b48b79369eaeed4f54ec9507da75becde10f7ce76a8eea4f827dc3a021d6"
  end

  depends_on "cmake" => :build
  depends_on "gcc" # for gfortran
  depends_on "hdf5-mpi"
  depends_on "open-mpi"

  conflicts_with "cgns", because: "both install the `cgns` library"

  def install
    # CMake FortranCInterface_VERIFY fails with LTO on Linux due to different GCC and GFortran versions
    ENV.append "FFLAGS", "-fno-lto" if OS.linux?

    args = %w[
      -DCGNS_ENABLE_64BIT=YES
      -DCGNS_ENABLE_FORTRAN=YES
      -DHDF5_NEED_MPI=YES
    ]

    system "cmake", "-S", ".", "-B", "build", *std_cmake_args, *args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"

    # Avoid references to Homebrew shims
    inreplace include/"cgnsBuild.defs", Superenv.shims_path/ENV.cc, ENV.cc
  end

  test do
    (testpath/"test.c").write <<~C
      #include <stdio.h>
      #include "cgnslib.h"
      int main(int argc, char *argv[])
      {
        int filetype = CG_FILE_NONE;
        if (cg_is_cgns(argv[0], &filetype) != CG_ERROR)
          return 1;
        return 0;
      }
    C
    flags = %W[-L#{lib} -lcgns]
    flags << "-Wl,-rpath,#{lib},-rpath,#{formula_opt_lib("libaec")}" if OS.linux?
    system formula_opt_prefix("hdf5-mpi")/"bin/h5pcc", "test.c", *flags
    system "mpirun", "-np", "2", "./a.out"
  end
end
