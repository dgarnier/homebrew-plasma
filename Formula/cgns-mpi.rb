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
    root_url "https://github.com/dgarnier/homebrew-plasma/releases/download/cgns-mpi-4.5.2"
    sha256               arm64_tahoe:   "0b9c6e0a60518b477e668406e5a961875bbfc13c79005ab0464e00f0c0cc51ae"
    sha256               arm64_sequoia: "5fb2c00e81939960ae319a0e9a5acc1b580536d97ae479e793b20f47b0115a0c"
    sha256               arm64_sonoma:  "aad60a83052be7333ecd1a12cefb68bacc6062621d2dfadc53a788a26ff357d7"
    sha256 cellar: :any, x86_64_linux:  "593157b4a28c8e756f3fa25c1a0e27c7f72b445bae2657e3d471158770e87f11"
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
