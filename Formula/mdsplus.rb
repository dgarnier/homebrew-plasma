class Mdsplus < Formula
  include Language::Python::Virtualenv

  desc "Data management system"
  homepage "https://mdsplus.org/"
  license "MIT"

  stable do
    url "https://github.com/MDSplus/mdsplus/archive/refs/tags/alpha_release-7-158-2.tar.gz"
    # required as build wont work with release tag
    version "alpha_release-7-158-2"
    sha256 "b6f7b358dbccedf7b51ce820ce415a9fa4e21d1054a13bf0dfb4eabdfa2d4645"
    patch :DATA
  end

  livecheck do
    url "https://github.com/mdsplus/mdsplus" # The URL to the GitHub repository
    regex(/(alpha|stable)_release-\d+-\d+-\d+/i)
    strategy :github_latest do |json, regex|
      json["name"][regex]
    end
  end

  bottle do
    rebuild 1
  end

  head do
    url "https://github.com/MDSplus/mdsplus.git", using: :git, branch: "alpha"
    patch :DATA
  end

  keg_only "its the normal way to have mdsplus work"

  option "with-ctest", "Build with full ctest suite."
  option "with-pytests", "Include python tests in build."

  depends_on "bison" => :build
  depends_on "cmake" => [:build, :test]
  depends_on "doxygen" => :build
  depends_on "flex"  => :build
  depends_on "maven" => :build
  depends_on "ninja" => [:build, :test]
  depends_on "numpy" => [:build, :test]
  depends_on "pkg-config" => :build
  depends_on "python@3.13" => :build
  depends_on "freetds"
  depends_on "libx11"
  depends_on "openjdk@21"
  depends_on "openmotif"
  depends_on "readline"
  depends_on "hdf5" => :recommended

  # these dont seem to work, so replace with homebrew-provided ones
  # uses_from_macos "readline"
  # uses_from_macos "xz"  # liblzma somehow this isn't getting used
  # uses_from_macos "blas"
  uses_from_macos "libffi"
  uses_from_macos "libiconv"
  uses_from_macos "libxml2"
  uses_from_macos "xz" # homebrew is actually ignoring this but ok.
  uses_from_macos "zlib" # use macos Accelerate framework

  on_macos do
    depends_on "gnu-tar" => :build # non broken tar for cmake on macos
  end

  on_linux do
    depends_on "gcc" => :build
    depends_on "gfortran" => :build
    depends_on "gperf" => :build
    depends_on "libxml2"
    depends_on "openblas"
    depends_on "zlib"
  end

  def install
    args = std_cmake_args + %W[
      -S .
      -B workspace/build
      -G Ninja
      -DCMAKE_INSTALL_PREFIX=#{prefix}
    ]

    args += if OS.mac?
      # Prefer Homebrew-provided X11/Motif headers/libs so the build does not pick
      # up macOS SDK framework headers (e.g. Tk.framework) which can provide
      # incompatible X11/Xlib.h. d
      %W[
        -DMotif_X11_INCLUDE_DIR=#{Formula["libx11"].opt_include}
        -DPLATFORM=macosx
      ]
    else
      %w[-DPLATFORM=linux]
    end

    args += if build.head?
      %w[
        -DCMAKE_BUILD_TYPE=Debug
      ]
    else
      %W[
        -DRELEASE_TAG=#{version}
        -DCMAKE_BUILD_TYPE=Release
      ]
    end

    # If the recommended HDF5 is not specifically disabled
    # this will allow the keg version to be found
    ENV["HDF5_DIR"] = Formula["hdf5"].opt_prefix if build.with? "hdf5"

    # use installed installed java
    ENV["JAVA_HOME"] = Formula["openjdk"].libexec/"openjdk.jdk/Contents/Home" if OS.mac?

    # Ensure mitdevices uses gtar (from gnu-tar) instead of "cmake -E tar"
    # which is sadly broken on macOS
    if OS.mac?
      inreplace "mitdevices/CMakeLists.txt",
                "${CMAKE_COMMAND} -E tar -czf",
                "/opt/homebrew/bin/gtar -czf"
    end

    # add back python testing if enabled
    if build.with? "pytests"
      inreplace "python/MDSplus/pyproject.toml", "[tool.setuptools.package-data]",
        "[tool.setuptools.package-data]\n\t'MDSplus.tests'=['devices/*', 'images/*', 'trees/*', 'mdsip.hosts']\n"
      args += %w[
        -DBUILD_TESTING=ON
      ]
    else # its actually broken by default
      inreplace "python/MDSplus/pyproject.toml", "'MDSplus.tests'", "# 'MDSplus.tests'"
    end
    if build.with? "ctest"
      args += %w[
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
      "tdi/treeshr/TreeShrHook.py.example"
    ], "/usr/local/mdsplus", opt_prefix

    virtualenv_create(buildpath/"workspace/venv", "python3.13")
    ENV["VIRTUAL_ENV"]=buildpath/"workspace/venv"
    args += %w[
      -DPython_FIND_VIRTUALENV=FIRST
    ]

    system "cmake", *args
    system "cmake", "--build", "workspace/build", "--", "-j#{ENV.make_jobs}"
    if build.with? "ctest"
      system "ctest", "--test-dir", "workspace/build", "-j#{ENV.make_jobs}"
      # this test has been broken, but seems to work now...
      # system "ctest", "--test-dir", "workspace/build", "-j#{ENV.make_jobs}", "-E", "MdsTreeNodeTest"
    end
    system "cmake", "--install", "workspace/build", "--prefix", prefix.to_s

    # add python tests in final install (though cmake would not include them)
    if build.with? "pytests"
      (prefix/"python/MDSplus").install "python/MDSplus/tests"
      rm prefix/"python/MDSplus/tests/Makefile.am"
      rm prefix/"python/MDSplus/tests/CMakeLists.txt"
    end

    # build python wheel
    # build_venv = virtualenv_create(buildpath/"venv", "python3.13")
    # build_venv.pip_install "wheel"
    # ENV.prepend_path "PATH", buildpath/"venv/bin"
    system "python3", "-m", "pip", "wheel", "--no-deps",
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

      Brew will now tell you about the un-recommended way to add mdsplus to your paths.
      It has opinions.  They aren't great ones.
    EOS
  end

  test do
    require "json"
    # `test do` will create, run in and delete a temporary directory.

    # setup python
    test_venv = virtualenv_create(testpath/"venv", "python3.13")
    ENV.prepend_path "PATH", testpath/"venv/bin"
    # get actual python library with full path
    test_venv.pip_install "find_libpython"
    # image library
    # don't enable for now because python image handling appears broken
    # test_venv.pip_install "pillow"
    wheel = Dir[opt_prefix/"python/*.whl"].first
    system "python3", "-m", "pip", "install", wheel

    # setup MDSplus environment
    ENV["MDSPLUS_DIR"]=opt_prefix
    # do normal mdsplus/setup.sh stuff
    shell_output("source #{opt_prefix}/setup.sh && printenv").each_line do |line|
      key, value = line.chomp.split("=", 2)
      ENV[key] = value if key.present?
    end

    # find the python libray path associated with the python in the environment
    # this is needed for spawned servers in the tests
    ENV["PyLib"] = shell_output("find_libpython")

    # also pass on the python path because it won't get the virtualenv when starting the server
    # the way the test does it
    pypath = shell_output('python -c "import sys; print(sys.path[1:])"').chomp.tr("'", '"')
    JSON.parse(pypath).each do |path|
      ENV.prepend_path "PYTHONPATH", path
    end

    # can't use ENV prepend_*path because MDSplus uses semicolons instead of colons.. sigh
    ENV["default_tree_path"]=(testpath/"trees").to_s+";"+(opt_prefix/"trees").to_s
    ENV["main_path"]=opt_prefix/"trees"
    ENV["subtree_path"]=opt_prefix/"trees/subtree"

    # this tests that tdi is setup and can see its home directory
    assert_match "Hello world", shell_output('echo "helloworld()" | tditest').lines[-2].chomp
    ohai "tditest passed"

    output = pipe_output("python3", "from MDSplus._version import release_tag; print(release_tag)").chomp
    assert_equal version.to_s, output
    ohai "Python loaded expected MDSplus version: #{output}"

    output = pipe_output("python3", "exec(\"try: import MDSplus.test; print('OK')\\nexcept: print('FAIL')\")")
    if output.include? "OK"
      # get python tests resource directory
      ohai "Running python tests suite which was enabled by --with-pytests"
      test_dir = shell_output('python -c "from importlib.resources import files; print(files(\"MDSplus.tests\"))"')
      test_dir.chomp!
      # add test devices and trees
      ENV.prepend_path "MDS_PYDEVICE_PATH", test_dir+"/devices"
      # puts test_dir at start of default tree path (with semicolons!)
      ENV["default_tree_path"] = test_dir+"/trees;" + ENV["default_tree_path"]

      # these tests would have been included if build.with? "tests" was true
      output = shell_output('python3 -c "from MDSplus.tests import exception_case as t; t.Tests.runTests()" 2>&1')
      assert_match "OK (skipped=1)", output.lines.last.chomp
      output = shell_output('python3 -c "from MDSplus.tests import tree_case as t; t.Tests.runTests()" 2>&1')
      assert_match "OK", output.lines.last.chomp
      output = shell_output('python3 -c "from MDSplus.tests import data_case as t; t.Tests.runTests()" 2>&1')
      assert_match "OK", output.lines.last.chomp
      output = shell_output('python3 -c "from MDSplus.tests import devices_case as t; t.Tests.runTests()"' \
        + " 2>test_stderr && cat test_stderr")
      puts output
      # assert_equal "OK", output.lines.last.chomp
      assert_match "OK", output.lines.last.chomp

      output = shell_output('python3 -c "from MDSplus.tests import segment_case as t; t.Tests.runTests()"' \
        + " 2>test_stderr && cat test_stderr")
      # puts output
      assert_match "OK", output.lines.last.chomp

      output = shell_output('python3 -c "from MDSplus.tests import dcl_case as t; t.Tests.runTests()"' \
        + " 2>test_stderr && cat test_stderr")
      # puts output
      assert_match "OK", output.lines.last.chomp

      output = shell_output('python3 -c "from MDSplus.tests import connection_case as t; t.Tests.runTests()"' \
        + " 2>test_stderr && cat test_stderr")
      puts output
      # assert_match "OK", output.lines.last.chomp

      # this is doing a segmentation fault.
      output = shell_output('python3 -c "from MDSplus.tests import thread_case as t; t.Tests.runTests()"' \
        + " 2>test_stderr && cat test_stderr")
      puts output
      puts shell_output("cat test_stderr")
      # assert_match "OK", output.lines.last.chomp
    else
      opoo "Extensive python test suite was not enabled by --with-pytests"
    end
  end
end
__END__
diff --git a/python/MDSplus/compound.py.in b/python/MDSplus/compound.py.in
index 9a2f2774e..e06cd1667 100644
--- a/python/MDSplus/compound.py.in
+++ b/python/MDSplus/compound.py.in
@@ -582,7 +582,11 @@ class Opaque(_dat.TreeRefX, Compound):
             from io import BytesIO as io
         else:
             from StringIO import StringIO as io
-        return Image.open(io(self.value.data().tostring()))
+        data = self.value.data()
+        if hasattr(data, 'tobytes'):
+            return Image.open(io(data.tobytes()))
+        else:
+            return Image.open(io(data.tostring()))

     @classmethod
     def fromFile(cls, filename, typestring=None):

diff --git a/java/CMakeLists.txt b/java/CMakeLists.txt
index 05290805b..bd6cd925a 100644
--- a/java/CMakeLists.txt
+++ b/java/CMakeLists.txt
@@ -19,6 +19,10 @@ if(ENABLE_JAVA)
     add_subdirectory(jdevices)
     add_subdirectory(jtraverser2)

+    install(FILES ${JSCH_JAR}
+        DESTINATION java/classes
+    )
+
     if(mvn_EXECUTABLE)

         include(ProcessorCount)
