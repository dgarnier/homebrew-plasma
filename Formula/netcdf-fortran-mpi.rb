class NetcdfFortranMpi < Formula
  desc "Fortran libraries and utilities for NetCDF with MPI support"
  homepage "https://www.unidata.ucar.edu/software/netcdf/"
  url "https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v4.6.3.tar.gz"
  sha256 "b9de820c4823faa5b4e1cd9ee82dd7c57acad105ebd8f6ae36b0244105518655"
  license "NetCDF"

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
