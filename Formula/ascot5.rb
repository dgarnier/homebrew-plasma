# Documentation: https://docs.brew.sh/Formula-Cookbook
#                https://rubydoc.brew.sh/Formula
# PLEASE REMOVE ALL GENERATED COMMENTS BEFORE SUBMITTING YOUR PULL REQUEST!
class Ascot5 < Formula
  include Language::Python::Virtualenv

  desc "ASCOT5 is a high-performance orbit-following code for fusion plasma physics and engineering"
  homepage "https://ascot4fusion.github.io/ascot5/"
  url "https://github.com/ascot4fusion/ascot5/archive/refs/tags/5.6.3.zip"
  sha256 "3b518b772cc8ad1bc0ab2fa6fab859cad26bb0246ad431241b35a7c26c7fe010"
  license "LGPL-3.0"

  head "https://github.com/ascot4fusion/ascot5.git"

  depends_on "make" => :build
  # depends_on "uv" => :build
  depends_on "cmake" => :build  # because clang python does
  depends_on "ninja" => :build  # because its required by cmake sometimes
  depends_on "cython" => :build
  depends_on "libomp"
  depends_on "open-mpi"
  depends_on "llvm@19"
  depends_on "hdf5-mpi"
  depends_on "h5py-mpi"
  depends_on "python@3.14"
  depends_on "python-tk@3.14"

  #for pyvista
  depends_on "vtk"
  depends_on "pillow"


  # for alphashape
  depends_on "geos"
  depends_on "spatialindex"

  # ascot5 relies on ctypeslib2 for Python bindings
  # and calls a code called clang2py to generate the bindings
  # the latest release (2.4.0), claims to be for clang 19 and python 3.13

  depends_on "numpy"
  depends_on "scipy"
  depends_on "python-matplotlib"
  depends_on "mpi4py"
  depends_on "symengine"
  depends_on "h5py-mpi"


  resource "wurlitzer" do
    url "https://files.pythonhosted.org/packages/9a/24/93ce54550a9dd3fd996ed477f00221f215bf6da3580397fbc138d6036e2e/wurlitzer-3.1.1-py3-none-any.whl"
    sha256 "0b2749c2cde3ef640bf314a9f94b24d929fe1ca476974719a6909dfc568c3aac"
  end
  resource "pyvista" do
    url "https://files.pythonhosted.org/packages/84/52/a98dea948d9782b80e8e60804097fee7f7bd8fed92c9d4f0c657e4c3a6f8/pyvista-0.47.1-py3-none-any.whl"
    sha256 "eb8cee6b6246c41f1a9d2d07e662ec7d0192ea5cf585d64ebf1266774258df59"
  end
  resource "freeqdsk" do
    url "https://files.pythonhosted.org/packages/3b/c3/27c40f49900c200ff1655af3070cd5f9e796e39e85e3d7edb452a9874f30/freeqdsk-0.5.2-py3-none-any.whl"
    sha256 "36f9b614b03b7af930b5239e1f9e0ea2da4a8b16de8284b8e8c96a8160a08895"
  end
  resource "unyt" do
    url "https://files.pythonhosted.org/packages/53/8a/889bfb9c7fe296e8f6224498d173442250b3ee4706d04d286971a348e07c/unyt-3.1.0-py3-none-any.whl"
    sha256 "6ff9efe694a1c13f5b07ccb4c6b30a0e282d5e4989947f0ef5aadf4ad7be3f69"
  end
  resource "sympy" do
    url "https://files.pythonhosted.org/packages/a2/09/77d55d46fd61b4a135c444fc97158ef34a095e5681d0a6c10b75bf356191/sympy-1.14.0-py3-none-any.whl"
    sha256 "e091cc3e99d2141a0ba2847328f5479b05d94a6635cb96148ccb3f34671bd8f5"
  end
  resource "mpmath" do
    url "https://mpmath.org/files/mpmath-1.4.0.tar.gz"
    sha256 "d272b40c031ba0ee385e7e5fc735b48560d9838a0d7fbca109919efd23580a22"
  end
  resource "xmlschema" do
    url "https://files.pythonhosted.org/packages/da/c4/ef78a231be72349fd6677b989ff80e276ef62e28054c36c4fea3b4db9611/xmlschema-4.3.1.tar.gz"
    sha256 "853effdfaf127849d4724368c17bd669e7f1486e15a0376404ad7954ec31a338"
  end
  resource "elementpath" do
    url "https://files.pythonhosted.org/packages/94/95/eeb61a2a917bf506d1402748e71c62399d8dcdd8cdccd64c81962832c260/elementpath-5.1.1.tar.gz"
    sha256 "c4d1bd6aed987258354d0ea004d965eb0a6818213326bd4fd9bde5dacdb20277"
  end
  resource "shapely" do
    url "https://files.pythonhosted.org/packages/4d/bc/0989043118a27cccb4e906a46b7565ce36ca7b57f5a18b78f4f1b0f72d9d/shapely-2.1.2.tar.gz"
    sha256 "2ed4ecb28320a433db18a5bf029986aa8afcfd740745e78847e330d5d94922a9"
  end
  resource "trimesh" do
    url "https://files.pythonhosted.org/packages/0d/bf/53b69f3b6708c20ceb4d1d1250c7dc205733eb646659e5e55771f76ffabd/trimesh-4.11.5.tar.gz"
    sha256 "b90e6cdd6ada51c52d4a7d32947f4ce44b6751c5b7cab2b04e271ecea1e397d3"
  end
  resource "rtree" do
    url "https://files.pythonhosted.org/packages/95/09/7302695875a019514de9a5dd17b8320e7a19d6e7bc8f85dcfb79a4ce2da3/rtree-1.4.1.tar.gz"
    sha256 "c6b1b3550881e57ebe530cc6cffefc87cd9bf49c30b37b894065a9f810875e46"
  end
  resource "alphashape" do
    url "https://files.pythonhosted.org/packages/2e/83/67ff905694df5b34a777123b59fdfd05998d5a31766f188aafbf5b340055/alphashape-1.3.1.tar.gz"
    sha256 "7a27340afc5f8ed301577acec46bb0cf2bada5410045f7289142e735ef6977ec"
  end
  resource "typing_extensions" do
    url "https://files.pythonhosted.org/packages/72/94/1a15dd82efb362ac84269196e94cf00f187f7ed21c242792a923cdb1c61f/typing_extensions-4.15.0.tar.gz"
    sha256 "0cea48d173cc12fa28ecabc3b837ea3cf6f38c6d1136f85cbaaf598984861466"
  end
  resource "scooby" do
    url "https://files.pythonhosted.org/packages/d1/d1/a28f3be1503a9c474a4878424bbeb93a55a2ec7d0cb66559aa258e690aea/scooby-0.11.0.tar.gz"
    sha256 "3dfacc6becf2d6558efa4b625bae3b844ced5d256f3143ebf774e005367e712a"
  end
  resource "cyclopts" do
    url "https://files.pythonhosted.org/packages/6c/c4/2ce2ca1451487dc7d59f09334c3fa1182c46cfcf0a2d5f19f9b26d53ac74/cyclopts-4.10.1.tar.gz"
    sha256 "ad4e4bb90576412d32276b14a76f55d43353753d16217f2c3cd5bdceba7f15a0"
  end
  resource "pooch" do
    url "https://files.pythonhosted.org/packages/83/43/85ef45e8b36c6a48546af7b266592dc32d7f67837a6514d111bced6d7d75/pooch-1.9.0.tar.gz"
    sha256 "de46729579b9857ffd3e741987a2f6d5e0e03219892c167c6578c0091fb511ed"
  end

  # Additional dependencies for building
  resource "clang" do
    url "https://files.pythonhosted.org/packages/65/f3/5906d54f4a6e52b76a184cbc22a1b76cd4787908fa2fab43a177b1437930/clang-19.1.7.tar.gz"
    #pypi "clang", version: "19.1.7"
    sha256 "bf8b109db34b72853f8a7c9baa89c9782a657e6c29763fce5bd773043385bcef"
  end
  resource "ctypeslib2" do
    url "https://files.pythonhosted.org/packages/b7/c2/0c939a5f852c148ab221cc438e0e335c94f7724df163df5933ebace7c5d6/ctypeslib2-2.4.0.tar.gz"
    #pypi "ctypeslib2", version: "2.4.0"
    sha256 "1dd0f1ab679394bd44addb979d9e05b9d06669e907d94255fddbd0c3ca2f293e"
  end

  def install

    inreplace "src/Makefile", "-shlib", ""

    ENV["MPI"] = "1"

    # Use the clang provided by the keg-only llvm@19 formula.
    llvm = Formula["llvm@19"]
    omp = Formula["libomp"]
    hdf5 = Formula["hdf5-mpi"]
    mpi = Formula["open-mpi"]
    # Ensure the llvm bin dir is first on PATH so its clang/clang++ are found.
    ENV.prepend_path "PATH", llvm.opt_bin.to_s

    # Use clang/clang++ from llvm@19 as the C and C++ compilers.
    ENV["OMPI_CC"] = (llvm.opt_bin/"clang").to_s
    #ENV["CFLAGS"] = "-I#{omp.opt_include} -lomp -lhdf5 -lhdf5_hl"
    ENV["LDFLAGS"] = "-L#{omp.opt_lib} -lomp -L#{hdf5.opt_lib} -lhdf5 -lhdf5_hl"
    ENV["CFLAGS"] = "-I#{omp.opt_include}"

    on_macos do
      # just make for current version of os if building from source
      ENV["MACOSX_DEPLOYMENT_TARGET"] = `sw_vers -productVersion`.chomp
    end

    # these make them in the builddir but don't get installed
    system "make", "libascot", "-j"
    system "make", "ascot5_main", "-j"
    system "make", "bbnbi5", "-j"

    ENV.prepend_path "PATH", llvm.opt_bin

    # build a venv for ctypeslib2 and clang
    # so that it can run the right clang2py and link the right clang library
    bvenv = virtualenv_create(buildpath/".venv", "python3.14")
    #ENV.prepend_path "PATH", venv
    bvenv.pip_install resource("ctypeslib2")
    bvenv.pip_install resource("clang")
    ENV.prepend_path "PATH", buildpath/".venv/bin"

    # make sure ctypeslib2 finds the right clang library which matches the python clang we just built
    ENV["CLANG_LIBRARY_PATH"] = "#{llvm.opt_lib}"
    ENV["CFLAGS"] = "#{ENV["CFLAGS"]} -I#{mpi.opt_include}"

    # look in lib
    inreplace ".setcdllascot2py.py", "libpath = str(Path(__file__).absolute().parent.parent.parent)", "libpath = \\\"#{lib}\\\""
    inreplace ".setcdllascot2py.py", "build/", ""
    inreplace ["a5py/testascot/physicstests.py", "a5py/testascot/unittests.py"], "./../../build/ascot5_main", "#{bin}/ascot5_main"
    inreplace ["a5py/testascot/physicstests.py"], "./../../build/bbnbi5", "#{bin}/bbnbi5"

    # fix trace mode in components.py
    inreplace "a5py/gui/components.py", ".trace('w'", ".trace_add('write'"

    system "make", "ascot2py.py"
    ENV.remove("PATH", buildpath/".venv/bin")

    # bin.install Dir["bin/*"]

    # install the python module and link the shared library
    venv = virtualenv_create(libexec, "python3.14")
    # ENV.prepend_path "PATH", libexec/"bin"
    #
    # missing lots of dependencies in
    # for shapely
    ENV["GEOS_CONFIG"] = "#{Formula["geos"].opt_bin}/geos-config"
    # for rtree
    ENV["SPATIALINDEX_C_LIBRARY"] = "#{Formula["spatialindex"].opt_lib}"
    %w[unyt wurlitzer pyvista freeqdsk sympy mpmath xmlschema
       elementpath shapely trimesh rtree alphashape typing_extensions
       scooby cyclopts pooch].each do |r|
      venv.pip_install resource(r)
    end
    venv.pip_install_and_link buildpath

    bin.install "build/ascot5_main", "build/bbnbi5"
    lib.install "build/libascot.so"

  end

  test do
    # `test do` will create, run in and delete a temporary directory.
    #
    # This test will fail and we won't accept that! For Homebrew/homebrew-core
    # this will need to be a test that verifies the functionality of the
    # software. Run the test with `brew test ascot5`. Options passed
    # to `brew install` such as `--HEAD` also need to be provided to `brew test`.
    #
    # The installed folder is not in the path, so use the entire path to any
    # executables being tested: `system bin/"program", "do", "something"`.
    system "false"
  end
end
