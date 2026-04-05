class H5pyMpi < Formula
  include Language::Python::Virtualenv

  desc "Python bindings for HDF5, using MPI for parallel I/O"
  homepage "https://www.h5py.org/"
  url "https://github.com/h5py/h5py/releases/download/3.16.0/h5py-3.16.0.tar.gz"
  sha256 "a0dbaad796840ccaa67a4c144a0d0c8080073c34c76d5a6941d6818678ef2738"

  bottle do
    root_url "https://github.com/dgarnier/homebrew-plasma/releases/download/h5py-mpi-3.16.0"
    rebuild 1
    sha256 cellar: :any, arm64_sequoia: "4a943a88cdb09a1e6ca68a7786218f9ad2edba011759607e9db3dbacb3f2d9ff"
    sha256 cellar: :any, arm64_sonoma:  "daf6ccb6977800bce08dfd8f42657de2dd6ae71fc8bba178d93167a47c88ea17"
  end

  # alphabetical order
  depends_on "cython" => :build
  depends_on "ninja" => :build
  depends_on "python@3.12" => [:build, :test] # receipe supports earlier python (>=3.10), but
  depends_on "python@3.13" => [:build, :test] # github actions fail with too long builds
  depends_on "python@3.14" => [:build, :test] # only 3.14 has mpi4py build
  depends_on "mpi4py" => :test # only on 3.14
  depends_on "numpy" => :test # only on 3.13, 3.14
  depends_on "hdf5-mpi"
  depends_on "open-mpi"

  # resources for testing
  resource "exceptiongroup" do
    url "https://files.pythonhosted.org/packages/8a/0e/97c33bf5009bdbac74fd2beace167cab3f978feb69cc36f1ef79360d6c4e/exceptiongroup-1.3.1-py3-none-any.whl"
    sha256 "a7a39a3bd276781e98394987d3a5701d0c4edffb633bb7a5144577f82c773598"
  end
  resource "iniconfig" do
    url "https://files.pythonhosted.org/packages/cb/b1/3846dd7f199d53cb17f49cba7e651e9ce294d8497c8c150530ed11865bb8/iniconfig-2.3.0-py3-none-any.whl"
    sha256 "f631c04d2c48c52b84d0d0549c99ff3859c98df65b3101406327ecc7d53fbf12"
  end
  resource "pluggy" do
    url "https://files.pythonhosted.org/packages/54/20/4d324d65cc6d9205fabedc306948156824eb9f0ee1633355a8f7ec5c66bf/pluggy-1.6.0-py3-none-any.whl"
    sha256 "e920276dd6813095e9377c0bc5566d94c932c33b27a3e3945d8389c374dd4746"
  end
  resource "pygments" do
    url "https://files.pythonhosted.org/packages/f4/7e/a72dd26f3b0f4f2bf1dd8923c85f7ceb43172af56d63c7383eb62b332364/pygments-2.20.0-py3-none-any.whl"
    sha256 "81a9e26dd42fd28a23a2d169d86d7ac03b46e2f8b59ed4698fb4785f946d0176"
  end
  resource "pytest" do
    url "https://files.pythonhosted.org/packages/3b/ab/b3226f0bd7cdcf710fbede2b3548584366da3b19b5021e74f5bde2a8fa3f/pytest-9.0.2-py3-none-any.whl"
    sha256 "711ffd45bf766d5264d487b917733b453d917afd2b0ad65223959f59089f875b"
  end
  resource "pytest-mpi" do
    url "https://files.pythonhosted.org/packages/a6/2b/0ed49de84e96ebf771c86a16d88b48c08d291627cfcdce30973f8538c99e/pytest_mpi-0.6-py2.py3-none-any.whl"
    sha256 "1b7e193fb3be31d08c8e4dd7435e8e13e14b17ead6a6fc6aa07a6d3c7145590b"
  end
  resource "typing-extensions" do
    url "https://files.pythonhosted.org/packages/72/94/1a15dd82efb362ac84269196e94cf00f187f7ed21c242792a923cdb1c61f/typing_extensions-4.15.0.tar.gz"
    sha256 "0cea48d173cc12fa28ecabc3b837ea3cf6f38c6d1136f85cbaaf598984861466"
  end

  def pythons
    deps.map(&:to_formula)
        .select { |f| f.name.start_with?("python@") }
        .map { |f| f.opt_libexec/"bin/python" }
  end

  def install
    hdf5 = Formula["hdf5-mpi"]
    mpi = Formula["open-mpi"]
    ENV["HDF5_MPI"] = "ON"
    ENV["CC"] = mpi.opt_bin/"mpicc"
    ENV["HDF_DIR"] = hdf5.opt_prefix

    pythons.each do |python3|
      system python3, "-m", "pip", "install", *std_pip_args(build_isolation: true), "."
    end
  end

  def post_install
    HOMEBREW_PREFIX.glob("lib/python*.*/site-packages/h5py/**/*.pyc").map(&:unlink)
  end

  test do
    # only test the latest python
    test_packages = %w[exceptiongroup iniconfig pluggy pygments pytest pytest-mpi typing-extensions]
    ["python3.14"].each do |python|
      venv = virtualenv_create(testpath/"venv", python)
      test_packages.each do |r|
        venv.pip_install resource(r)
      end
      ENV["PATH"] = "#{testpath/"venv"/"bin"}:#{ENV["PATH"]}"
      # system "pytest", "--pyargs", "h5py"
      system "mpirun", "-n", ENV.make_jobs, "pytest", "--with-mpi", "--pyargs", "h5py"
    end
  end
end
