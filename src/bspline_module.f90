!*****************************************************************************************
    module bspline_module
!*****************************************************************************************
!****h* BSPLINE/bspline_module
!
!  NAME
!    bspline_module
!
!  DESCRIPTION
!    Multidimensional (2D-6D) B-Spline interpolation of data on a regular grid.
!
!  NOTES
!    This module is based on the bspline and spline routines from [1].
!    The original Fortran 77 routines were converted to free-form source.
!    Some of them are relatively unchanged from the originals, but some have
!    been extensively refactored.  In addition, new routines for 
!    4d, 5d, and 6d interpolation were also created.
!
!  SEE ALSO
!    * 1) DBSPLIN and DTENSBS from the NIST Core Math Library (CMLIB)
!       http://www.nist.gov/itl/math/mcsd-software.cfm
!       Original code is public domain.
!    * 2) carl de boor, "a practical guide to splines",
!        springer-verlag, new york, 1978.
!    * 3) carl de boor, "efficient computer manipulation of tensor
!        products", acm transactions on mathematical software,
!        vol. 5 (1979), pp. 173-182.
!    * 4) d.e. amos, "computation with splines and b-splines",
!        sand78-1968, sandia laboratories, march, 1979.
!
!*****************************************************************************************

    use,intrinsic :: iso_fortran_env,    only: wp => real64
    
    implicit none
    
    private

    !main routines:
    public :: db2ink, db2val
    public :: db3ink, db3val
    public :: db4ink, db4val
    public :: db5ink, db5val
    public :: db6ink, db6val
    
    !unit test:
    public :: bspline_test
    
    contains
    
!*****************************************************************************************

!*****************************************************************************************
!****f* bspline_module/db2ink
!
!  NAME
!    db2ink
!
!  DESCRIPTION
!
!   db2ink determines the parameters of a  function  that  interpolates
!   the two-dimensional gridded data (x(i),y(j),fcn(i,j)) for i=1,..,nx
!   and j=1,..,ny. the interpolating function and its  derivatives  may
!   subsequently be evaluated by the function db2val.
!
!   the interpolating  function  is  a  piecewise  polynomial  function
!   represented as a tensor product of one-dimensional  b-splines.  the
!   form of this function is
!
!                          nx   ny
!              s(x,y)  =  sum  sum  a   u (x) v (y)
!                         i=1  j=1   ij  i     j
!
!   where the functions u(i)  and  v(j)  are  one-dimensional  b-spline
!   basis functions. the coefficients a(i,j) are chosen so that
!
!         s(x(i),y(j)) = fcn(i,j)   for i=1,..,nx and j=1,..,ny
!
!   note that  for  each  fixed  value  of  y  s(x,y)  is  a  piecewise
!   polynomial function of x alone, and for each fixed value of x  s(x,
!   y) is a piecewise polynomial function of y alone. in one  dimension
!   a piecewise polynomial may  be  created  by  partitioning  a  given
!   interval into subintervals and defining a distinct polynomial piece
!   on each one. the points where adjacent subintervals meet are called
!   knots. each of the functions u(i) and v(j)  above  is  a  piecewise
!   polynomial.
!
!   users of db2ink choose  the  order  (degree+1)  of  the  polynomial
!   pieces used to define the piecewise polynomial in each of the x and
!   y directions (kx and ky). users also  may  define  their  own  knot
!   sequence in x and y separately (tx and ty).  if  iflag=0,  however,
!   db2ink will choose sequences of knots that result  in  a  piecewise
!   polynomial interpolant with kx-2 continuous partial derivatives  in
!   x and ky-2 continuous partial derivatives in y. (kx knots are taken
!   near each endpoint in the x direction,  not-a-knot  end  conditions
!   are used, and the remaining knots are placed at data points  if  kx
!   is even or at midpoints between data points if kx  is  odd.  the  y
!   direction is treated similarly.)
!
!   after a call to db2ink, all information  necessary  to  define  the
!   interpolating function are contained in the parameters nx, ny,  kx,
!   ky, tx, ty, and bcoef. these quantities should not be altered until
!   after the last call of the evaluation routine db2val.
!
!  INPUTS
!
!    * x : real(wp) 1d array (size nx) :
!           array of x abcissae. must be strictly increasing.
!    * nx : integer scalar (>= 3)
!           number of x abcissae.
!    * y : real(wp) 1d array (size ny)
!           array of y abcissae. must be strictly increasing.
!    * ny : integer scalar (>= 3)
!           number of y abcissae.
!    * fcn : real(wp) 2d array (size nx by ny)
!           array of function values to interpolate. fcn(i,j) should
!           contain the function value at the point (x(i),y(j))
!    * kx : integer scalar (>= 2, < nx)
!           the order of spline pieces in x.
!           (order = polynomial degree + 1)
!    * ky : integer scalar (>= 2, < ny)
!           the order of spline pieces in y.
!           (order = polynomial degree + 1)
!
!  INPUTS/OUTPUTS
!
!    * tx : real(wp) 1d array (size nx+kx)
!           the knots in the x direction for the spline interpolant.
!           if iflag=0 these are chosen by db2ink.
!           if iflag=1 these are specified by the user.
!           (must be non-decreasing.)
!    * ty : real(wp) 1d array (size ny+ky)
!           the knots in the y direction for the spline interpolant.
!           if iflag=0 these are chosen by db2ink.
!           if iflag=1 these are specified by the user.
!           (must be non-decreasing.)
!    * iflag : integer scalar.
!
!           on input:  0 == knot sequence chosen by db2ink
!                      1 == knot sequence chosen by user.
!           on output: 1 == successful execution
!                      2 == iflag out of range
!                      3 == nx out of range
!                      4 == kx out of range
!                      5 == x not strictly increasing
!                      6 == tx not non-decreasing
!                      7 == ny out of range
!                      8 == ky out of range
!                      9 == y not strictly increasing
!                     10 == ty not non-decreasing
!
!  OUTPUTS
!
!    * bcoef : real(wp) 2d array (size nx by ny)
!           array of coefficients of the b-spline interpolant.
!           this may be the same array as fcn.
!
!  AUTHOR
!    * boisvert, ronald, nbs
!        scientific computing division
!        national bureau of standards
!        washington, dc 20234
!
!  HISTORY
!    * date written 25 may 1982
!    * 000330 modified array declarations.  (jec)
!    * Jacob Williams, 2/24/2015 : extensive refactoring of CMLIB routine.
!
!  SOURCE

    subroutine db2ink(x,nx,y,ny,fcn,kx,ky,tx,ty,bcoef,iflag)

    integer,intent(in)                      :: nx  
    integer,intent(in)                      :: ny  
    integer,intent(in)                      :: kx  
    integer,intent(in)                      :: ky  
    real(wp),dimension(nx),intent(in)       :: x   
    real(wp),dimension(ny),intent(in)       :: y   
    real(wp),dimension(nx,ny),intent(in)    :: fcn 
    real(wp),dimension(:),intent(inout)     :: tx
    real(wp),dimension(:),intent(inout)     :: ty
    real(wp),dimension(nx,ny),intent(out)   :: bcoef
    integer,intent(inout)                   :: iflag

    real(wp),dimension(nx*ny) :: temp
    real(wp),dimension(max(2*kx*(nx+1),2*ky*(ny+1))) :: work
    logical :: status_ok
  
    !check validity of inputs
    
    call check_inputs('db2ink',&
                        iflag,&
                        nx=nx,ny=ny,&
                        kx=kx,ky=ky,&
                        x=x,y=y,&
                        tx=tx,ty=ty,&
                        status_ok=status_ok)
                        
    if (status_ok) then

        !choose knots

        if (iflag == 0) then
            call dbknot(x,nx,kx,tx)
            call dbknot(y,ny,ky,ty)
        end if

        !construct b-spline coefficients

        call dbtpcf(x,nx,fcn, nx,ny,tx,kx,temp, work)
        call dbtpcf(y,ny,temp,ny,nx,ty,ky,bcoef,work)

        iflag = 1
    
    end if

    end subroutine db2ink
!*****************************************************************************************
     
!*****************************************************************************************
!****f* bspline_module/db2val
!
!  NAME
!    db2val
!
!  DESCRIPTION
!
!   db2val  evaluates   the   tensor   product   piecewise   polynomial
!   interpolant constructed  by  the  routine  db2ink  or  one  of  its
!   derivatives at the point (xval,yval). to evaluate  the  interpolant
!   itself, set idx=idy=0, to evaluate the first partial  with  respect
!   to x, set idx=1,idy=0, and so on.
!
!   db2val returns 0.0e0 if (xval,yval) is out of range. that is, if
!            xval<tx(1) .or. xval>tx(nx+kx) .or.
!            yval<ty(1) .or. yval>ty(ny+ky)
!   if the knots tx  and  ty  were  chosen  by  db2ink,  then  this  is
!   equivalent to
!            xval<x(1) .or. xval>x(nx)+epsx .or.
!            yval<y(1) .or. yval>y(ny)+epsy
!   where epsx = 0.1*(x(nx)-x(nx-1)) and epsy = 0.1*(y(ny)-y(ny-1)).
!
!   the input quantities tx, ty, nx, ny, kx, ky, and  bcoef  should  be
!   unchanged since the last call of db2ink.
!
!  INPUTS
!
!   xval    real(wp) scalar
!           x coordinate of evaluation point.
!
!   yval    real(wp) scalar
!           y coordinate of evaluation point.
!
!   idx     integer scalar
!           x derivative of piecewise polynomial to evaluate.
!
!   idy     integer scalar
!           y derivative of piecewise polynomial to evaluate.
!
!   tx      real(wp) 1d array (size nx+kx)
!           sequence of knots defining the piecewise polynomial in
!           the x direction.  (same as in last call to db2ink.)
!
!   ty      real(wp) 1d array (size ny+ky)
!           sequence of knots defining the piecewise polynomial in
!           the y direction.  (same as in last call to db2ink.)
!
!   nx      integer scalar
!           the number of interpolation points in x.
!           (same as in last call to db2ink.)
!
!   ny      integer scalar
!           the number of interpolation points in y.
!           (same as in last call to db2ink.)
!
!   kx      integer scalar
!           order of polynomial pieces in x.
!           (same as in last call to db2ink.)
!
!   ky      integer scalar
!           order of polynomial pieces in y.
!           (same as in last call to db2ink.)
!
!   bcoef   real(wp) 2d array (size nx by ny)
!           the b-spline coefficients computed by db2ink.
!
!  AUTHOR
!    boisvert, ronald, nbs
!        scientific computing division
!        national bureau of standards
!        washington, dc 20234
!
!  HISTORY
!    date written   25 may 1982
!    000330  modified array declarations.  (jec)
!    Jacob Williams, 2/24/2015 : extensive refactoring of CMLIB routine.
!
!  SOURCE

    real(wp) function db2val(xval,yval,idx,idy,tx,ty,nx,ny,kx,ky,bcoef)

    integer,intent(in)                   :: idx, idy
    integer,intent(in)                   :: nx, ny
    integer,intent(in)                   :: kx, ky
    real(wp),intent(in)                  :: xval, yval
    real(wp),dimension(:),intent(in)     :: tx, ty
    real(wp),dimension(nx,ny),intent(in) :: bcoef

    integer :: inbv, k, lefty, mflag, kcol
    real(wp),dimension(ky) :: temp
    real(wp),dimension(3*max(kx,ky)) :: work

    integer,save :: iloy = 1
    integer,save :: inbvx = 1
    
    db2val = 0.0_wp

    if (xval<tx(1) .or. xval>tx(nx+kx)) return
    if (yval<ty(1) .or. yval>ty(ny+ky)) return

    call dintrv(ty,ny+ky,yval,iloy,lefty,mflag); if (mflag /= 0) return
    
    inbv = 1

    kcol = lefty - ky
    do k=1,ky
        kcol = kcol + 1
        temp(k) = dbvalu(tx,bcoef(:,kcol),nx,kx,idx,xval,inbvx,work)
    end do
    
    kcol = lefty - ky + 1
    db2val = dbvalu(ty(kcol:),temp,ky,ky,idy,yval,inbv,work)
         
    end function db2val
!*****************************************************************************************
      
!*****************************************************************************************
!****f* bspline_module/db3ink
!
!  NAME
!    db3ink
!
!  DESCRIPTION
!
!   db3ink determines the parameters of a  function  that  interpolates
!   the three-dimensional gridded data (x(i),y(j),z(k),fcn(i,j,k))  for
!   i=1,..,nx, j=1,..,ny, and k=1,..,nz. the interpolating function and
!   its derivatives may  subsequently  be  evaluated  by  the  function
!   db3val.
!
!   the interpolating  function  is  a  piecewise  polynomial  function
!   represented as a tensor product of one-dimensional  b-splines.  the
!   form of this function is
!
!                      nx   ny   nz
!        s(x,y,z)  =  sum  sum  sum  a    u (x) v (y) w (z)
!                     i=1  j=1  k=1   ijk  i     j     k
!
!   where the functions u(i), v(j), and  w(k)  are  one-dimensional  b-
!   spline basis functions. the coefficients a(i,j) are chosen so that
!
!   s(x(i),y(j),z(k)) = fcn(i,j,k)  for i=1,..,nx, j=1,..,ny, k=1,..,nz
!
!   note that for fixed values of y  and  z  s(x,y,z)  is  a  piecewise
!   polynomial function of x alone, for fixed values of x and z  s(x,y,
!   z) is a piecewise polynomial function of y  alone,  and  for  fixed
!   values of x and y s(x,y,z)  is  a  function  of  z  alone.  in  one
!   dimension a piecewise polynomial may be created by  partitioning  a
!   given interval into subintervals and defining a distinct polynomial
!   piece on each one. the points where adjacent subintervals meet  are
!   called knots. each of the functions u(i), v(j), and w(k) above is a
!   piecewise polynomial.
!
!   users of db3ink choose  the  order  (degree+1)  of  the  polynomial
!   pieces used to define the piecewise polynomial in each of the x, y,
!   and z directions (kx, ky, and kz). users also may define their  own
!   knot sequence in x, y, and z separately (tx, ty, and tz). if iflag=
!   0, however, db3ink will choose sequences of knots that result in  a
!   piecewise  polynomial  interpolant  with  kx-2  continuous  partial
!   derivatives in x, ky-2 continuous partial derivatives in y, and kz-
!   2 continuous partial derivatives in z. (kx  knots  are  taken  near
!   each endpoint in x, not-a-knot end conditions  are  used,  and  the
!   remaining knots are placed at data points  if  kx  is  even  or  at
!   midpoints between data points if kx is odd. the y and z  directions
!   are treated similarly.)
!
!   after a call to db3ink, all information  necessary  to  define  the
!   interpolating function are contained in the parameters nx, ny,  nz,
!   kx, ky, kz, tx, ty, tz, and bcoef. these quantities should  not  be
!   altered until after the last call of the evaluation routine db3val.
!
!  INPUTS
!
!   x       real(wp) 1d array (size nx)
!           array of x abcissae. must be strictly increasing.
!
!   nx      integer scalar (>= 3)
!           number of x abcissae.
!
!   y       real(wp) 1d array (size ny)
!           array of y abcissae. must be strictly increasing.
!
!   ny      integer scalar (>= 3)
!           number of y abcissae.
!
!   z       real(wp) 1d array (size nz)
!           array of z abcissae. must be strictly increasing.
!
!   nz      integer scalar (>= 3)
!           number of z abcissae.
!
!   fcn     real(wp) 3d array (size nx by ny by nz)
!           array of function values to interpolate. fcn(i,j,k) should
!           contain the function value at the point (x(i),y(j),z(k))
!
!   kx      integer scalar (>= 2, < nx)
!           the order of spline pieces in x.
!           (order = polynomial degree + 1)
!
!   ky      integer scalar (>= 2, < ny)
!           the order of spline pieces in y.
!           (order = polynomial degree + 1)
!
!   kz      integer scalar (>= 2, < nz)
!           the order of spline pieces in z.
!           (order = polynomial degree + 1)
!
!  INPUT/OUTPUT
!
!   tx      real(wp) 1d array (size nx+kx)
!           the knots in the x direction for the spline interpolant.
!           if iflag=0 these are chosen by db3ink.
!           if iflag=1 these are specified by the user.
!                      (must be non-decreasing.)
!
!   ty      real(wp) 1d array (size ny+ky)
!           the knots in the y direction for the spline interpolant.
!           if iflag=0 these are chosen by db3ink.
!           if iflag=1 these are specified by the user.
!                      (must be non-decreasing.)
!
!   tz      real(wp) 1d array (size nz+kz)
!           the knots in the z direction for the spline interpolant.
!           if iflag=0 these are chosen by db3ink.
!           if iflag=1 these are specified by the user.
!                      (must be non-decreasing.)
!
!  OUTPUT
!
!   bcoef   real(wp) 3d array (size nx by ny by nz)
!           array of coefficients of the b-spline interpolant.
!           this may be the same array as fcn.
!
!  MISCELLANEOUS
!
!   iflag   integer scalar.
!           on input:  0 == knot sequence chosen by b2ink
!                      1 == knot sequence chosen by user.
!           on output: 1 == successful execution
!                      2 == iflag out of range
!                      3 == nx out of range
!                      4 == kx out of range
!                      5 == x not strictly increasing
!                      6 == tx not non-decreasing
!                      7 == ny out of range
!                      8 == ky out of range
!                      9 == y not strictly increasing
!                     10 == ty not non-decreasing
!                     11 == nz out of range
!                     12 == kz out of range
!                     13 == z not strictly increasing
!                     14 == ty not non-decreasing
!
!  AUTHOR
!    boisvert, ronald, nbs
!        scientific computing division
!        national bureau of standards
!        washington, dc 20234
!
!  HISTORY
!    date written   25 may 1982
!   000330  modified array declarations.  (jec)
!    Jacob Williams, 2/24/2015 : extensive refactoring of CMLIB routine.
!
!  SOURCE

    subroutine db3ink(x,nx,y,ny,z,nz,fcn,kx,ky,kz,tx,ty,tz,bcoef,iflag)

    integer,intent(in)                       :: nx, ny, nz
    integer,intent(in)                       :: kx, ky, kz
    real(wp),dimension(nx),intent(in)        :: x
    real(wp),dimension(ny),intent(in)        :: y
    real(wp),dimension(nz),intent(in)        :: z      
    real(wp),dimension(nx,ny,nz),intent(in)  :: fcn
    real(wp),dimension(:),intent(inout)      :: tx,ty,tz
    real(wp),dimension(nx,ny,nz),intent(out) :: bcoef
    integer,intent(inout)                    :: iflag

    real(wp),dimension(nx*ny*nz) :: temp
    real(wp),dimension(max(2*kx*(nx+1),2*ky*(ny+1),2*kz*(nz+1))) :: work
    logical :: status_ok
      
    ! check validity of input

    call check_inputs('db3ink',&
                        iflag,&
                        nx=nx,ny=ny,nz=nz,&
                        kx=kx,ky=ky,kz=kz,&
                        x=x,y=y,z=z,&
                        tx=tx,ty=ty,tz=tz,&
                        status_ok=status_ok)
                        
    if (status_ok) then

        ! choose knots

        if (iflag == 0) then
            call dbknot(x,nx,kx,tx)
            call dbknot(y,ny,ky,ty)
            call dbknot(z,nz,kz,tz)
        end if
    
        ! copy fcn to work in packed for dbtpcf
        temp(1:nx*ny*nz) = reshape( fcn, [nx*ny*nz] )

        ! construct b-spline coefficients
        
        call dbtpcf(x,nx,temp, nx,ny*nz,tx,kx,bcoef,work)
        call dbtpcf(y,ny,bcoef,ny,nx*nz,ty,ky,temp, work)
        call dbtpcf(z,nz,temp, nz,nx*ny,tz,kz,bcoef,work)
    
        iflag = 1
    
    end if

    end subroutine db3ink
!*****************************************************************************************

!*****************************************************************************************
!****f* bspline_module/db3val
!
!  NAME
!    db3val
!
!  DESCRIPTION
!
!   db3val  evaluates   the   tensor   product   piecewise   polynomial
!   interpolant constructed  by  the  routine  db3ink  or  one  of  its
!   derivatives  at  the  point  (xval,yval,zval).  to   evaluate   the
!   interpolant  itself,  set  idx=idy=idz=0,  to  evaluate  the  first
!   partial with respect to x, set idx=1,idy=idz=0, and so on.
!
!   db3val returns 0.0d0 if (xval,yval,zval) is out of range. that is,
!            xval<tx(1) .or. xval>tx(nx+kx) .or.
!            yval<ty(1) .or. yval>ty(ny+ky) .or.
!            zval<tz(1) .or. zval>tz(nz+kz)
!   if the knots tx, ty, and tz were chosen by  db3ink,  then  this  is
!   equivalent to
!            xval<x(1) .or. xval>x(nx)+epsx .or.
!            yval<y(1) .or. yval>y(ny)+epsy .or.
!            zval<z(1) .or. zval>z(nz)+epsz
!   where epsx = 0.1*(x(nx)-x(nx-1)), epsy =  0.1*(y(ny)-y(ny-1)),  and
!   epsz = 0.1*(z(nz)-z(nz-1)).
!
!   the input quantities tx, ty, tz, nx, ny, nz, kx, ky, kz, and  bcoef
!   should remain unchanged since the last call of db3ink.
!
!  INPUTS
!
!   xval    real(wp) scalar
!           x coordinate of evaluation point.
!
!   yval    real(wp) scalar
!           y coordinate of evaluation point.
!
!   zval    real(wp) scalar
!           z coordinate of evaluation point.
!
!   idx     integer scalar
!           x derivative of piecewise polynomial to evaluate.
!
!   idy     integer scalar
!           y derivative of piecewise polynomial to evaluate.
!
!   idz     integer scalar
!           z derivative of piecewise polynomial to evaluate.
!
!   tx      real(wp) 1d array (size nx+kx)
!           sequence of knots defining the piecewise polynomial in
!           the x direction.  (same as in last call to db3ink.)
!
!   ty      real(wp) 1d array (size ny+ky)
!           sequence of knots defining the piecewise polynomial in
!           the y direction.  (same as in last call to db3ink.)
!
!   tz      real(wp) 1d array (size nz+kz)
!           sequence of knots defining the piecewise polynomial in
!           the z direction.  (same as in last call to db3ink.)
!
!   nx      integer scalar
!           the number of interpolation points in x.
!           (same as in last call to db3ink.)
!
!   ny      integer scalar
!           the number of interpolation points in y.
!           (same as in last call to db3ink.)
!
!   nz      integer scalar
!           the number of interpolation points in z.
!           (same as in last call to db3ink.)
!
!   kx      integer scalar
!           order of polynomial pieces in x.
!           (same as in last call to db3ink.)
!
!   ky      integer scalar
!           order of polynomial pieces in y.
!           (same as in last call to db3ink.)
!
!   kz      integer scalar
!           order of polynomial pieces in z.
!           (same as in last call to db3ink.)
!
!   bcoef   real(wp) 2d array (size nx by ny by nz)
!           the b-spline coefficients computed by db3ink.
!
!  AUTHOR
!    boisvert, ronald, nbs
!        scientific computing division
!        national bureau of standards
!        washington, dc 20234
!
!  HISTORY
!    date written   25 may 1982
!   000330  modified array declarations.  (jec)
!    Jacob Williams, 2/24/2015 : extensive refactoring of CMLIB routine.
!
!  SOURCE

    real(wp) function db3val(xval,yval,zval,idx,idy,idz,&
                                     tx,ty,tz,&
                                     nx,ny,nz,kx,ky,kz,bcoef)

    integer,intent(in)                      :: idx, idy, idz
    integer,intent(in)                      :: nx, ny, nz
    integer,intent(in)                      :: kx, ky, kz
    real(wp),intent(in)                     :: xval, yval, zval
    real(wp),dimension(:),intent(in)        :: tx,ty,tz
    real(wp),dimension(nx,ny,nz),intent(in) :: bcoef

    real(wp),dimension(ky,kz)              :: temp1
    real(wp),dimension(kz)                 :: temp2
    real(wp),dimension(3*max(kx,ky,kz))    :: work

    integer :: inbv1, inbv2, lefty, leftz, mflag,&
                kcoly, kcolz, izm1, j, k

    integer,save :: iloy  = 1
    integer,save :: iloz  = 1
    integer,save :: inbvx = 1
    
    db3val = 0.0_wp

    if (xval<tx(1) .or. xval>tx(nx+kx)) return
    if (yval<ty(1) .or. yval>ty(ny+ky)) return
    if (zval<tz(1) .or. zval>tz(nz+kz)) return

    call dintrv(ty,ny+ky,yval,iloy,lefty,mflag); if (mflag /= 0) return
    call dintrv(tz,nz+kz,zval,iloz,leftz,mflag); if (mflag /= 0) return

    inbv1 = 1
    inbv2 = 1

    kcolz = leftz - kz
    do k=1,kz
        kcolz = kcolz + 1
        kcoly = lefty - ky
        do j=1,ky
            kcoly = kcoly + 1
            temp1(j,k) = dbvalu(tx,bcoef(:,kcoly,kcolz),nx,kx,idx,xval,inbvx,work)
        end do
    end do

    kcoly = lefty - ky + 1
    do k=1,kz
        temp2(k) = dbvalu(ty(kcoly:),temp1(:,k),ky,ky,idy,yval,inbv1,work)
    end do

    kcolz = leftz - kz + 1
    db3val = dbvalu(tz(kcolz:),temp2,kz,kz,idz,zval,inbv2,work)

    end function db3val
!*****************************************************************************************

!*****************************************************************************************
!****f* bspline_module/db4ink
!
!  NAME
!    db4ink
!
!  DESCRIPTION
!    db4ink determines the parameters of a function that interpolates
!    the four-dimensional gridded data (x(i),y(j),z(k),q(l),fcn(i,j,k,l)) for
!    i=1,..,nx, j=1,..,ny, k=1,..,nz, and l=1,..,nq. the interpolating function and
!    its derivatives may subsequently be evaluated by the function db4val.
!
!    See db3ink header for more details.
!
!  AUTHOR
!    Jacob Williams, 2/24/2015
!
!  SOURCE

    subroutine db4ink(x,nx,y,ny,z,nz,q,nq,&
                        fcn,&
                        kx,ky,kz,kq,&
                        tx,ty,tz,tq,&
                        bcoef,iflag)

    integer,intent(in)                          :: nx, ny, nz, nq
    integer,intent(in)                          :: kx, ky, kz, kq
    integer,intent(inout)                       :: iflag
    real(wp),dimension(nx),intent(in)           :: x
    real(wp),dimension(ny),intent(in)           :: y
    real(wp),dimension(nz),intent(in)           :: z
    real(wp),dimension(nq),intent(in)           :: q
    real(wp),dimension(nx,ny,nz,nq),intent(in)  :: fcn
    real(wp),dimension(:),intent(inout)         :: tx,ty,tz,tq
    real(wp),dimension(nx,ny,nz,nq),intent(out) :: bcoef
           
    real(wp),dimension(nx*ny*nz*nq) :: temp
    real(wp),dimension(max(2*kx*(nx+1),2*ky*(ny+1),2*kz*(nz+1),2*kq*(nq+1))) :: work
    logical :: status_ok
      
    ! check validity of input
    
    call check_inputs('db4ink',&
                        iflag,&
                        nx=nx,ny=ny,nz=nz,nq=nq,&
                        kx=kx,ky=ky,kz=kz,kq=kq,&
                        x=x,y=y,z=z,q=q,&
                        tx=tx,ty=ty,tz=tz,tq=tq,&
                        status_ok=status_ok)
                        
    if (status_ok) then
    
        ! choose knots

        if (iflag == 0) then
            call dbknot(x,nx,kx,tx)
            call dbknot(y,ny,ky,ty)
            call dbknot(z,nz,kz,tz)
            call dbknot(q,nq,kq,tq)
        end if

        ! construct b-spline coefficients

        call dbtpcf(x,nx,fcn,  nx,ny*nz*nq,tx,kx,temp, work)
        call dbtpcf(y,ny,temp, ny,nx*nz*nq,ty,ky,bcoef,work)
        call dbtpcf(z,nz,bcoef,nz,nx*ny*nq,tz,kz,temp, work)
        call dbtpcf(q,nq,temp, nq,nx*ny*nz,tq,kq,bcoef,work)
      
        iflag = 1
     
     end if

    end subroutine db4ink
!*****************************************************************************************

!*****************************************************************************************
!****f* bspline_module/db4val
!
!  NAME
!    db4val
!
!  DESCRIPTION
!    db4val evaluates the tensor product piecewise polynomial
!    interpolant constructed by the routine db4ink or one of its
!    derivatives at the point (xval,yval,zval,qval). to evaluate the
!    interpolant itself, set idx=idy=idz=idq=0, to evaluate the first
!    partial with respect to x, set idx=1,idy=idz=idq=0, and so on.
!
!    See db3val header for more information.
!
!  AUTHOR
!    Jacob Williams, 2/24/2025
!
!  SOURCE

    real(wp) function db4val(xval,yval,zval,qval,&
                                idx,idy,idz,idq,&
                                tx,ty,tz,tq,&
                                nx,ny,nz,nq,&
                                kx,ky,kz,kq,&
                                bcoef)

    integer,intent(in)                          :: idx, idy, idz, idq
    integer,intent(in)                          :: nx, ny, nz, nq
    integer,intent(in)                          :: kx, ky, kz, kq
    real(wp),intent(in)                         :: xval, yval, zval, qval
    real(wp),dimension(:),intent(in)            :: tx,ty,tz,tq
    real(wp),dimension(nx,ny,nz,nq),intent(in)  :: bcoef
    
    real(wp),dimension(ky,kz,kq)             :: temp1
    real(wp),dimension(kz,kq)                :: temp2
    real(wp),dimension(kq)                   :: temp3
    real(wp),dimension(3*max(kx,ky,kz,kq))   :: work
    integer :: inbv1, inbv2, inbv3, lefty, leftz, leftq, mflag,&
                kcoly, kcolz, kcolq, i, j, k, q

    integer,save :: iloy  = 1
    integer,save :: iloz  = 1
    integer,save :: iloq  = 1
    integer,save :: inbvx = 1
    
    db4val = 0.0_wp

    if (xval<tx(1) .or. xval>tx(nx+kx) ) return
    if (yval<ty(1) .or. yval>ty(ny+ky) ) return
    if (zval<tz(1) .or. zval>tz(nz+kz) ) return
    if (qval<tq(1) .or. qval>tq(nq+kq) ) return

    call dintrv(ty,ny+ky,yval,iloy,lefty,mflag); if (mflag /= 0) return
    call dintrv(tz,nz+kz,zval,iloz,leftz,mflag); if (mflag /= 0) return
    call dintrv(tq,nq+kq,qval,iloq,leftq,mflag); if (mflag /= 0) return

    inbv1 = 1
    inbv2 = 1
    inbv3 = 1

    ! x -> y, z, q
    kcolq = leftq - kq
    do q=1,kq
        kcolq = kcolq + 1
        kcolz = leftz - kz
        do k=1,kz
            kcolz = kcolz + 1
            kcoly = lefty - ky
            do j=1,ky
                kcoly = kcoly + 1
                temp1(j,k,q) = dbvalu(tx,bcoef(:,kcoly,kcolz,kcolq),&
                                        nx,kx,idx,xval,inbvx,work)
            end do
        end do
    end do

    ! y -> z, q
    kcoly = lefty - ky + 1
    do q=1,kq
        do k=1,kz
            temp2(k,q) = dbvalu(ty(kcoly:),temp1(:,k,q),ky,ky,idy,yval,inbv1,work)    
        end do
    end do

    ! z -> q
    kcolz = leftz - kz + 1
    do q=1,kq
        temp3(q) = dbvalu(tz(kcolz:),temp2(:,q),kz,kz,idz,zval,inbv2,work)    
    end do

    ! q
    kcolq = leftq - kq + 1
    db4val = dbvalu(tq(kcolq:),temp3,kq,kq,idq,qval,inbv3,work) 

    end function db4val
!*****************************************************************************************

!*****************************************************************************************
!****f* bspline_module/db5ink
!
!  NAME
!    db5ink
!
!  DESCRIPTION
!    db5ink determines the parameters of a function that interpolates
!    the five-dimensional gridded data (x(i),y(j),z(k),q(l),r(m),fcn(i,j,k,l,m)) for
!    i=1,..,nx, j=1,..,ny, k=1,..,nz, l=1,..,nq, and m=1,..,nr. 
!    the interpolating function and its derivatives may subsequently be evaluated 
!    by the function db5val.
!
!    See db3ink header for more details.
!
!  AUTHOR
!    Jacob Williams, 2/24/2015
!
!  SOURCE

    subroutine db5ink(x,nx,y,ny,z,nz,q,nq,r,nr,&
                        fcn,&
                        kx,ky,kz,kq,kr,&
                        tx,ty,tz,tq,tr,&
                        bcoef,iflag)

    integer,intent(in)                              :: nx, ny, nz, nq, nr
    integer,intent(in)                              :: kx, ky, kz, kq, kr
    integer,intent(inout)                           :: iflag
    real(wp),dimension(nx),intent(in)               :: x
    real(wp),dimension(ny),intent(in)               :: y
    real(wp),dimension(nz),intent(in)               :: z
    real(wp),dimension(nq),intent(in)               :: q
    real(wp),dimension(nr),intent(in)               :: r
    real(wp),dimension(nx,ny,nz,nq,nr),intent(in)   :: fcn
    real(wp),dimension(:),intent(inout)             :: tx,ty,tz,tq,tr
    real(wp),dimension(nx,ny,nz,nq,nr),intent(out)  :: bcoef
           
    real(wp),dimension(nx*ny*nz*nq*nr) :: temp
    real(wp),dimension(max( 2*kx*(nx+1),&
                            2*ky*(ny+1),&
                            2*kz*(nz+1),&
                            2*kq*(nq+1),&
                            2*kr*(nr+1) )) :: work
    logical :: status_ok
      
    !  check validity of input
    
    call check_inputs('db5ink',&
                        iflag,&
                        nx=nx,ny=ny,nz=nz,nq=nq,nr=nr,&
                        kx=kx,ky=ky,kz=kz,kq=kq,kr=kr,&
                        x=x,y=y,z=z,q=q,r=r,&
                        tx=tx,ty=ty,tz=tz,tq=tq,tr=tr,&
                        status_ok=status_ok)
                        
    if (status_ok) then
    
        !  choose knots

        if (iflag == 0) then
            call dbknot(x,nx,kx,tx)
            call dbknot(y,ny,ky,ty)
            call dbknot(z,nz,kz,tz)
            call dbknot(q,nq,kq,tq)
            call dbknot(r,nr,kr,tr)
        end if

        ! copy fcn to work in packed for dbtpcf
    
        temp(1:nx*ny*nz*nq*nr) = reshape( fcn, [nx*ny*nz*nq*nr] )

        !  construct b-spline coefficients
    
        call dbtpcf(x,nx,temp,  nx,ny*nz*nq*nr,tx,kx,bcoef, work)
        call dbtpcf(y,ny,bcoef, ny,nx*nz*nq*nr,ty,ky,temp,  work)
        call dbtpcf(z,nz,temp,  nz,nx*ny*nq*nr,tz,kz,bcoef, work)
        call dbtpcf(q,nq,bcoef, nq,nx*ny*nz*nr,tq,kq,temp,  work)
        call dbtpcf(r,nr,temp,  nr,nx*ny*nz*nq,tr,kr,bcoef, work)
      
        iflag = 1
     
     end if

    end subroutine db5ink
!*****************************************************************************************

!*****************************************************************************************
!****f* bspline_module/db5val
!
!  NAME
!    db5val
!
!  DESCRIPTION
!    db5val evaluates the tensor product piecewise polynomial
!    interpolant constructed by the routine db5ink or one of its
!    derivatives at the point (xval,yval,zval,qval,rval). to evaluate the
!    interpolant itself, set idx=idy=idz=idq=idr=0, to evaluate the first
!    partial with respect to x, set idx=1,idy=idz=idq=idr=0, and so on.
!
!    See db3val header for more information.
!
!  AUTHOR
!    Jacob Williams, 2/24/2025
!
!  SOURCE

    real(wp) function db5val(xval,yval,zval,qval,rval,&
                                idx,idy,idz,idq,idr,&
                                tx,ty,tz,tq,tr,&
                                nx,ny,nz,nq,nr,&
                                kx,ky,kz,kq,kr,&
                                bcoef)

    integer,intent(in)                            :: idx, idy, idz, idq, idr
    integer,intent(in)                            :: nx, ny, nz, nq, nr
    integer,intent(in)                            :: kx, ky, kz, kq, kr
    real(wp),intent(in)                           :: xval, yval, zval, qval, rval
    real(wp),dimension(:),intent(in)              :: tx,ty,tz,tq,tr
    real(wp),dimension(nx,ny,nz,nq,nr),intent(in) :: bcoef
    
    real(wp),dimension(ky,kz,kq,kr)           :: temp1
    real(wp),dimension(kz,kq,kr)              :: temp2
    real(wp),dimension(kq,kr)                 :: temp3
    real(wp),dimension(kr)                    :: temp4
    real(wp),dimension(3*max(kx,ky,kz,kq,kr)) :: work
    integer :: inbv1, inbv2, inbv3, inbv4,&
                lefty, leftz, leftq, leftr, mflag,&
                kcoly, kcolz, kcolq, kcolr, i, j, k, q, r

    integer,save :: iloy  = 1
    integer,save :: iloz  = 1
    integer,save :: iloq  = 1
    integer,save :: ilor  = 1
    integer,save :: inbvx = 1
    
    db5val = 0.0_wp
        
    if ( xval<tx(1) .or. xval>tx(nx+kx) ) return
    if ( yval<ty(1) .or. yval>ty(ny+ky) ) return
    if ( zval<tz(1) .or. zval>tz(nz+kz) ) return
    if ( qval<tq(1) .or. qval>tq(nq+kq) ) return
    if ( rval<tr(1) .or. rval>tr(nr+kr) ) return
    
    call dintrv(ty,ny+ky,yval,iloy,lefty,mflag); if (mflag /= 0) return
    call dintrv(tz,nz+kz,zval,iloz,leftz,mflag); if (mflag /= 0) return
    call dintrv(tq,nq+kq,qval,iloq,leftq,mflag); if (mflag /= 0) return
    call dintrv(tr,nr+kr,rval,ilor,leftr,mflag); if (mflag /= 0) return
        
    inbv1 = 1
    inbv2 = 1
    inbv3 = 1
    inbv4 = 1

    ! x -> y, z, q, r
    kcolr = leftr - kr
    do r=1,kr
        kcolr = kcolr + 1
        kcolq = leftq - kq
        do q=1,kq
            kcolq = kcolq + 1
            kcolz = leftz - kz
            do k=1,kz
                kcolz = kcolz + 1
                kcoly = lefty - ky
                do j=1,ky
                    kcoly = kcoly + 1
                    temp1(j,k,q,r) = dbvalu(tx,bcoef(:,kcoly,kcolz,kcolq,kcolr),&
                                            nx,kx,idx,xval,inbvx,work)
                end do
            end do
        end do    
    end do
    
    ! y -> z, q, r
    kcoly = lefty - ky + 1
    do r=1,kr
        do q=1,kq
            do k=1,kz
                temp2(k,q,r) = dbvalu(ty(kcoly:),temp1(:,k,q,r),ky,ky,idy,yval,inbv1,work)    
            end do
        end do
    end do
    
    ! z -> q, r
    kcolz = leftz - kz + 1    
    do r=1,kr
        do q=1,kq
            temp3(q,r) = dbvalu(tz(kcolz:),temp2(:,q,r),kz,kz,idz,zval,inbv2,work)    
        end do    
    end do
    
    ! q -> r
    kcolq = leftq - kq + 1
    do r=1,kr
        temp4(r) = dbvalu(tq(kcolq:),temp3(:,r),kq,kq,idq,qval,inbv3,work)    
    end do
    
    ! r
    kcolr = leftr - kr + 1
    db5val = dbvalu(tr(kcolr:),temp4,kr,kr,idr,rval,inbv4,work) 
    
    end function db5val
!*****************************************************************************************

!*****************************************************************************************
!****f* bspline_module/db6ink
!
!  NAME
!    db6ink
!
!  DESCRIPTION
!    db6ink determines the parameters of a function that interpolates
!    the six-dimensional gridded data (x(i),y(j),z(k),q(l),r(m),s(n),fcn(i,j,k,l,m,n)) for
!    i=1,..,nx, j=1,..,ny, k=1,..,nz, l=1,..,nq, m=1,..,nr, n=1,..,ns. 
!    the interpolating function and its derivatives may subsequently be evaluated 
!    by the function db6val.
!
!    See db3ink header for more details.
!
!  AUTHOR
!    Jacob Williams, 2/24/2015
!
!  SOURCE

    subroutine db6ink(x,nx,y,ny,z,nz,q,nq,r,nr,s,ns,&
                        fcn,&
                        kx,ky,kz,kq,kr,ks,&
                        tx,ty,tz,tq,tr,ts,&
                        bcoef,iflag)

    integer,intent(in)                                :: nx,ny,nz,nq,nr,ns
    integer,intent(in)                                :: kx,ky,kz,kq,kr,ks
    integer,intent(inout)                             :: iflag
    real(wp),dimension(nx),intent(in)                 :: x
    real(wp),dimension(ny),intent(in)                 :: y
    real(wp),dimension(nz),intent(in)                 :: z
    real(wp),dimension(nq),intent(in)                 :: q
    real(wp),dimension(nr),intent(in)                 :: r
    real(wp),dimension(ns),intent(in)                 :: s
    real(wp),dimension(nx,ny,nz,nq,nr,ns),intent(in)  :: fcn
    real(wp),dimension(:),intent(inout)               :: tx,ty,tz,tq,tr,ts
    real(wp),dimension(nx,ny,nz,nq,nr,ns),intent(out) :: bcoef
           
    real(wp),dimension(nx*ny*nz*nq*nr*ns) :: temp
    real(wp),dimension(max( 2*kx*(nx+1),&
                            2*ky*(ny+1),&
                            2*kz*(nz+1),&
                            2*kq*(nq+1),&
                            2*kr*(nr+1),&
                            2*ks*(ns+1))) :: work
    logical :: status_ok
      
    ! check validity of input
    
    call check_inputs('db6ink',&
                        iflag,&
                        nx=nx,ny=ny,nz=nz,nq=nq,nr=nr,ns=ns,&
                        kx=kx,ky=ky,kz=kz,kq=kq,kr=kr,ks=ks,&
                        x=x,y=y,z=z,q=q,r=r,s=s,&
                        tx=tx,ty=ty,tz=tz,tq=tq,tr=tr,ts=ts,&
                        status_ok=status_ok)
                        
    if (status_ok) then
    
        ! choose knots

        if (iflag == 0) then
            call dbknot(x,nx,kx,tx)
            call dbknot(y,ny,ky,ty)
            call dbknot(z,nz,kz,tz)
            call dbknot(q,nq,kq,tq)
            call dbknot(r,nr,kr,tr)
            call dbknot(s,ns,ks,ts)
        end if

        ! construct b-spline coefficients
    
        call dbtpcf(x,nx,fcn,  nx,ny*nz*nq*nr*ns,tx,kx,temp, work)
        call dbtpcf(y,ny,temp, ny,nx*nz*nq*nr*ns,ty,ky,bcoef,work)
        call dbtpcf(z,nz,bcoef,nz,nx*ny*nq*nr*ns,tz,kz,temp, work)
        call dbtpcf(q,nq,temp, nq,nx*ny*nz*nr*ns,tq,kq,bcoef,work)
        call dbtpcf(r,nr,bcoef,nr,nx*ny*nz*nq*ns,tr,kr,temp, work)
        call dbtpcf(s,ns,temp, ns,nx*ny*nz*nq*nr,ts,ks,bcoef,work)
      
        iflag = 1
     
     end if

    end subroutine db6ink
!*****************************************************************************************

!*****************************************************************************************
!****f* bspline_module/db6val
!
!  NAME
!    db6val
!
!  DESCRIPTION
!    db6val evaluates the tensor product piecewise polynomial
!    interpolant constructed by the routine db6ink or one of its
!    derivatives at the point (xval,yval,zval,qval,rval,sval). to evaluate the
!    interpolant itself, set idx=idy=idz=idq=idr=ids=0, to evaluate the first
!    partial with respect to x, set idx=1,idy=idz=idq=idr=ids=0, and so on.
!
!    See db3val header for more information.
!
!  AUTHOR
!    Jacob Williams, 2/24/2025
!
!  SOURCE

    real(wp) function db6val(xval,yval,zval,qval,rval,sval,&
                                idx,idy,idz,idq,idr,ids,&
                                tx,ty,tz,tq,tr,ts,&
                                nx,ny,nz,nq,nr,ns,&
                                kx,ky,kz,kq,kr,ks,&
                                bcoef)

    integer,intent(in)                               :: idx,idy,idz,idq,idr,ids
    integer,intent(in)                               :: nx,ny,nz,nq,nr,ns
    integer,intent(in)                               :: kx,ky,kz,kq,kr,ks
    real(wp),intent(in)                              :: xval,yval,zval,qval,rval,sval
    real(wp),dimension(:),intent(in)                 :: tx,ty,tz,tq,tr,ts
    real(wp),dimension(nx,ny,nz,nq,nr,ns),intent(in) :: bcoef
    
    real(wp),dimension(ky,kz,kq,kr,ks)            :: temp1
    real(wp),dimension(kz,kq,kr,ks)               :: temp2
    real(wp),dimension(kq,kr,ks)                  :: temp3
    real(wp),dimension(kr,ks)                     :: temp4
    real(wp),dimension(ks)                        :: temp5
    real(wp),dimension(3*max(kx,ky,kz,kq,kr,ks))  :: work
    
    integer :: inbv1,inbv2,inbv3,inbv4,inbv5,&
                lefty,leftz,leftq,leftr,lefts,&
                mflag,&
                kcoly,kcolz,kcolq,kcolr,kcols,&
                i,j,k,q,r,s

    integer,save :: iloy  = 1
    integer,save :: iloz  = 1
    integer,save :: iloq  = 1
    integer,save :: ilor  = 1
    integer,save :: ilos  = 1
    integer,save :: inbvx = 1
    
    db6val = 0.0_wp

    if (xval<tx(1) .or. xval>tx(nx+kx) ) return
    if (yval<ty(1) .or. yval>ty(ny+ky) ) return
    if (zval<tz(1) .or. zval>tz(nz+kz) ) return
    if (qval<tq(1) .or. qval>tq(nq+kq) ) return
    if (rval<tr(1) .or. rval>tr(nr+kr) ) return
    if (sval<ts(1) .or. sval>ts(ns+ks) ) return

    call dintrv(ty,ny+ky,yval,iloy,lefty,mflag); if (mflag /= 0) return
    call dintrv(tz,nz+kz,zval,iloz,leftz,mflag); if (mflag /= 0) return
    call dintrv(tq,nq+kq,qval,iloq,leftq,mflag); if (mflag /= 0) return
    call dintrv(tr,nr+kr,rval,ilor,leftr,mflag); if (mflag /= 0) return
    call dintrv(ts,ns+ks,sval,ilos,lefts,mflag); if (mflag /= 0) return

    inbv1 = 1
    inbv2 = 1
    inbv3 = 1
    inbv4 = 1
    inbv5 = 1

    ! x -> y, z, q, r, s    
    kcols = lefts - ks
    do s=1,ks
        kcols = kcols + 1
        kcolr = leftr - kr
        do r=1,kr
            kcolr = kcolr + 1
            kcolq = leftq - kq
            do q=1,kq
                kcolq = kcolq + 1
                kcolz = leftz - kz
                do k=1,kz
                    kcolz = kcolz + 1
                    kcoly = lefty - ky
                    do j=1,ky
                        kcoly = kcoly + 1
                        temp1(j,k,q,r,s) = dbvalu(tx,bcoef(:,kcoly,kcolz,kcolq,kcolr,kcols),&
                                                    nx,kx,idx,xval,inbvx,work)
                    end do
                end do
            end do    
        end do
    end do
    
    ! y -> z, q, r, s
    kcoly = lefty - ky + 1
    do s=1,ks
        do r=1,kr
            do q=1,kq
                do k=1,kz
                    temp2(k,q,r,s) = dbvalu(ty(kcoly:),temp1(:,k,q,r,s),ky,ky,idy,yval,inbv1,work)    
                end do
            end do
        end do
    end do
    
    ! z -> q, r, s
    kcolz = leftz - kz + 1    
    do s=1,ks
        do r=1,kr
            do q=1,kq
                temp3(q,r,s) = dbvalu(tz(kcolz:),temp2(:,q,r,s),kz,kz,idz,zval,inbv2,work)    
            end do    
        end do
    end do
    
    ! q -> r, s
    kcolq = leftq - kq + 1
    do s=1,ks
        do r=1,kr
            temp4(r,s) = dbvalu(tq(kcolq:),temp3(:,r,s),kq,kq,idq,qval,inbv3,work)    
        end do
    end do
    
    ! r -> s
    kcolr = leftr - kr + 1
    do s=1,ks
        temp5(s) = dbvalu(tr(kcolr:),temp4(:,s),kr,kr,idr,rval,inbv4,work)    
    end do
        
    ! s
    kcols = lefts - ks + 1
    db6val = dbvalu(ts(kcols:),temp5,ks,ks,ids,sval,inbv5,work) 

    end function db6val
!*****************************************************************************************

!*****************************************************************************************
!****if* bspline_module/check_inputs
!
!  NAME
!    check_inputs
!
!  DESCRIPTION
!    Check the validity of the inputs to the "ink" routines.
!    Prints warning message if there is an error, 
!        and also sets iflag and status_ok.
!
!    Supports up to 6D: x,y,z,q,r,s
!
!  NOTES
!    The code is new, but the logic is based on the original
!    logic in the CMLIB routines db2ink and db3ink.
!
!  AUTHOR
!    Jacob Williams, 2/24/2015
!
!  SOURCE

    subroutine check_inputs(routine,&
                            iflag,&
                            nx,ny,nz,nq,nr,ns,&
                            kx,ky,kz,kq,kr,ks,&
                            x,y,z,q,r,s,&
                            tx,ty,tz,tq,tr,ts,&
                            status_ok)
    
    implicit none
    
    character(len=*),intent(in)                :: routine
    integer,intent(inout)                      :: iflag
    integer,intent(in),optional                :: nx,ny,nz,nq,nr,ns
    integer,intent(in),optional                :: kx,ky,kz,kq,kr,ks
    real(wp),dimension(:),intent(in),optional  :: x,y,z,q,r,s
    real(wp),dimension(:),intent(in),optional  :: tx,ty,tz,tq,tr,ts
    logical,intent(out)                        :: status_ok
    
    logical :: error
    
    status_ok = .false.
    
    if ((iflag < 0) .or. (iflag > 1)) then
    
          write(*,*) trim(routine)//' - iflag is out of range: ',iflag
          iflag = 2
          
    else
    
        call check('x',nx,kx,x,tx,[3,4,5,6],    error); if (error) return
        call check('y',ny,ky,y,ty,[7,8,9,10],   error); if (error) return
        call check('z',nz,kz,z,tz,[11,12,13,14],error); if (error) return
        call check('q',nq,kq,q,tq,[15,16,17,18],error); if (error) return
        call check('r',nr,kr,r,tr,[19,20,21,22],error); if (error) return
        call check('s',ns,ks,s,ts,[23,24,25,26],error); if (error) return

        status_ok = .true.
    
    end if
          
    contains
    
        subroutine check(s,n,k,x,t,ierrs,error)  !check t,x,n,k for validity
        
        implicit none
        
        character(len=1),intent(in),optional       :: s        !coordinate string: 'x','y','z','q','r','s'
        integer,intent(in),optional                :: n        !size of x
        integer,intent(in),optional                :: k        !order
        real(wp),dimension(:),intent(in),optional  :: x        !abcissae vector
        real(wp),dimension(:),intent(in),optional  :: t        !knot vector size(n+k)
        integer,dimension(4),intent(in)            :: ierrs    !int error codes for n,k,x,t checks
        logical,intent(out)                        :: error    !true if there was an error
        
        if (present(n)) then
            call check_n('n'//s,n,ierrs(1),error); if (error) return
            if (present(k)) then
                call check_k('k'//s,k,n,ierrs(2),error); if (error) return
            end if
            if (present(x)) then
                call check_x(s,n,x,ierrs(3),error); if (error) return
            end if
            if (iflag /= 0) then
                if (present(k) .and. present(t)) then
                    call check_t('t'//s,n,k,t,ierrs(4),error); if (error) return
                end if
            end if
        end if
        
        end subroutine check
        
        subroutine check_n(s,n,ierr,error)
        
        implicit none
        
        integer,intent(in)          :: n
        character(len=*),intent(in) :: s
        integer,intent(in)          :: ierr
        logical,intent(out)         :: error
        
        if (n < 3) then
            write(*,*) trim(routine)//' - '//trim(s)//' is out of range: ',n
            iflag = ierr
            error = .true.
        else
            error = .false.
        end if        
          
          end subroutine check_n

        subroutine check_k(s,k,n,ierr,error)
        
        implicit none
        
        character(len=*),intent(in) :: s
        integer,intent(in)          :: k
        integer,intent(in)          :: n
        integer,intent(in)          :: ierr
        logical,intent(out)         :: error
        
        if ((k < 2) .or. (k >= n)) then              
              write(*,*) trim(routine)//' - '//trim(s)//' is out of range: ',k
              iflag = ierr
              error = .true.
          else
              error = .false.
        end if
                  
          end subroutine check_k
          
          subroutine check_x(s,n,x,ierr,error)
          
        implicit none
        
        character(len=*),intent(in)       :: s
        integer,intent(in)                :: n
        real(wp),dimension(:),intent(in)  :: x
        integer,intent(in)                :: ierr
        logical,intent(out)               :: error
        
        integer :: i
        
        error = .true.
        do i=2,n
            if (x(i) <= x(i-1)) then
                  iflag = ierr
                write(*,*) trim(routine)//' - '//trim(s)//&
                            ' array must be strictly increasing'
                return
            end if 
        end do          
          error = .false.
                  
          end subroutine check_x
          
          subroutine check_t(s,n,k,t,ierr,error)
          
        implicit none
        
        character(len=*),intent(in)       :: s
        integer,intent(in)                :: n
        integer,intent(in)                :: k
        real(wp),dimension(:),intent(in)  :: t
        integer,intent(in)                :: ierr
        logical,intent(out)               :: error
        
        integer :: i
        
        error = .true.
        do i=2,n + k
            if (t(i) < t(i-1))  then
                  iflag = ierr
                write(*,*) trim(routine)//' - '//trim(s)//&
                            ' array must be non-decreasing'
                return
            end if 
        end do          
          error = .false.
                  
          end subroutine check_t
          
    end subroutine check_inputs
!*****************************************************************************************

!*****************************************************************************************
!****if* bspline_module/dbknot
!
!  NAME
!    dbknot
!
!  DESCRIPTION
!    dbknot chooses a knot sequence for interpolation of order k at the
!    data points x(i), i=1,..,n.  the n+k knots are placed in the array
!    t.  k knots are placed at each endpoint and not-a-knot end
!    conditions are used.  the remaining knots are placed at data points
!    if n is even and between data points if n is odd.  the rightmost
!    knot is shifted slightly to the right to insure proper interpolation
!    at x(n) (see page 350 of the reference).
!    
!  SOURCE

    subroutine dbknot(x,n,k,t)

    implicit none
    
    integer,intent(in)                 :: n
    integer,intent(in)                 :: k
    real(wp),dimension(n),intent(in)   :: x
    real(wp),dimension(:),intent(out)  :: t

    integer  :: i, j, ipj, npj, ip1, jstrt
    real(wp) :: rnot

    !put k knots at each endpoint
    !(shift right endpoints slightly -- see pg 350 of reference)
    rnot = x(n) + 0.1_wp*( x(n)-x(n-1) )
    do j=1,k
        t(j)   = x(1)
        npj    = n + j
        t(npj) = rnot
    end do

    !distribute remaining knots

    if (mod(k,2) == 1)  then

        !case of odd k --  knots between data points
        
        i = (k-1)/2 - k
        ip1 = i + 1
        jstrt = k + 1
        do j=jstrt,n
            ipj = i + j
            t(j) = 0.5_wp*( x(ipj) + x(ipj+1) )
        end do

    else

        !case of even k --  knots at data points

        i = (k/2) - k
        jstrt = k+1
        do j=jstrt,n
            ipj = i + j
            t(j) = x(ipj)
        end do

    end if

    end subroutine dbknot
!*****************************************************************************************
      
!*****************************************************************************************
!****if* bspline_module/dbtpcf
!
!  NAME
!    dbtpcf
!
!  DESCRIPTION
!    dbtpcf computes b-spline interpolation coefficients for nf sets
!    of data stored in the columns of the array fcn. the b-spline
!    coefficients are stored in the rows of bcoef however.
!    each interpolation is based on the n abcissa stored in the
!    array x, and the n+k knots stored in the array t. the order
!    of each interpolation is k. the work array must be of length
!    at least 2*k*(n+1).
!
!  SOURCE

    subroutine dbtpcf(x,n,fcn,ldf,nf,t,k,bcoef,work)

    integer  :: n, nf, ldf, k
    real(wp) :: x(n), fcn(ldf,nf), t(*), bcoef(nf,n), work(*)

    integer :: i, j, m1, m2, iq, iw

    ! check for null input

    if (nf > 0)  then

        ! partition work array
        m1 = k - 1
        m2 = m1 + k
        iq = 1 + n
        iw = iq + m2*n+1

        ! compute b-spline coefficients

        ! first data set

        call dbintk(x,fcn,t,n,k,work,work(iq),work(iw))
        do i=1,n
            bcoef(1,i) = work(i)
        end do

        !  all remaining data sets by back-substitution

        if (nf == 1)  return
        do j=2,nf
            do i=1,n
                work(i) = fcn(i,j)
            end do
            call dbnslv(work(iq),m2,n,m1,m1,work)
            do i=1,n
                bcoef(j,i) = work(i)
            end do
        end do
    
    end if

    end subroutine dbtpcf
!*****************************************************************************************

      subroutine dbintk(x,y,t,n,k,bcoef,q,work)
!***begin prologue  dbintk
!***date written   800901   (yymmdd)
!***revision date  820801   (yymmdd)
!***revision history  (yymmdd)
!   000330  modified array declarations.  (jec)
!
!***category no.  e1a
!***keywords  b-spline,data fitting,real(wp),interpolation,
!             spline
!***author  amos, d. e., (snla)
!***purpose  produces the b-spline coefficients, bcoef, of the
!            b-spline of order k with knots t(i), i=1,...,n+k, which
!            takes on the value y(i) at x(i), i=1,...,n.
!***description
!
!     written by carl de boor and modified by d. e. amos
!
!     references
!
!         a practical guide to splines by c. de boor, applied
!         mathematics series 27, springer, 1979.
!
!     abstract    **** a real(wp) routine ****
!
!         dbintk is the splint routine of the reference.
!
!         dbintk produces the b-spline coefficients, bcoef, of the
!         b-spline of order k with knots t(i), i=1,...,n+k, which
!         takes on the value y(i) at x(i), i=1,...,n.  the spline or
!         any of its derivatives can be evaluated by calls to dbvalu.
!
!         the i-th equation of the linear system a*bcoef = b for the
!         coefficients of the interpolant enforces interpolation at
!         x(i), i=1,...,n.  hence, b(i) = y(i), for all i, and a is
!         a band matrix with 2k-1 bands if a is invertible.  the matrix
!         a is generated row by row and stored, diagonal by diagonal,
!         in the rows of q, with the main diagonal going into row k.
!         the banded system is then solved by a call to dbnfac (which
!         constructs the triangular factorization for a and stores it
!         again in q), followed by a call to dbnslv (which then
!         obtains the solution bcoef by substitution).  dbnfac does no
!         pivoting, since the total positivity of the matrix a makes
!         this unnecessary.  the linear system to be solved is
!         (theoretically) invertible if and only if
!                 t(i) < x(i) < t(i+k),        for all i.
!         equality is permitted on the left for i=1 and on the right
!         for i=n when k knots are used at x(1) or x(n).  otherwise,
!         violation of this condition is certain to lead to an error.
!
!         dbintk calls dbspvn, dbnfac, dbnslv, xerror
!
!     description of arguments
!
!         input       x,y,t are real(wp)
!           x       - vector of length n containing data point abscissa
!                     in strictly increasing order.
!           y       - corresponding vector of length n containing data
!                     point ordinates.
!           t       - knot vector of length n+k
!                     since t(1),..,t(k) <= x(1) and t(n+1),..,t(n+k)
!                     >= x(n), this leaves only n-k knots (not nec-
!                     essarily x(i) values) interior to (x(1),x(n))
!           n       - number of data points, n >= k
!           k       - order of the spline, k >= 1
!
!         output      bcoef,q,work are real(wp)
!           bcoef   - a vector of length n containing the b-spline
!                     coefficients
!           q       - a work vector of length (2*k-1)*n, containing
!                     the triangular factorization of the coefficient
!                     matrix of the linear system being solved.  the
!                     coefficients for the interpolant of an
!                     additional data set (x(i),yy(i)), i=1,...,n
!                     with the same abscissa can be obtained by loading
!                     yy into bcoef and then executing
!                         call dbnslv(q,2k-1,n,k-1,k-1,bcoef)
!           work    - work vector of length 2*k
!
!     error conditions
!         improper input is a fatal error
!         singular system of equations is a fatal error
!***references  c. de boor, *a practical guide to splines*, applied
!                 mathematics series 27, springer, 1979.
!               d.e. amos, *computation with splines and b-splines*,
!                 sand78-1968,sandia laboratories,march,1979.
!***routines called  dbnfac,dbnslv,dbspvn,xerror
!***end prologue  dbintk
!
!
      integer iflag, iwork, k, n, i, ilp1mx, j, jj, km1, kpkm2, left,&
       lenq, np1
      real(wp) bcoef(n), y(n), q(*), t(*), x(n), xi, work(*)
!     dimension q(2*k-1,n), t(n+k)
!***first executable statement  dbintk
      if(k<1) go to 100
      if(n<k) go to 105
      jj = n - 1
      if(jj==0) go to 6
      do 5 i=1,jj
      if(x(i)>=x(i+1)) go to 110
    5 continue
    6 continue
      np1 = n + 1
      km1 = k - 1
      kpkm2 = 2*km1
      left = k
!                zero out all entries of q
      lenq = n*(k+km1)
      do 10 i=1,lenq
        q(i) = 0.0d0
   10 continue
!
!  ***   loop over i to construct the  n  interpolation equations
      do 50 i=1,n
        xi = x(i)
        ilp1mx = min(i+k,np1)
!        *** find  left  in the closed interval (i,i+k-1) such that
!                t(left) <= x(i) < t(left+1)
!        matrix is singular if this is not possible
        left = max(left,i)
        if (xi<t(left)) go to 80
   20   if (xi<t(left+1)) go to 30
        left = left + 1
        if (left<ilp1mx) go to 20
        left = left - 1
        if (xi>t(left+1)) go to 80
!        *** the i-th equation enforces interpolation at xi, hence
!        a(i,j) = b(j,k,t)(xi), all j. only the  k  entries with  j =
!        left-k+1,...,left actually might be nonzero. these  k  numbers
!        are returned, in  bcoef (used for temp.storage here), by the
!        following
   30   call dbspvn(t, k, k, 1, xi, left, bcoef, work, iwork)
!        we therefore want  bcoef(j) = b(left-k+j)(xi) to go into
!        a(i,left-k+j), i.e., into  q(i-(left+j)+2*k,(left+j)-k) since
!        a(i+j,j)  is to go into  q(i+k,j), all i,j,  if we consider  q
!        as a two-dim. array , with  2*k-1  rows (see comments in
!        dbnfac). in the present program, we treat  q  as an equivalent
!        one-dimensional array (because of fortran restrictions on
!        dimension statements) . we therefore want  bcoef(j) to go into
!        entry
!            i -(left+j) + 2*k + ((left+j) - k-1)*(2*k-1)
!                   =  i-left+1 + (left -k)*(2*k-1) + (2*k-2)*j
!        of  q .
        jj = i - left + 1 + (left-k)*(k+km1)
        do 40 j=1,k
          jj = jj + kpkm2
          q(jj) = bcoef(j)
   40   continue
   50 continue
!
!     ***obtain factorization of  a  , stored again in  q.
      call dbnfac(q, k+km1, n, km1, km1, iflag)

      !go to (60, 90), iflag   !JW removed obsolescent Computed GOTO
      select case (iflag)
      case(1); goto 60  !success
      case(2); goto 90  !failure
      end select

!     *** solve  a*bcoef = y  by backsubstitution
   60 do 70 i=1,n
        bcoef(i) = y(i)
   70 continue
      call dbnslv(q, k+km1, n, km1, km1, bcoef)
      return
!
!
   80 continue
      call xerror( ' dbintk,  some abscissa was not in the support of the'//&
                   ' corresponding basis function and the system is singular.',109,2,1)
      return
   90 continue
      call xerror( ' dbintk,  the system of solver detects a singular system'//&
                   ' although the theoretical conditions for a solution were satisfied.',123,8,1)
      return
  100 continue
      call xerror( ' dbintk,  k does not satisfy k>=1', 35, 2, 1)
      return
  105 continue
      call xerror( ' dbintk,  n does not satisfy n>=k', 35, 2, 1)
      return
  110 continue
      call xerror( ' dbintk,  x(i) does not satisfy x(i)<x(i+1) for some i', 57, 2, 1)
      return
      end subroutine dbintk

      subroutine dbnfac(w,nroww,nrow,nbandl,nbandu,iflag)
!***begin prologue  dbnfac
!***refer to  dbint4,dbintk
!
!  dbnfac is the banfac routine from
!        * a practical guide to splines *  by c. de boor
!
!  dbnfac is a real(wp) routine
!
!  returns in  w  the lu-factorization (without pivoting) of the banded
!  matrix  a  of order  nrow  with  (nbandl + 1 + nbandu) bands or diag-
!  onals in the work array  w .
!
! *****  i n p u t  ****** w is real(wp)
!  w.....work array of size  (nroww,nrow)  containing the interesting
!        part of a banded matrix  a , with the diagonals or bands of  a
!        stored in the rows of  w , while columns of  a  correspond to
!        columns of  w . this is the storage mode used in  linpack  and
!        results in efficient innermost loops.
!           explicitly,  a  has  nbandl  bands below the diagonal
!                            +     1     (main) diagonal
!                            +   nbandu  bands above the diagonal
!        and thus, with    middle = nbandu + 1,
!          a(i+j,j)  is in  w(i+middle,j)  for i=-nbandu,...,nbandl
!                                              j=1,...,nrow .
!        for example, the interesting entries of a (1,2)-banded matrix
!        of order  9  would appear in the first  1+1+2 = 4  rows of  w
!        as follows.
!                          13 24 35 46 57 68 79
!                       12 23 34 45 56 67 78 89
!                    11 22 33 44 55 66 77 88 99
!                    21 32 43 54 65 76 87 98
!
!        all other entries of  w  not identified in this way with an en-
!        try of  a  are never referenced .
!  nroww.....row dimension of the work array  w .
!        must be  >=  nbandl + 1 + nbandu  .
!  nbandl.....number of bands of  a  below the main diagonal
!  nbandu.....number of bands of  a  above the main diagonal .
!
! *****  o u t p u t  ****** w is real(wp)
!  iflag.....integer indicating success( = 1) or failure ( = 2) .
!     if  iflag = 1, then
!  w.....contains the lu-factorization of  a  into a unit lower triangu-
!        lar matrix  l  and an upper triangular matrix  u (both banded)
!        and stored in customary fashion over the corresponding entries
!        of  a . this makes it possible to solve any particular linear
!        system  a*x = b  for  x  by a
!              call dbnslv ( w, nroww, nrow, nbandl, nbandu, b )
!        with the solution x  contained in  b  on return .
!     if  iflag = 2, then
!        one of  nrow-1, nbandl,nbandu failed to be nonnegative, or else
!        one of the potential pivots was found to be zero indicating
!        that  a  does not have an lu-factorization. this implies that
!        a  is singular in case it is totally positive .
!
! *****  m e t h o d  ******
!     gauss elimination  w i t h o u t  pivoting is used. the routine is
!  intended for use with matrices  a  which do not require row inter-
!  changes during factorization, especially for the  t o t a l l y
!  p o s i t i v e  matrices which occur in spline calculations.
!     the routine should not be used for an arbitrary banded matrix.
!***routines called  (none)
!***end prologue  dbnfac
!
      integer iflag, nbandl, nbandu, nrow, nroww, i, ipk, j, jmax, k,&
       kmax, middle, midmk, nrowm1
      real(wp) w(nroww,nrow), factor, pivot
!
!***first executable statement  dbnfac
      iflag = 1
      middle = nbandu + 1
!                         w(middle,.) contains the main diagonal of  a .
      nrowm1 = nrow - 1

      !if (nrowm1) 120, 110, 10    !JW removed obsolescent arithmetic IF statement
      if (nrowm1 < 0) then;      goto 120
      elseif (nrowm1 == 0) then; goto 110
      else;                      goto 10
      end if

   10 if (nbandl>0) go to 30
!                a is upper triangular. check that diagonal is nonzero .
      do 20 i=1,nrowm1
        if (w(middle,i)==0.0d0) go to 120
   20 continue
      go to 110
   30 if (nbandu>0) go to 60
!              a is lower triangular. check that diagonal is nonzero and
!                 divide each column by its diagonal .
      do 50 i=1,nrowm1
        pivot = w(middle,i)
        if (pivot==0.0d0) go to 120
        jmax = min(nbandl,nrow-i)
        do 40 j=1,jmax
          w(middle+j,i) = w(middle+j,i)/pivot
   40   continue
   50 continue
      return
!
!        a  is not just a triangular matrix. construct lu factorization
   60 do 100 i=1,nrowm1
!                                  w(middle,i)  is pivot for i-th step .
        pivot = w(middle,i)
        if (pivot==0.0d0) go to 120
!                 jmax  is the number of (nonzero) entries in column  i
!                     below the diagonal .
        jmax = min(nbandl,nrow-i)
!              divide each entry in column  i  below diagonal by pivot .
        do 70 j=1,jmax
          w(middle+j,i) = w(middle+j,i)/pivot
   70   continue
!                 kmax  is the number of (nonzero) entries in row  i  to
!                     the right of the diagonal .
        kmax = min(nbandu,nrow-i)
!                  subtract  a(i,i+k)*(i-th column) from (i+k)-th column
!                  (below row  i ) .
        do 90 k=1,kmax
          ipk = i + k
          midmk = middle - k
          factor = w(midmk,ipk)
          do 80 j=1,jmax
            w(midmk+j,ipk) = w(midmk+j,ipk) - w(middle+j,i)*factor
   80     continue
   90   continue
  100 continue
!                                       check the last diagonal entry .
  110 if (w(middle,nrow)/=0.0d0) return
  120 iflag = 2
      return
      end subroutine dbnfac
      
      subroutine dbnslv(w,nroww,nrow,nbandl,nbandu,b)
!***begin prologue  dbnslv
!***refer to  dbint4,dbintk
!
!  dbnslv is the banslv routine from
!        * a practical guide to splines *  by c. de boor
!
!  dbnslv is a real(wp) routine
!
!  companion routine to  dbnfac . it returns the solution  x  of the
!  linear system  a*x = b  in place of  b , given the lu-factorization
!  for  a  in the work array  w from dbnfac.
!
! *****  i n p u t  ****** w,b are real(wp)
!  w, nroww,nrow,nbandl,nbandu.....describe the lu-factorization of a
!        banded matrix  a  of order  nrow  as constructed in  dbnfac .
!        for details, see  dbnfac .
!  b.....right side of the system to be solved .
!
! *****  o u t p u t  ****** b is real(wp)
!  b.....contains the solution  x , of order  nrow .
!
! *****  m e t h o d  ******
!     (with  a = l*u, as stored in  w,) the unit lower triangular system
!  l(u*x) = b  is solved for  y = u*x, and  y  stored in  b . then the
!  upper triangular system  u*x = y  is solved for  x  . the calcul-
!  ations are so arranged that the innermost loops stay within columns.
!***routines called  (none)
!***end prologue  dbnslv
!
      integer nbandl, nbandu, nrow, nroww, i, j, jmax, middle, nrowm1
      real(wp) w(nroww,nrow), b(nrow)
!***first executable statement  dbnslv
      middle = nbandu + 1
      if (nrow==1) go to 80
      nrowm1 = nrow - 1
      if (nbandl==0) go to 30
!                                 forward pass
!            for i=1,2,...,nrow-1, subtract  right side(i)*(i-th column
!            of  l )  from right side  (below i-th row) .
      do 20 i=1,nrowm1
        jmax = min(nbandl,nrow-i)
        do 10 j=1,jmax
          b(i+j) = b(i+j) - b(i)*w(middle+j,i)
   10   continue
   20 continue
!                                 backward pass
!            for i=nrow,nrow-1,...,1, divide right side(i) by i-th diag-
!            onal entry of  u, then subtract  right side(i)*(i-th column
!            of  u)  from right side  (above i-th row).
   30 if (nbandu>0) go to 50
!                                a  is lower triangular .
      do 40 i=1,nrow
        b(i) = b(i)/w(1,i)
   40 continue
      return
   50 i = nrow
   60 b(i) = b(i)/w(middle,i)
      jmax = min(nbandu,i-1)
      do 70 j=1,jmax
        b(i-j) = b(i-j) - b(i)*w(middle-j,i)
   70 continue
      i = i - 1
      if (i>1) go to 60
   80 b(1) = b(1)/w(middle,1)
      return
      end subroutine dbnslv

      subroutine dbspvn(t,jhigh,k,index,x,ileft,vnikx,work,iwork)
!***begin prologue  dbspvn
!***date written   800901   (yymmdd)
!***revision date  820801   (yymmdd)
!***revision history  (yymmdd)
!   000330  modified array declarations.  (jec)
!
!***category no.  e3,k6
!***keywords  b-spline,data fitting,real(wp),interpolation,
!             spline
!***author  amos, d. e., (snla)
!***purpose  calculates the value of all (possibly) nonzero basis
!            functions at x.
!***description
!
!     written by carl de boor and modified by d. e. amos
!
!     reference
!         siam j. numerical analysis, 14, no. 3, june, 1977, pp.441-472.
!
!     abstract    **** a real(wp) routine ****
!         dbspvn is the bsplvn routine of the reference.
!
!         dbspvn calculates the value of all (possibly) nonzero basis
!         functions at x of order max(jhigh,(j+1)*(index-1)), where t(k)
!         <= x <= t(n+1) and j=iwork is set inside the routine on
!         the first call when index=1.  ileft is such that t(ileft) <=
!         x < t(ileft+1).  a call to dintrv(t,n+1,x,ilo,ileft,mflag)
!         produces the proper ileft.  dbspvn calculates using the basic
!         algorithm needed in dbspvd.  if only basis functions are
!         desired, setting jhigh=k and index=1 can be faster than
!         calling dbspvd, but extra coding is required for derivatives
!         (index=2) and dbspvd is set up for this purpose.
!
!         left limiting values are set up as described in dbspvd.
!
!     description of arguments
!
!         input      t,x are real(wp)
!          t       - knot vector of length n+k, where
!                    n = number of b-spline basis functions
!                    n = sum of knot multiplicities-k
!          jhigh   - order of b-spline, 1 <= jhigh <= k
!          k       - highest possible order
!          index   - index = 1 gives basis functions of order jhigh
!                          = 2 denotes previous entry with work, iwork
!                              values saved for subsequent calls to
!                              dbspvn.
!          x       - argument of basis functions,
!                    t(k) <= x <= t(n+1)
!          ileft   - largest integer such that
!                    t(ileft) <= x <  t(ileft+1)
!
!         output     vnikx, work are real(wp)
!          vnikx   - vector of length k for spline values.
!          work    - a work vector of length 2*k
!          iwork   - a work parameter.  both work and iwork contain
!                    information necessary to continue for index = 2.
!                    when index = 1 exclusively, these are scratch
!                    variables and can be used for other purposes.
!
!     error conditions
!         improper input is a fatal error.
!***references  c. de boor, *package for calculating with b-splines*,
!                 siam journal on numerical analysis, volume 14, no. 3,
!                 june 1977, pp. 441-472.
!***routines called  xerror
!***end prologue  dbspvn
!
!
      integer ileft, imjp1, index, ipj, iwork, jhigh, jp1, jp1ml, k, l
      real(wp) t, vm, vmprev, vnikx, work, x
!     dimension t(ileft+jhigh)
      dimension t(*), vnikx(k), work(*)
!     content of j, deltam, deltap is expected unchanged between calls.
!     work(i) = deltap(i), work(k+i) = deltam(i), i = 1,k
!***first executable statement  dbspvn
      if(k<1) go to 90
      if(jhigh>k .or. jhigh<1) go to 100
      if(index<1 .or. index>2) go to 105
      if(x<t(ileft) .or. x>t(ileft+1)) go to 110

      !go to (10, 20), index    !JW removed obsolescent Computed GOTO
      select case (index)
      case(1); goto 10
      case(2); goto 20
      end select

   10 iwork = 1
      vnikx(1) = 1.0_wp
      if (iwork>=jhigh) go to 40
!
   20 ipj = ileft + iwork
      work(iwork) = t(ipj) - x
      imjp1 = ileft - iwork + 1
      work(k+iwork) = x - t(imjp1)
      vmprev = 0.0d0
      jp1 = iwork + 1
      do 30 l=1,iwork
        jp1ml = jp1 - l
        vm = vnikx(l)/(work(l)+work(k+jp1ml))
        vnikx(l) = vm*work(l) + vmprev
        vmprev = vm*work(k+jp1ml)
   30 continue
      vnikx(jp1) = vmprev
      iwork = jp1
      if (iwork<jhigh) go to 20
!
   40 return
!
!
   90 continue
      call xerror( ' dbspvn,  k does not satisfy k>=1', 35, 2, 1)
      return
  100 continue
      call xerror( ' dbspvn,  jhigh does not satisfy 1<=jhigh<=k',48, 2, 1)
      return
  105 continue
      call xerror( ' dbspvn,  index is not 1 or 2',29,2,1)
      return
  110 continue
      call xerror( ' dbspvn,  x does not satisfy t(ileft)<=x<=t(ileft+1)', 56, 2, 1)
      return
      end subroutine dbspvn
      
      real(wp) function dbvalu(t,a,n,k,ideriv,x,inbv,work)
!***begin prologue  dbvalu
!***date written   800901   (yymmdd)
!***revision date  820801   (yymmdd)
!***revision history  (yymmdd)
!   000330  modified array declarations.  (jec)
!
!***category no.  e3,k6
!***keywords  b-spline,data fitting,real(wp),interpolation,
!             spline
!***author  amos, d. e., (snla)
!***purpose  evaluates the b-representation of a b-spline at x for the
!            function value or any of its derivatives.
!***description
!
!     written by carl de boor and modified by d. e. amos
!
!     reference
!         siam j. numerical analysis, 14, no. 3, june, 1977, pp.441-472.
!
!     abstract   **** a real(wp) routine ****
!         dbvalu is the bvalue function of the reference.
!
!         dbvalu evaluates the b-representation (t,a,n,k) of a b-spline
!         at x for the function value on ideriv=0 or any of its
!         derivatives on ideriv=1,2,...,k-1.  right limiting values
!         (right derivatives) are returned except at the right end
!         point x=t(n+1) where left limiting values are computed.  the
!         spline is defined on t(k) <= x <= t(n+1).  dbvalu returns
!         a fatal error message when x is outside of this interval.
!
!         to compute left derivatives or left limiting values at a
!         knot t(i), replace n by i-1 and set x=t(i), i=k+1,n+1.
!
!         dbvalu calls dintrv
!
!     description of arguments
!
!         input      t,a,x are real(wp)
!          t       - knot vector of length n+k
!          a       - b-spline coefficient vector of length n
!          n       - number of b-spline coefficients
!                    n = sum of knot multiplicities-k
!          k       - order of the b-spline, k >= 1
!          ideriv  - order of the derivative, 0 <= ideriv <= k-1
!                    ideriv = 0 returns the b-spline value
!          x       - argument, t(k) <= x <= t(n+1)
!          inbv    - an initialization parameter which must be set
!                    to 1 the first time dbvalu is called.
!
!         output     work,dbvalu are real(wp)
!          inbv    - inbv contains information for efficient process-
!                    ing after the initial call and inbv must not
!                    be changed by the user.  distinct splines require
!                    distinct inbv parameters.
!          work    - work vector of length 3*k.
!          dbvalu  - value of the ideriv-th derivative at x
!
!     error conditions
!         an improper input is a fatal error
!***references  c. de boor, *package for calculating with b-splines*,
!                 siam journal on numerical analysis, volume 14, no. 3,
!                 june 1977, pp. 441-472.
!***routines called  dintrv,xerror
!***end prologue  dbvalu

    integer,intent(in) :: n
    real(wp),dimension(:),intent(in) :: t
    real(wp),dimension(n),intent(in) :: a
    real(wp),dimension(:) :: work

      integer i,ideriv,iderp1,ihi,ihmkmj,ilo,imk,imkpj, inbv, ipj,&
       ip1, ip1mj, j, jj, j1, j2, k, kmider, kmj, km1, kpk, mflag
      !real(wp) a, fkmj, t, work, x
      real(wp) fkmj,x 
     ! dimension t(*), a(n), work(*)
      
!***first executable statement  dbvalu
      dbvalu = 0.0d0
      if(k<1) go to 102
      if(n<k) go to 101
      if(ideriv<0 .or. ideriv>=k) go to 110
      kmider = k - ideriv
!
! *** find *i* in (k,n) such that t(i) <= x < t(i+1)
!     (or, <= t(i+1) if t(i) < t(i+1) = t(n+1)).
      km1 = k - 1
      call dintrv(t, n+1, x, inbv, i, mflag)
      if (x<t(k)) go to 120
      if (mflag==0) go to 20
      if (x>t(i)) go to 130
   10 if (i==k) go to 140
      i = i - 1
      if (x==t(i)) go to 10
!
! *** difference the coefficients *ideriv* times
!     work(i) = aj(i), work(k+i) = dp(i), work(k+k+i) = dm(i), i=1.k
!
   20 imk = i - k
      do 30 j=1,k
        imkpj = imk + j
        work(j) = a(imkpj)
   30 continue
      if (ideriv==0) go to 60
      do 50 j=1,ideriv
        kmj = k - j
        fkmj = dble(float(kmj))
        do 40 jj=1,kmj
          ihi = i + jj
          ihmkmj = ihi - kmj
          work(jj) = (work(jj+1)-work(jj))/(t(ihi)-t(ihmkmj))*fkmj
   40   continue
   50 continue
!
! *** compute value at *x* in (t(i),(t(i+1)) of ideriv-th derivative,
!     given its relevant b-spline coeff. in aj(1),...,aj(k-ideriv).
   60 if (ideriv==km1) go to 100
      ip1 = i + 1
      kpk = k + k
      j1 = k + 1
      j2 = kpk + 1
      do 70 j=1,kmider
        ipj = i + j
        work(j1) = t(ipj) - x
        ip1mj = ip1 - j
        work(j2) = x - t(ip1mj)
        j1 = j1 + 1
        j2 = j2 + 1
   70 continue
      iderp1 = ideriv + 1
      do 90 j=iderp1,km1
        kmj = k - j
        ilo = kmj
        do 80 jj=1,kmj
          work(jj) = (work(jj+1)*work(kpk+ilo)+work(jj)&
                    *work(k+jj))/(work(kpk+ilo)+work(k+jj))
          ilo = ilo - 1
   80   continue
   90 continue
  100 dbvalu = work(1)
      return
!
!
  101 continue
      call xerror( ' dbvalu,  n does not satisfy n>=k',35,2,1)
      return
  102 continue
      call xerror( ' dbvalu,  k does not satisfy k>=1',35,2,1)
      return
  110 continue
      call xerror( ' dbvalu,  ideriv does not satisfy 0<=ideriv<k',50, 2, 1)
      return
  120 continue
      call xerror( ' dbvalu,  x is n0t greater than or equal to t(k)',48, 2, 1)
      return
  130 continue
      call xerror( ' dbvalu,  x is not less than or equal to t(n+1)',47, 2, 1)
      return
  140 continue
      call xerror( ' dbvalu,  a left limiting value cann0t be obtained at t(k)', 58, 2, 1)
      return
      end function dbvalu
      
      subroutine dintrv(xt,lxt,x,ilo,ileft,mflag)
!***begin prologue  dintrv
!***date written   800901   (yymmdd)
!***revision date  820801   (yymmdd)
!***category no.  e3,k6
!***keywords  b-spline,data fitting,real(wp),interpolation,
!             spline
!***author  amos, d. e., (snla)
!***purpose  computes the largest integer ileft in 1<=ileft<=lxt
!            such that xt(ileft)<=x where xt(*) is a subdivision of
!            the x interval.
!***description
!
!     written by carl de boor and modified by d. e. amos
!
!     reference
!         siam j.  numerical analysis, 14, no. 3, june 1977, pp.441-472.
!
!     abstract    **** a real(wp) routine ****
!         dintrv is the interv routine of the reference.
!
!         dintrv computes the largest integer ileft in 1 <= ileft <=
!         lxt such that xt(ileft) <= x where xt(*) is a subdivision of
!         the x interval.  precisely,
!
!                      x < xt(1)                1         -1
!         if  xt(i) <= x < xt(i+1)  then  ileft=i  , mflag=0
!           xt(lxt) <= x                        lxt        1,
!
!         that is, when multiplicities are present in the break point
!         to the left of x, the largest index is taken for ileft.
!
!     description of arguments
!
!         input      xt,x are real(wp)
!          xt      - xt is a knot or break point vector of length lxt
!          lxt     - length of the xt vector
!          x       - argument
!          ilo     - an initialization parameter which must be set
!                    to 1 the first time the spline array xt is
!                    processed by dintrv.
!
!         output
!          ilo     - ilo contains information for efficient process-
!                    ing after the initial call and ilo must not be
!                    changed by the user.  distinct splines require
!                    distinct ilo parameters.
!          ileft   - largest integer satisfying xt(ileft) <= x
!          mflag   - signals when x lies out of bounds
!
!     error conditions
!         none
!***references  c. de boor, *package for calculating with b-splines*,
!                 siam journal on numerical analysis, volume 14, no. 3,
!                 june 1977, pp. 441-472.
!***routines called  (none)
!***end prologue  dintrv
!
!
      integer ihi, ileft, ilo, istep, lxt, mflag, middle
      real(wp) x, xt
      dimension xt(lxt)
!***first executable statement  dintrv
      ihi = ilo + 1
      if (ihi<lxt) go to 10
      if (x>=xt(lxt)) go to 110
      if (lxt<=1) go to 90
      ilo = lxt - 1
      ihi = lxt
!
   10 if (x>=xt(ihi)) go to 40
      if (x>=xt(ilo)) go to 100
!
! *** now x < xt(ihi) . find lower bound
      istep = 1
   20 ihi = ilo
      ilo = ihi - istep
      if (ilo<=1) go to 30
      if (x>=xt(ilo)) go to 70
      istep = istep*2
      go to 20
   30 ilo = 1
      if (x<xt(1)) go to 90
      go to 70
! *** now x >= xt(ilo) . find upper bound
   40 istep = 1
   50 ilo = ihi
      ihi = ilo + istep
      if (ihi>=lxt) go to 60
      if (x<xt(ihi)) go to 70
      istep = istep*2
      go to 50
   60 if (x>=xt(lxt)) go to 110
      ihi = lxt
!
! *** now xt(ilo) <= x < xt(ihi) . narrow the interval
   70 middle = (ilo+ihi)/2
      if (middle==ilo) go to 100
!     note. it is assumed that middle = ilo in case ihi = ilo+1
      if (x<xt(middle)) go to 80
      ilo = middle
      go to 70
   80 ihi = middle
      go to 70
! *** set output and return
   90 mflag = -1
      ileft = 1
      return
  100 mflag = 0
      ileft = ilo
      return
  110 mflag = 1
      ileft = lxt
      return
      end subroutine dintrv      

!*****************************************************************************************
!****if* bspline_module/d1mach
!
!  NAME
!    d1mach
!
!  DESCRIPTION
!    Just a replacement for the CMLIB machine constants routine.
!
!  SOURCE

    pure function d1mach (i) result(d)
    
    implicit none
    
    real(wp)           :: d
    integer,intent(in) :: i
    
    real(wp),parameter :: x = 1.0_wp
    real(wp),parameter :: b = radix(x)
    
    select case (i)
    case (1)
      d = b**(minexponent(x)-1) ! smallest positive magnitude
    case (2) 
      d = huge(x)               ! largest magnitude
    case (3) 
      d = b**(-digits(x))       ! smallest relative spacing
    case (4) 
      d = b**(1-digits(x))      ! largest relative spacing
    case (5)
      d = log10(b)
    end select
    
    end function d1mach     
!*****************************************************************************************
    
!*****************************************************************************************
!****if* bspline_module/xerror
!
!  NAME
!    xerror
!
!  DESCRIPTION
!    Just a replacement for the CMLIB XERROR routine.
!
!  SOURCE

    subroutine xerror(messg,nmessg,nerr,level)

    implicit none

    character(len=*),intent(in) :: messg
    integer,intent(in),optional :: nmessg,nerr,level
    
    write(*,'(A)') trim(messg)

    end subroutine xerror
!*****************************************************************************************

!*****************************************************************************************
!****if* bspline_module/bspline_test
!
!  NAME
!    bspline_test
!
!  DESCRIPTION
!    Units test for 2d-6d tensor product b-spline interpolation.
!
!  SOURCE

    subroutine bspline_test()

    implicit none
    
    integer,parameter :: nx = 6    !number of points
    integer,parameter :: ny = 6
    integer,parameter :: nz = 6
    integer,parameter :: nq = 6
    integer,parameter :: nr = 6
    integer,parameter :: ns = 6
    
    integer,parameter :: kx = 4    !order
    integer,parameter :: ky = 4
    integer,parameter :: kz = 4
    integer,parameter :: kq = 4
    integer,parameter :: kr = 4
    integer,parameter :: ks = 4
            
    real(wp) :: x(nx),y(ny),z(nz),q(nq),r(nr),s(ns)
    real(wp) :: tx(nx+kx),ty(ny+ky),tz(nz+kz),tq(nq+kq),tr(nr+kr),ts(ns+ks)    
    real(wp) :: fcn_2d(nx,ny)
    real(wp) :: fcn_3d(nx,ny,nz)
    real(wp) :: fcn_4d(nx,ny,nz,nq)
    real(wp) :: fcn_5d(nx,ny,nz,nq,nr)
    real(wp) :: fcn_6d(nx,ny,nz,nq,nr,ns)
        
    real(wp) :: tol
    real(wp),dimension(6) :: val,tru,err,errmax
    logical  :: fail
    integer  :: i,j,k,l,m,n,idx,idy,idz,idq,idr,ids,iflag
    
    fail = .false.
    tol = 500.0_wp*d1mach(4)
    idx = 0
    idy = 0
    idz = 0
    idq = 0
    idr = 0
    ids = 0

     do i=1,nx
        x(i) = dble(i-1)/dble(nx-1)
     end do
     do j=1,ny
        y(j) = dble(j-1)/dble(ny-1)
     end do
     do k=1,nz
        z(k) = dble(k-1)/dble(nz-1)
     end do
     do l=1,nq
        q(l) = dble(l-1)/dble(nq-1)
     end do
     do m=1,nr
        r(m) = dble(m-1)/dble(nr-1)
     end do
     do n=1,ns
        s(n) = dble(n-1)/dble(ns-1)
     end do
     do i=1,nx
        do j=1,ny
                        fcn_2d(i,j) = f2(x(i),y(j))
           do k=1,nz
                        fcn_3d(i,j,k) = f3(x(i),y(j),z(k))
              do l=1,nq
                        fcn_4d(i,j,k,l) = f4(x(i),y(j),z(k),q(l))
                 do m=1,nr
                        fcn_5d(i,j,k,l,m) = f5(x(i),y(j),z(k),q(l),r(m))
                     do n=1,ns
                        fcn_6d(i,j,k,l,m,n) = f6(x(i),y(j),z(k),q(l),r(m),s(n))
                     end do
                 end do
              end do
           end do
        end do
     end do

    ! interpolate
    
     iflag = 0
     call db2ink(x,nx,y,ny,fcn_2d,kx,ky,tx,ty,fcn_2d,iflag)
     iflag = 0
     call db3ink(x,nx,y,ny,z,nz,fcn_3d,kx,ky,kz,tx,ty,tz,fcn_3d,iflag)
     iflag = 0
     call db4ink(x,nx,y,ny,z,nz,q,nq,fcn_4d,kx,ky,kz,kq,tx,ty,tz,tq,fcn_4d,iflag)
     iflag = 0
     call db5ink(x,nx,y,ny,z,nz,q,nq,r,nr,fcn_5d,kx,ky,kz,kq,kr,tx,ty,tz,tq,tr,fcn_5d,iflag)
     iflag = 0
     call db6ink(x,nx,y,ny,z,nz,q,nq,r,nr,s,ns,fcn_6d,kx,ky,kz,kq,kr,ks,tx,ty,tz,tq,tr,ts,fcn_6d,iflag)

    ! compute max error at interpolation points

     errmax = 0.0_wp
     do i=1,nx
        do j=1,ny
                        val(2)    = db2val(x(i),y(j),idx,idy,&
                                            tx,ty,nx,ny,kx,ky,fcn_2d)
                        tru(2)    = f2(x(i),y(j))
                        err(2)    = abs(tru(2)-val(2))
                        errmax(2) = max(err(2),errmax(2))
           do k=1,nz
                        val(3)    = db3val(x(i),y(j),z(k),idx,idy,idz,&
                                            tx,ty,tz,nx,ny,nz,kx,ky,kz,fcn_3d)
                        tru(3)    = f3(x(i),y(j),z(k))
                        err(3)    = abs(tru(3)-val(3))
                        errmax(3) = max(err(3),errmax(3))
              do l=1,nq
                        val(4)    = db4val(x(i),y(j),z(k),q(l),idx,idy,idz,idq,&
                                            tx,ty,tz,tq,nx,ny,nz,nq,kx,ky,kz,kq,fcn_4d)
                        tru(4)    = f4(x(i),y(j),z(k),q(l))
                        err(4)    = abs(tru(4)-val(4))
                        errmax(4) = max(err(4),errmax(4))
                do m=1,nr
                        val(5)    = db5val(x(i),y(j),z(k),q(l),r(m),idx,idy,idz,idq,idr,&
                                            tx,ty,tz,tq,tr,nx,ny,nz,nq,nr,kx,ky,kz,kq,kr,fcn_5d)
                        tru(5)    = f5(x(i),y(j),z(k),q(l),r(m))
                        err(5)    = abs(tru(5)-val(5))
                        errmax(5) = max(err(5),errmax(5))
                    do n=1,ns
                        val(6)    = db6val(x(i),y(j),z(k),q(l),r(m),s(n),idx,idy,idz,idq,idr,ids,&
                                            tx,ty,tz,tq,tr,ts,nx,ny,nz,nq,nr,ns,kx,ky,kz,kq,kr,ks,fcn_6d)
                        tru(6)    = f6(x(i),y(j),z(k),q(l),r(m),s(n))
                        err(6)    = abs(tru(6)-val(6))
                        errmax(6) = max(err(6),errmax(6))
                    end do
                end do
              end do
           end do
        end do
     end do

    ! check max error against tolerance
    do i=2,6
        write(*,*) i,'D: max error:', errmax(i)
        if (errmax(i) >= tol) then
            write(*,*)  ' ** test failed ** '
        else
            write(*,*)  ' ** test passed ** '
        end if
        write(*,*) ''
    end do
 
    contains
      
        real(wp) function f2(x,y)
        real(wp) x,y,piov2
        piov2 = 2.0_wp * atan(1.0_wp)
        f2 = 0.5_wp * (y*exp(-x) + sin(piov2*y) )
        return
        end function f2
    
        real(wp) function f3 (x,y,z)
        real(wp) x,y,z,piov2
        piov2 = 2.0_wp*atan(1.0_wp)
        f3 = 0.5_wp*( y*exp(-x) + z*sin(piov2*y) )
        end function f3    
    
        real(wp) function f4 (x,y,z,q)
        real(wp) x,y,z,q,piov2
        piov2 = 2.0_wp*atan(1.0_wp)
        f4 = 0.5_wp*( y*exp(-x) + z*sin(piov2*y) + q )
        end function f4    
    
        real(wp) function f5 (x,y,z,q,r)
        real(wp) x,y,z,q,r,piov2
        piov2 = 2.0_wp*atan(1.0_wp)
        f5 = 0.5_wp*( y*exp(-x) + z*sin(piov2*y) + q*r )
        end function f5
      
        real(wp) function f6 (x,y,z,q,r,s)
        real(wp) x,y,z,q,r,s,piov2
        piov2 = 2.0_wp*atan(1.0_wp)
        f6 = 0.5_wp*( y*exp(-x) + z*sin(piov2*y) + q*r + 2.0_wp*s )
        end function f6
              
    end subroutine bspline_test
!*****************************************************************************************

!*****************************************************************************************
    end module bspline_module
!*****************************************************************************************