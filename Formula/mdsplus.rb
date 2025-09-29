class Mdsplus < Formula
  desc "The MDSplus data management system"
  homepage "https://mdsplus.org/"
  license "MIT"
  head "https://github.com/MDSplus/mdsplus.git", branch: "cmake" 

  depends_on "python@3.13"
  depends_on "pkg-config" => :build
  depends_on "cmake" => [:build, :test]
  depends_on "ninja" => [:build, :test]
  depends_on "bison" => [:build]
  depends_on "gnu-tar" => :build

  uses_from_macos "libffi"
  uses_from_macos "libxml2"
  uses_from_macos "zlib"
  uses_from_macos "libiconv"

  depends_on "readline"
  depends_on "openblas"
  depends_on "freetds"
  depends_on "libx11"
  depends_on "openmotif"

  # Additional dependency
  # resource "" do
  #   url ""
  #   sha256 ""
  # end

  def install

    # Ensure mitdevices uses gtar (from gnu-tar) instead of "cmake -E tar"
    inreplace "mitdevices/CMakeLists.txt",
              '${CMAKE_COMMAND} -E tar -czf',
              '/opt/homebrew/bin/gtar -czf'

    # Prefer Homebrew-provided X11/Motif headers/libs so the build does not pick
    # up macOS SDK framework headers (e.g. Tk.framework) which can provide
    # incompatible X11/Xlib.h. Also disable CMake framework searching so
    # frameworks under the SDK are not added to the include path.
    args = std_cmake_args + %W[
      -S .
      -B workspace/build
      -G Ninja
      -DMotif_X11_INCLUDE_DIR=#{Formula["libx11"].opt_include}
      -DPLATFORM=macosx
      -DCMAKE_INSTALL_PREFIX=#{prefix}
    ]

    system "cmake", *args
    system "cmake", "--build", "workspace/build", "--", "-j#{ENV.make_jobs}"
    system "cmake", "--install", "workspace/build", "--prefix", prefix
  end

  test do
    # `test do` will create, run in and delete a temporary directory.
    #
    # This test will fail and we won't accept that! For Homebrew/homebrew-core
    # this will need to be a test that verifies the functionality of the
    # software. Run the test with `brew test MDSplus`. Options passed
    # to `brew install` such as `--HEAD` also need to be provided to `brew test`.
    #
    # The installed folder is not in the path, so use the entire path to any
    # executables being tested: `system bin/"program", "do", "something"`.
    system "false"
  end
end
