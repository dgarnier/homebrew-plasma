class Zoltan < Formula
  desc "Parallel partitioning, load balancing and data-management services"
  homepage "https://sandialabs.github.io/Zoltan/"
  url "https://github.com/sandialabs/Zoltan/archive/refs/tags/v3.901.tar.gz"
  sha256 "030c22d9f7532d3076e40cba1f03a63b2ee961d8cc9a35149af4a3684922a910"
  license "BSD-3-Clause"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  bottle do
    root_url "https://github.com/dgarnier/homebrew-plasma/releases/download/zoltan-3.901"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:   "bb04d968f5d8374fd921ba1ed61b32b9a05e0d3c861a43916d217b56dbfbd8a3"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "72059af0cb1cba63276c96eca0c2ef1101f2e374fc5afef2a4a276055e60f7cb"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "3220bbe9d2d15600e332650e76f37123c605b9336f4a1d538485a3fd160da096"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "4c16455811c2c243800b567d1af893cd9adce89c03584195c3f224553e5fbfd9"
  end

  depends_on "open-mpi"

  def install
    # -fPIC so the static library can be linked into shared libraries (PUMI).
    Formula["open-mpi"]
    mkdir "zoltan-build" do
      args = ["--prefix=#{prefix}",
              #              "--enable-f90interface",
              "CC=mpicc",
              "CXX=mpicxx",
              "FC=mpif90",
              "CFLAGS=-fPIC",
              "CXXFLAGS=-fPIC"]
      # for some reason, linux needs -lm and also this is the way
      # to put it in
      args << "--with-libs=-lm" if OS.linux?
      system "../configure", *args

      system "make", "everything"
      system "make", "install"
    end
  end

  test do
    (testpath/"test.c").write <<~C
      #include <mpi.h>
      #include <stdio.h>
      #include <zoltan.h>

      int main(int argc, char **argv) {
        float ver;
        MPI_Init(&argc, &argv);
        if (Zoltan_Initialize(argc, argv, &ver) != ZOLTAN_OK) return 1;
        struct Zoltan_Struct *zz = Zoltan_Create(MPI_COMM_WORLD);
        if (!zz) return 1;
        Zoltan_Destroy(&zz);
        printf("Zoltan %.3f\\n", ver);
        MPI_Finalize();
        return 0;
      }
    C
    comp_args = ["-I#{include}", "-L#{lib}", "-lzoltan"]
    comp_args << "-lm" if OS.linux?
    system "mpicc", "test.c", "-o", "test", *comp_args
    system "mpirun", "-np", "2", "./test"
  end
end
