class Mdsplus < Formula
  include Language::Python::Virtualenv
  desc "The MDSplus data management system"
  homepage "https://mdsplus.org/"
  license "MIT"
  #url "https://github.com/MDSplus/mdsplus"
  #url "https://github.com/MDSplus/mdsplus/tree/1d03558.git", :using 

  #url "https://github.com/MDSplus/mdsplus/archive/1d03558.zip"
  #sha256 "244139c73373adb076aa50239282e32c46ef4e04af3bdfd44943546c907f370e"
  head "https://github.com/MDSplus/mdsplus.git", branch: "alpha"
  
  depends_on "pkg-config" => :build
  depends_on "cmake" => [:build, :test]
  depends_on "ninja" => [:build, :test]
  depends_on "bison" => [:build]
  depends_on "gnu-tar" => :build

  #uses_from_macos "python" => :build
  uses_from_macos "libffi"
  uses_from_macos "libxml2"
  uses_from_macos "zlib"
  uses_from_macos "libiconv"
  uses_from_macos "liblzma"

  depends_on "python@3.13" => :build
  depends_on "readline"
  depends_on "openblas"
  depends_on "freetds"
  depends_on "libx11"
  depends_on "openmotif"
  depends_on "hdf5@1.14"

  # Additional dependency
  # resource "" do
  #   url ""
  #   sha256 ""
  # end

  keg_only "its the normal way to have mdsplus work"

  def install

    # Ensure mitdevices uses gtar (from gnu-tar) instead of "cmake -E tar"
    inreplace "mitdevices/CMakeLists.txt",
              '${CMAKE_COMMAND} -E tar -czf',
              '/opt/homebrew/bin/gtar -czf'

    inreplace "setup.sh", '/usr/local/mdsplus', opt_prefix
    inreplace "setup.csh", '/usr/local/mdsplus', opt_prefix

    # Prefer Homebrew-provided X11/Motif headers/libs so the build does not pick
    # up macOS SDK framework headers (e.g. Tk.framework) which can provide
    # incompatible X11/Xlib.h. d
    args = std_cmake_args + %W[
      -S .
      -B workspace/build
      -G Ninja
      -DMotif_X11_INCLUDE_DIR=#{Formula["libx11"].opt_include}
      -DENABLE_HDF5=ON
      -DHDF5_INCLUDE_DIR=#{Formula["hdf5"].opt_include}
      -DHDF5_LIBRARY_DIR=#{Formula["hdf5"].opt_lib}
      -DPLATFORM=macosx
      -DCMAKE_INSTALL_PREFIX=#{prefix}
    ]

    system "cmake", *args
    system "cmake", "--build", "workspace/build", "--", "-j#{ENV.make_jobs}"
    system "cmake", "--install", "workspace/build", "--prefix", "#{prefix}"


    # install didn't install python tests.. so comment them out 
    inreplace prefix/"python/MDSplus/pyproject.toml", "'MDSplus.tests'", "#'MDSplus.tests'"
    build_venv = virtualenv_create(buildpath/"venv", "python3.13")
    build_venv.pip_install "wheel"
    ENV.prepend_path "PATH", buildpath/"venv/bin"
    system "cd", prefix/"python", "&&", "python", "-m", "pip", "wheel", "--no-deps", "./MDSplus"
    system "rm", "-r", buildpath/"venv"

  end

  def caveats
    <<~EOS
      MDSplus installed as a keg-only package here:
        #{opt_prefix}

      It is recommended to add the following to your .zshrc:

      if [ -f #{opt_prefix}/setup.sh ]; then
        source #{opt_prefix}/setup.sh
      fi
    EOS
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
