class NetcdfFortranMpi < Formula
  desc "Fortran libraries and utilities for NetCDF with MPI support"
  homepage "https://www.unidata.ucar.edu/software/netcdf/"
  url "https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v4.6.3.tar.gz"
  sha256 "b9de820c4823faa5b4e1cd9ee82dd7c57acad105ebd8f6ae36b0244105518655"
  license "NetCDF"

  bottle do
    root_url "https://github.com/dgarnier/homebrew-plasma/releases/download/netcdf-fortran-mpi-4.6.3"
    sha256 cellar: :any, arm64_tahoe:   "4b762edf333ea1508f2c8349323e53dae0705faa4c52121d26fca3ba89c63317"
    sha256 cellar: :any, arm64_sequoia: "6caa7ddb8e76a325742caf7ff46e06e00caeb21b1837239c676e9ceea95d6fa5"
    sha256 cellar: :any, arm64_sonoma:  "d5ed61e98afd8f60d1492bb5de835eb1c7f90c1daea17fe5be0af46ec33cede0"
    sha256 cellar: :any, x86_64_linux:  "b2f78f20f3e1cc6477f8f6c1b542a7e425cc30c097770b4fb58c195e40ae67f2"
  end

  depends_on "cmake" => :build
  depends_on "gcc" # for gfortran
  depends_on "netcdf-mpi"
  depends_on "open-mpi"

  on_macos do
    depends_on "libaec"
    depends_on "zstd"
  end

  def install
    args = std_cmake_args + %w[-DENABLE_TESTS=OFF -DENABLE_DOXYGEN=OFF]
    args += %w[-DCMAKE_SHARED_LINKER_FLAGS="-Wl,-undefined,dynamic_lookup,-twolevel_namespace"] if OS.mac?

    system "cmake", "-S", ".", "-B", "build_shared", *args, "-DBUILD_SHARED_LIBS=ON"
    system "cmake", "--build", "build_shared"
    system "cmake", "--install", "build_shared"

    system "cmake", "-S", ".", "-B", "build_static", *args, "-DBUILD_SHARED_LIBS=OFF"
    system "cmake", "--build", "build_static"
    lib.install "build_static/fortran/libnetcdff.a"

    libexec.install lib/"libnetcdff.settings"

    # Remove shim paths
    inreplace [bin/"nf-config", lib/"pkgconfig/netcdf-fortran.pc"], Superenv.shims_path/ENV.cc, ENV.cc
  end

  test do
    (testpath/"test.f90").write <<~FORTRAN
      program test
        use netcdf
        integer :: ncid, varid, dimids(2)
        integer :: dat(2,2) = reshape([1, 2, 3, 4], [2, 2])
        call check( nf90_create("test.nc", NF90_CLOBBER, ncid) )
        call check( nf90_def_dim(ncid, "x", 2, dimids(2)) )
        call check( nf90_def_dim(ncid, "y", 2, dimids(1)) )
        call check( nf90_def_var(ncid, "data", NF90_INT, dimids, varid) )
        call check( nf90_enddef(ncid) )
        call check( nf90_put_var(ncid, varid, dat) )
        call check( nf90_close(ncid) )
      contains
        subroutine check(status)
          integer, intent(in) :: status
          if (status /= nf90_noerr) call abort
        end subroutine check
      end program test
    FORTRAN
    system "gfortran", "test.f90", "-L#{lib}", "-I#{include}", "-lnetcdff", "-o", "testf"
    system "mpirun", "-np", "1", "./testf"
  end
end
