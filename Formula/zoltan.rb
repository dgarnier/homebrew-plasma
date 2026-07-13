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

  depends_on "open-mpi"

  def install
    # -fPIC so the static library can be linked into shared libraries (PUMI).
    ENV.append "LDFLAGS", "-lm" if OS.linux?
    mkdir "zoltan-build" do
      system "../configure", "--prefix=#{prefix}",
             "CC=mpicc",
             "CXX=mpicxx",
             "CFLAGS=-fPIC",
             "CXXFLAGS=-fPIC",
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
    system "mpicc", "test.c", "-I#{include}", "-L#{lib}", "-lzoltan", "-o", "test"
    system "mpirun", "-np", "2", "./test"
  end
end
