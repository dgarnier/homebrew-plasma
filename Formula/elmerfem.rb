class Elmerfem < Formula
  desc "Official git repository of Elmer FEM software"
  homepage "http://www.elmerfem.org"
  license "NOASSERTION"
  head "https://github.com/ElmerCSC/elmerfem.git", :branch => "devel"


  depends_on "cmake" => :build
  depends_on "gcc" => :build
  depends_on "open-mpi" => :build
  depends_on "netcdf"
  depends_on "netcdf-fortran"
  depends_on "netcdf-cxx"
  depends_on "hypre"
  depends_on "suite-sparse"               # includes cholmod and GraphBLAS 
  depends_on "dgarnier/plasma/tetgen"     # from tap brewsci/num
  depends_on "opencascade"
  depends_on "libomp"
  depends_on "qt@6"
  depends_on "qwt"
  depends_on "vtk"
  depends_on "vulkan-profiles"


  # Additional dependency
  # resource "" do
  #   url ""
  #   sha256 ""
  # end

  def install
    args = std_cmake_args + %W[
      -GNinja
      -DHOMEBREW_PREFIX=#{HOMEBREW_PREFIX}
      -DWITH_MPI:BOOL=TRUE
      -DWITH_OpenMP:BOOL=TRUE
      -DWITH_MUMPS:BOOL=TRUE
      -DWITH_Hypre:BOOL=TRUE
      -DWITH_CHOLMOD:BOOL=TRUE
      -DWITH_ELMERGUI:BOOL=TRUE
      -DWITH_ElmerIce:BOOL=TRUE
      -DWITH_CONTRIB:BOOL=TRUE
      -DWITH_NETCDF:BOOL=TRUE
      -DWITH_OCC:BOOL=TRUE
      -DCMAKE_SHARED_LINKER_FLAGS="-lomp"
      -DCMAKE_EXE_LINKER_FLAGS="-lomp"
      -DWITH_QT6:BOOL=TRUE
      -DWITH_QWT:BOOL=TRUE
      -DWITH_LUA:BOOL=TRUE
      -DWITH_VTK:BOOL=TRUE
      -DQWT_INCLUDE_DIR=#{HOMEBREW_PREFIX}/lib/qwt.framework/Headers
    ]
    system "cmake", "-S", ".", "-B", "build", *args
    # system "stop"
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    # `test do` will create, run in and delete a temporary directory.
    #
    # This test will fail and we won't accept that! For Homebrew/homebrew-core
    # this will need to be a test that verifies the functionality of the
    # software. Run the test with `brew test elmerfem`. Options passed
    # to `brew install` such as `--HEAD` also need to be provided to `brew test`.
    #
    # The installed folder is not in the path, so use the entire path to any
    # executables being tested: `system bin/"program", "do", "something"`.
    system "false"
  end
end
