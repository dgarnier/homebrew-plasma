class CgnsMpi < Formula
  desc "CFD General Notation System"
  homepage "https://cgns.github.io/"
  url "https://github.com/CGNS/CGNS/archive/refs/tags/v4.5.1.tar.gz"
  sha256 "ae63b0098764803dd42b7b2a6487cbfb3c0ae7b22eb01a2570dbce49316ad279"
  license "BSD-3-Clause"
  compatibility_version 1
  head "https://github.com/CGNS/CGNS.git", branch: "develop"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  bottle do
    root_url "https://github.com/dgarnier/homebrew-plasma/releases/download/cgns-mpi-4.5.1"
    sha256                               arm64_tahoe:   "b76f7682fd9aac5895169fda0b311feb378b5f825038f9922f7c79dccf3760ea"
    sha256                               arm64_sequoia: "e8a938ba97c12d6524c892b16280a4d4620d80af388df39f7606a376b399cca9"
    sha256                               arm64_sonoma:  "cf2dafc94d74dc6c344cee9d75ca926ace83f8bad9608b7c0acd03f07f25ed8c"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "4f5a82eea52228257f6a1129179a240f0d9b685053f40b9d09d56c46b096458d"
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
    flags << "-Wl,-rpath,#{lib},-rpath,#{Formula["libaec"].opt_lib}" if OS.linux?
    system Formula["hdf5-mpi"].opt_prefix/"bin/h5pcc", "test.c", *flags
    system "mpirun", "-np", "2", "./a.out"
  end
end
