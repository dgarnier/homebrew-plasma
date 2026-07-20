class Pumi < Formula
  desc "Parallel Unstructured Mesh Infrastructure (SCOREC core)"
  homepage "https://www.scorec.rpi.edu/pumi/"
  # Pinned to the 2.2.x series: SCOREC v3+ replaced the global PCU API with a
  # handle-based one that M3D-C1's bundled m3dc1_scorec does not support yet.
  url "https://github.com/SCOREC/core/archive/refs/tags/v2.2.9.tar.gz"
  sha256 "5982b5f0e2ea69baf394af57fed5ae70d41be23ba54eca1644ece913f032a51c"
  license "BSD-3-Clause"

  livecheck do
    url :stable
    regex(/^v?(2\.\d+(?:\.\d+)+)$/i)
  end

  depends_on "cmake" => :build
  depends_on "dgarnier/plasma/zoltan"
  depends_on "metis"
  depends_on "open-mpi"

  def install
    # Our Zoltan is built without ParMETIS (graph partitioning falls back to
    # Zoltan's built-in PHG), so drop the hard ParMETIS requirement.
    inreplace "cmake/FindZoltan.cmake", "find_package(Parmetis MODULE REQUIRED)", ""
    ENV.append "LDFLAGS", "-lm" if OS.linux?

    system "cmake", "-S", ".", "-B", "build",
           "-DCMAKE_C_COMPILER=mpicc",
           "-DCMAKE_CXX_COMPILER=mpicxx",
           "-DBUILD_SHARED_LIBS=ON",
           "-DENABLE_ZOLTAN=ON",
           "-DZOLTAN_PREFIX=#{formula_opt_prefix("dgarnier/plasma/zoltan")}",
           *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    (testpath/"test.cc").write <<~CPP
      #include <mpi.h>
      #include <PCU.h>
      #include <apfMDS.h>
      #include <apfMesh2.h>
      #include <gmi_null.h>
      #include <cstdio>

      int main(int argc, char **argv) {
        MPI_Init(&argc, &argv);
        PCU_Comm_Init();
        gmi_register_null();
        gmi_model *model = gmi_load(".null");
        apf::Mesh2 *m = apf::makeEmptyMdsMesh(model, 2, false);
        apf::MeshEntity *v = m->createVert(nullptr);
        apf::Vector3 p(0, 0, 0);
        m->setPoint(v, 0, p);
        std::printf("verts=%d\\n", (int)m->count(0));
        m->destroyNative();
        apf::destroyMesh(m);
        PCU_Comm_Free();
        MPI_Finalize();
        return 0;
      }
    CPP
    zoltan = Formula["dgarnier/plasma/zoltan"]
    comp_args = ["-I#{include}", "-L#{lib}", "-L#{zoltan.opt_lib}",
                 "-lmds", "-lapf", "-lgmi", "-lpcu", "-llion", "-lmth",
                 "-std=c++11"]
    comp_args << "-lm" if OS.linux?
    system "mpicxx", "test.cc", "-o", "test", *comp_args
    system "mpirun", "-np", "1", "./test"
  end
end
