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

  option "without-tests", "Build without tests"
  
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

    # Prefer Homebrew-provided X11/Motif headers/libs so the build does not pick
    # up macOS SDK framework headers (e.g. Tk.framework) which can provide
    # incompatible X11/Xlib.h. d
    args = std_cmake_args + %W[
      -S .
      -B workspace/build
      -G Ninja
      -DMotif_X11_INCLUDE_DIR=#{Formula["libx11"].opt_include}
      -DPLATFORM=macosx
      -DCMAKE_INSTALL_PREFIX=#{prefix}
    ]

    #       -DENABLE_HDF5=ON
    #  -DHDF5_INCLUDE_DIR=#{Formula["hdf5"].opt_include}
    #  -DHDF5_LIBRARY_DIR=#{Formula["hdf5"].opt_lib}

    ENV["HDF5_DIR"] = Formula["hdf5"].opt_prefix


    # Ensure mitdevices uses gtar (from gnu-tar) instead of "cmake -E tar"
    inreplace "mitdevices/CMakeLists.txt",
              '${CMAKE_COMMAND} -E tar -czf',
              '/opt/homebrew/bin/gtar -czf'

    if build.with? "tests"
      inreplace "python/MDSplus/CMakeLists.txt" do |s|
        s.gsub!(/PATTERN "tests" EXCLUDE/, '# PATTERN "tests" EXCLUDE')
      end
      args = args + %W[
        -DBUILD_TESTING=ON
      ] 
    end

    inreplace [
        "setup.sh", "setup.csh", 
        "python/MDSplus/__init__.py",
        "python/MDSplus/version.py",
        "python/MDSplus/tree.py",
        "python/MDSplus/wsgi/__init__.py",
        "python/MDSplus/wsgi/doMdsip.py",
        "python/MDSplus/wsgi/conf/mdsplus.wsgi",
        "epics/archiver/Sdd2Mds",
        "cmake/FindMDSplus.cmake",
        "macosx/mdsip.plist",
        "tdi/treeshr/TreeShrHook.py.example",
      ], '/usr/local/mdsplus', opt_prefix



    system "cmake", *args
    system "cmake", "--build", "workspace/build", "--", "-j#{ENV.make_jobs}"
    system "cmake", "--install", "workspace/build", "--prefix", "#{prefix}"

    # prepend #!/bin/sh to these files so the get the right permissions
    # after homebrew "cleans up"
    inreplace [ bin/"job_finish", bin/"job_functions", 
                bin/"job_output", bin/"job_start",
                bin/"mdstcl", bin/"synchronize_unix"
              ] do |s|
                s.sub!(/\A(?!#!)/, "#!/bin/sh\n")
              end

    # install didn't install python tests.. so comment them out
    if build.without? "tests" 
      inreplace prefix/"python/MDSplus/pyproject.toml", "'MDSplus.tests'", "# 'MDSplus.tests'"
    end
    build_venv = virtualenv_create(buildpath/"venv", "python3.13")
    build_venv.pip_install "wheel"
    ENV.prepend_path "PATH", buildpath/"venv/bin"
    system "python3", "-m", "pip", "wheel", #"--no-deps", 
      "-w", prefix/"python", prefix/"python/MDSplus"
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
    ENV['MDSPLUS_DIR']=opt_prefix
    test_venv = virtualenv_create(testpath/"venv", "python3.13")
    ENV.prepend_path "PATH", testpath/"venv/bin"
    wheel = Dir[opt_prefix/"python/*.whl"].first
    system "python3", "-m", "pip", "install", wheel
    system "python3", "-c", "from unittest import TextTestRunner;" +
          "from MDSplus.tests import data_case as test_case;" +
          "TextTestRunner(verbosity=2).run(test_case.Tests.getTestSuite())"
  end
end
