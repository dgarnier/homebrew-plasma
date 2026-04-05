class H5pyMpi < Formula
  desc "Python bindings for HDF5, using MPI for parallel I/O"
  homepage "https://www.h5py.org/"
  url "https://files.pythonhosted.org/packages/db/33/acd0ce6863b6c0d7735007df01815403f5589a21ff8c2e1ee2587a38f548/h5py-3.16.0.tar.gz"
  sha256 "a0dbaad796840ccaa67a4c144a0d0c8080073c34c76d5a6941d6818678ef2738"

  depends_on "open-mpi"
  depends_on "hdf5-mpi"

  depends_on "ninja" => :build
  depends_on "python@3.10" => [:build, :test]
  depends_on "python@3.11" => [:build, :test]
  depends_on "python@3.12" => [:build, :test]
  depends_on "python@3.13" => [:build, :test]
  depends_on "python@3.14" => [:build, :test]

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

end
