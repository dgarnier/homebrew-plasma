class Tetgen < Formula
  desc "Quality Tetrahedral Mesh Generator and a 3D Delaunay Triangulator"
  homepage "http://tetgen.org/"
  url "https://github.com/TetGen/TetGen/archive/refs/tags/v1.5.1.zip"
  version "v1.5.1"
  license "AGPLv3"
  sha256 "11075fb5d3fcfd37788a66d58e81e38c43ef94d59de6fc5b66bd414c2c1cd9f0"
  
  depends_on "cmake" => :build

  resource "manual" do
    url "https://codeberg.org/TetGen/Manuals/src/branch/main/tetgen-manual-1.5.pdf"
    sha256 "457085c2fb9aeb3fd268edcaf621d02adfb8d87072f8ccb994a0dfc38eedaf9b"
  end

  def install
    mkdir "build" do
      system "cmake", "..", *std_cmake_args, "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
      system "make"
      bin.install "tetgen"
      lib.install "libtet.a"
      include.install buildpath/"tetgen.h"
      resource("manual").stage do
        doc.install "tetgen-manual-1.5.pdf"
      end
      pkgshare.install buildpath/"example.poly"
    end
  end

  test do
    cp pkgshare/"example.poly", testpath
    output = shell_output("#{bin}/tetgen -pq1.2V example.poly")
    assert_match /[Ss]tatistics/, output, "Missing statistics in output"
    assert_match /[Hh]istogram/, output, "Missing histogram in output"
    assert_match /seconds/, output, "Missing timings in output"
    outfile_suffixes = %w[node ele face edge]
    outfile_suffixes.each do |suff|
      assert_predicate testpath/"example.1.#{suff}", :exist?
      rm testpath/"example.1.#{suff}"
    end
    cp testpath/"example.poly", testpath/"example.node"
    system "#{bin}/tetgen", testpath/"example.node"
    outfile_suffixes -= ["edge"]
    outfile_suffixes.each do |suff|
      assert_predicate testpath/"example.1.#{suff}", :exist?
    end
  end
end