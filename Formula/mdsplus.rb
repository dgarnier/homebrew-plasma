class Mdsplus < Formula
  include Language::Python::Virtualenv
  desc "The MDSplus data management system"
  homepage "https://mdsplus.org/"
  license "MIT"
  #license_files ["MDSplus-license.txt", "MDSplus-license.rtf"]

  url "https://github.com/MDSplus/mdsplus.git", revision: "f11259dec7874a88b2ab0af4456b393923fdf87e"
  version 'alpha_release-7-153-7'

  head "https://github.com/MDSplus/mdsplus.git", branch: "alpha"

  option "without-tests", "Build without tests"
  
  depends_on "pkg-config" => :build
  depends_on "cmake" => [:build, :test]
  depends_on "ninja" => [:build, :test]
  depends_on "bison" => [:build]
  depends_on "gnu-tar" => :build
  depends_on "doxygen" => :build

  #uses_from_macos "python" => :build
  uses_from_macos "libffi"
  uses_from_macos "libxml2"
  uses_from_macos "zlib"
  uses_from_macos "libiconv"
  uses_from_macos "blas"  # use macos Accelerate framework
  
  # these dont seem to work, so replace with homebrew-provided ones
  #uses_from_macos "readline"
  #uses_from_macos "xz"  # liblzma somehow this isn't getting used
  
  depends_on "python@3.13" => :build
  depends_on "readline"
  depends_on "xz"
  # depends_on "openblas"
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

    # fix python testing.. either with or without tests
    if build.with? "tests"
      inreplace "python/MDSplus/pyproject.toml", "[tool.setuptools.package-data]",
        "[tool.setuptools.package-data]\n\t'MDSplus.tests'=['devices/*', 'images/*', 'trees/*', 'mdsip.hosts']\n"
      args = args + %W[
        -DBUILD_TESTING=ON
      ]
    else
      inreplace "python/MDSplus/pyproject.toml", "'MDSplus.tests'", "# 'MDSplus.tests'"
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

    # add python tests in final install (though cmake would not include them)
    if build.with? "tests"
      (prefix/"python/MDSplus").install Dir["python/MDSplus/tests"]
      rm prefix/"python/MDSplus/tests/Makefile.am"
      rm prefix/"python/MDSplus/tests/CMakeLists.txt"
    end
    
    # build python wheel 
    build_venv = virtualenv_create(buildpath/"venv", "python3.13")
    build_venv.pip_install "wheel"
    ENV.prepend_path "PATH", buildpath/"venv/bin"
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
    EOS
  end

  test do
    # `test do` will create, run in and delete a temporary directory.

    # setup python
    test_venv = virtualenv_create(testpath/"venv", "python3.13")
    ENV.prepend_path "PATH", testpath/"venv/bin"
    # image library
    test_venv.pip_install "pillow" 
    wheel = Dir[opt_prefix/"python/*.whl"].first
    system "python3", "-m", "pip", "install", wheel

    # setup MDSplus environment
    ENV['MDSPLUS_DIR']=opt_prefix
    # do normal mdsplus/setup.sh stuff
    shell_output("source #{opt_prefix}/setup.sh && printenv").each_line do |line|
      key, value = line.chomp.split('=', 2)
      ENV[key] = value if key && !key.empty?
    end

    # get python tests resource directory
    test_dir = shell_output('python -c "from importlib.resources import files; print(files(\"MDSplus.tests\"))"').chomp
    #puts test_dir

    # add test devices and trees
    ENV.prepend_path "MDS_PYDEVICE_PATH", test_dir+"/devices"
    # can't use ENV prepend_*path because MDSplus uses semicolons instead of colons.. sigh
    ENV['default_tree_path']=(testpath/"trees").to_s+";"+test_dir+"/trees;"+(opt_prefix/"trees").to_s
    ENV['main_path']=opt_prefix/"trees"
    ENV['subtree_path']=opt_prefix/"trees/subtree"

    #output = shell_output("printenv")
    #puts output

    output = shell_output('python3 -c "from MDSplus.tests import exception_case as t; t.Tests.runTests()" 2>&1')
    assert_match "OK (skipped=1)", output.lines.last.chomp
    output = shell_output('python3 -c "from MDSplus.tests import tree_case as t; t.Tests.runTests()" 2>&1')
    assert_match "OK", output.lines.last.chomp
    output = shell_output('python3 -c "from MDSplus.tests import data_case as t; t.Tests.runTests()" 2>&1')
    assert_equal "OK", output.lines.last.chomp
    output = shell_output('python3 -c "from MDSplus.tests import devices_case as t; t.Tests.runTests()" 2>&1')
    puts output
    #assert_equal "OK", output.lines.last.chomp
    assert_match "OK", output.lines[-2].chomp
    output = shell_output('python3 -c "from MDSplus.tests import segment_case as t; t.Tests.runTests()" 2>&1')
    puts output
    #assert_equal "OK", output.lines.last.chomp

    output = shell_output('python3 -c "from MDSplus.tests import dcl_case as t; t.Tests.runTests()" 2>&1')
    puts output
    assert_equal "OK", output.lines.last.chomp
    
  end
end
