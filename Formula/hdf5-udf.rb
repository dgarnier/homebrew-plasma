class Hdf5Udf < Formula
  desc "User-defined functions for HDF5 (dynamically generated dataset plugin)"
  homepage "https://github.com/lucasvr/hdf5-udf"
  # The v2.1 tag predates the macOS build fixes (and a backend-file rename) that
  # only landed on the default branch, so pin the latest default-branch commit.
  url "https://github.com/lucasvr/hdf5-udf/archive/a23d14df28ca97db76cbd20bf92a3229a4241954.tar.gz"
  version "2.1.0.dev20230320"
  sha256 "9009613bef532fb409e9e0146808ad4587d9ef4a12e2703b6d34c6bb1677c101"
  license "MIT"

  livecheck do
    skip "pinned to a default-branch commit ahead of the last tagged release"
  end

  bottle do
    root_url "https://github.com/dgarnier/homebrew-plasma/releases/download/hdf5-udf-2.1.0.dev20230320"
    sha256 cellar: :any, arm64_tahoe:   "c908b277adca2fe1362d3c840d3b5aa6476cfa3a1de5df0d5cd75f668cf525b2"
    sha256 cellar: :any, arm64_sequoia: "d1049286bc3fbf058e4b1a0990a23357de4f49446e10230f15d4ada797b50ee8"
    sha256 cellar: :any, arm64_sonoma:  "34356e25a6005eb944d2a17bdde2a23b3c3dcbbec2d7e9d70963c513ef126f35"
    sha256               x86_64_linux:  "05a3bc55907afe52ded802669aaa04e230cd8b7f5abaf3a4d2da460a8b54b60e"
  end

  # alphabetical order
  depends_on "cmake" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on "hdf5"
  depends_on "libsodium"
  # Core luajit (not keg-only) so its `luajit` binary is on PATH: the Lua
  # backend shells out to `luajit -b` (via execvp) to build UDF bytecode.
  depends_on "luajit"
  depends_on "pcre" # provides libpcrecpp, required by the build
  # Must match the interpreter Homebrew's meson runs under: its bare
  # `dependency('python3')` resolves to meson's own Python via sysconfig, and
  # the build sandbox only permits headers from a declared dependency.
  depends_on "python@3.14"

  on_linux do
    depends_on "libseccomp"
  end

  def install
    # Enable the Python, Lua and C/C++ backends as recommended by upstream's
    # macOS INSTALL notes. The sandbox is left enabled (macOS uses its own
    # sandbox implementation, no extra dependency required).
    system "meson", "setup", "build",
           "-Dwith-python=true",
           "-Dwith-lua=true",
           "-Dwith-cpp=true",
           *std_meson_args
    system "meson", "compile", "-C", "build", "--verbose"
    system "meson", "install", "-C", "build"
  end

  def caveats
    <<~EOS
      The HDF5 I/O filter plugin was installed to:
        #{opt_prefix}/hdf5/lib/plugin

      To let HDF5 tools (h5dump, h5py, ...) read datasets that use an
      hdf5-udf function, add that directory to HDF5_PLUGIN_PATH:
        export HDF5_PLUGIN_PATH=#{opt_prefix}/hdf5/lib/plugin

      To use the Python backend, install the cffi module in the Python
      interpreter you use to run UDFs:
        python3 -m pip install cffi
    EOS
  end

  test do
    # The tool prints its usage banner (and exits non-zero) with no arguments.
    assert_match "hdf5-udf", shell_output("#{bin}/hdf5-udf 2>&1", 1)

    # The I/O filter plugin must be installed where HDF5 can load it.
    plugin = prefix/"hdf5/lib/plugin/libhdf5-udf-iofilter.#{OS.mac? ? "dylib" : "so"}"
    assert_path_exists plugin

    # End-to-end: seed an HDF5 file, embed a Lua UDF into it, then read the
    # generated dataset back through the filter plugin with h5dump. This
    # exercises the Lua backend (which shells out to `luajit`) and the plugin.
    hdf5 = Formula["hdf5"]
    (testpath/"seed.c").write <<~C
      #include "hdf5.h"
      int main(void) {
        hid_t f = H5Fcreate("test.h5", H5F_ACC_TRUNC, H5P_DEFAULT, H5P_DEFAULT);
        H5Fclose(f);
        return 0;
      }
    C
    system hdf5.opt_bin/"h5cc", "seed.c", "-o", "seed"
    system "./seed"

    (testpath/"udf.lua").write <<~LUA
      function dynamic_dataset()
          local udf_data = lib.getData("Simple")
          local udf_dims = lib.getDims("Simple")
          for i=1, udf_dims[1] do
              udf_data[i] = i
          end
      end
    LUA

    # On first use the tool generates a libsodium signing keypair under
    # $HOME/Library/HDF5-UDF; point HOME at the sandbox and pre-create the
    # (non-recursively created) parent directory.
    ENV["HOME"] = testpath
    keypath = OS.mac? ? testpath/"Library" : testpath/".config"
    keypath.mkpath

    # The tool needs to locate its own filter plugin both when embedding the
    # UDF and when the dataset is later read back. The dataset must be large
    # enough to hold the embedded bytecode + JSON metadata (~2 KB here).
    ENV["HDF5_PLUGIN_PATH"] = prefix/"hdf5/lib/plugin"
    system bin/"hdf5-udf", "test.h5", "udf.lua", "Simple:4096:int32"

    output = shell_output("#{hdf5.opt_bin}/h5dump -d Simple test.h5")
    assert_match "1, 2, 3, 4, 5, 6, 7, 8", output
  end
end
