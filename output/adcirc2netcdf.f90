! This program will convert ADCIRC+SWAN ASCII Output to NETCDF
! Copyleft by Patrick C. Kerr
! University of Notre Dame
! pkerr@nd.edu

! 2012-01-12:   v1 - Original
! 2012-01-16:   v2 - Fixed Time Bug, Made CF Compliant
! 2012-01-17:   v3 - Added maxele

! g95 -o adcirc2netcdf.x -ffree-form -ffree-line-length-huge -I/usr/local/netcdf/netcdf-4.1.1/f90 adcirc2netcdf.f90 -L/usr/local/hdf5/hdf5-1.8.8/hdf5/lib  -lnetcdf -lhdf5_hl -lhdf5 -lhdf5_fortran -lz
!-----+---------+---------+---------+---------+---------+---------+
   module adcmesh
!-----+---------+---------+---------+---------+---------+---------+
      character(120) :: meshFileName ! full pathname of file
      double precision, allocatable :: xyd(:,:), bar(:,:,:)
      character(120)                :: agrid
      integer                       :: ne, np
      integer                       :: nope, neta, nvdl_max
      integer                       :: nbou, nvel, nvel_max, nodemax
      integer,          allocatable :: nm(:,:), nvdll(:), nbdv(:,:), nsequencer(:)
      integer,          allocatable :: nvell(:), ibtype(:),  nbvv(:,:), ibconn(:,:)

   contains

   !-----+---------+---------+---------+---------+---------+---------+
   !  READ14_ALLOC
   !-----+---------+---------+---------+---------+---------+---------+
   subroutine read14_alloc ()
      implicit none
      integer :: i, j, k
      integer, parameter :: iunit = 14
!
      nvdl_max = 0
      nvel_max = 0
      nodemax = 0
      read(iunit,*)
      read(iunit,*) ne, np
      do k = 1, np
         read(iunit,*) i
         nodemax = max(i,nodemax)
      enddo
      do k = 1, ne
         read(iunit,*)
      enddo
      write(6,*) '  |'
      read(iunit,*) nope
      read(iunit,*)
      do k = 1, nope
         read(iunit,*) i
         if( i >= nvdl_max ) nvdl_max = i
         do j = 1, i
            read(iunit,*)
         enddo
      enddo
      read(iunit,*) nbou
      read(iunit,*)
      do k = 1, nbou
         read(iunit,*) i
         if( i >= nvel_max ) nvel_max = i
         do j = 1, i
            read(iunit,*)
         enddo
      enddo
      rewind(iunit)
   !-----+---------+---------+---------+---------+---------+---------+
   end subroutine read14_alloc
   !-----+---------+---------+---------+---------+---------+---------+

   !-----+---------+---------+---------+---------+---------+---------+
   ! READ14
   !-----+---------+---------+---------+---------+---------+---------+
   subroutine read14 ()
      implicit none

      integer :: i, j, k, jn, je, nhy
      integer, parameter :: iunit = 14

      if (trim(meshFileName).eq."null") then
         write(6,*)    '*************************************************'
         WRITE(6,'(A)',ADVANCE='NO') "Enter name of the fort.14 file: "
         read(5,'(A)') meshFileName
      endif
      call openFileForRead(iunit,trim(meshFileName))
      call read14_alloc ()

      allocate( xyd(3,np) )
      allocate( nm(3,ne) )
      allocate( nvdll(nope)  )
      allocate( nbdv(nope,nvdl_max) )
      allocate( nvell(nbou), ibtype(nbou)  )
      allocate( nbvv(nbou,nvel_max), ibconn(nbou,nvel_max), bar(3,nbou,nvel_max) )
      allocate( nsequencer(nodemax) )

      nsequencer(:) = 0
      bar(:,:,:) = 0.0d0
      ibconn(:,:) = 0
      agrid = ' '
      read(iunit,*)
      read(iunit,*) ne, np
      do k = 1, np
         read(iunit,*) jn, (xyd(j,k), j=1,3)
         nsequencer(jn) = k
      enddo
      write(6,*) '  + '
      do k = 1, ne
         read(iunit,*) je, nhy, ( nm(j,k), j = 1, 3 )
         do j = 1, 3
            if( nm(j,k) <= 0 ) write(6,*) k,j, nm(j,k)
            nm(j,k) = nsequencer(nm(j,k))
         enddo
      enddo
      read(iunit,*) nope
      read(iunit,*) neta
      do k = 1, nope
         read(iunit,*) nvdll(k)
         do j = 1, nvdll(k)
            read(iunit,*) nbdv(k,j)
            nbdv(k,j) = nsequencer(nbdv(k,j))
         enddo
      enddo
      read(iunit,*) nbou
      read(iunit,*) nvel
      do k = 1, nbou
         read(iunit,*) nvell(k), ibtype(k)
         select case(ibtype(k))
            case(0,1,2,10,11,12,20,21,22,30,52)
               do j = 1, nvell(k)
                  read(iunit,*) nbvv(k,j)
                  nbvv(k,j) = nsequencer(nbvv(k,j))
               enddo
            case(3, 13, 23)
               do j = 1, nvell(k)
                  read(iunit,*) nbvv(k,j), (bar(i,k,j), i=1,2)
                  nbvv(k,j) = nsequencer(nbvv(k,j))
               enddo
            case(4, 24)
               do j = 1, nvell(k)
                  read(iunit,*) nbvv(k,j), ibconn(k,j), (bar(i,k,j), i=1,3)
                  nbvv(k,j) = nsequencer(nbvv(k,j))
                  ibconn(k,j) = nsequencer(ibconn(k,j))
               enddo
            case default
               write(6,*) 'ERROR: IBTYPE ',ibtype(k),' is not allowed.'
               stop
         end select
      enddo
      close(14)
      write(6,*) 'INFO: Finished reading mesh file.'
!     deallocate( nsequencer )
   !-----+---------+---------+---------+---------+---------+---------+
   end subroutine read14
   !-----+---------+---------+---------+---------+---------+---------+
!-----+---------+---------+---------+---------+---------+---------+
   end module adcmesh
!-----+---------+---------+---------+---------+---------+---------+


!-----+---------+---------+---------+---------+---------+---------+
!
!   P R O G R A M    A D C I R C  2  N E T C D F
!
!-----+---------+---------+---------+---------+---------+---------+
   program adcirc2netcdf


      USE netcdf
      USE adcmesh
      IMPLICIT NONE
      CHARACTER(120)                :: InputFile, OutputFile, AttFile
      character(120)                :: datenum
      character(120),   allocatable :: att(:,:)
      character(1000)               :: Line
      character(1)                  :: JunkC, Tadj
      DOUBLE PRECISION              :: DefaultValue, FillValue=-99999.0d0
      double precision              :: temp1, temp2, SnapR, Interval, time(1)
      DOUBLE PRECISION, ALLOCATABLE :: Global1(:), Global2(:), Global3(:)
      integer                       :: yy, mo, dd, hh, mi
      integer                       :: natt, i, j, k, N, SS, NumNodes, NumSnaps
      integer                       :: NumNodesNonDefault, SnapI
      integer                       :: unitnumber, nCol
      integer, allocatable          :: iopt(:)         ! files to convert
      integer                       :: nopt         ! actual number of files to convert
      integer                       :: menuOpt   ! user's selection
      integer                       :: argcount  ! number of command line arguments
      integer                       :: iargc     ! function to return command line arguments
      character(2048)               :: cmdlineopt ! command line option
      character(2048)               :: cmdlinearg ! content of command line argument
      logical                       :: useNetCDF4 ! .true. if user wants netcdf classic model
                                                  ! files formatted in hdf5 format
      logical                       :: meshonly   ! .true. if user just wants to conver the mesh
      logical                       :: withXDMF ! .true. if user wants to generate XDMF xml with netcdf4 file
      logical                       :: onlyXDMF ! .true. if user has netcdf4 file already and wants to generate XDMF xml
      integer                       :: ncFileType
      integer                       :: NC_ID
      INTEGER                       :: NC_DimID(2)
      INTEGER                       :: NC_Count(2)
      INTEGER                       :: NC_Start(2)

      integer                       :: NC_DimID_time
      integer                       :: NC_DimID_node
      integer                       :: NC_DimID_nele
      integer                       :: NC_DimID_nvertex
      integer                       :: NC_DimID_nope
      integer                       :: NC_DimID_max_nvdll
      integer                       :: NC_DimID_nbou
      integer                       :: NC_DimID_neta
      integer                       :: NC_DimID_nvel
      integer                       :: NC_DimID_max_nvell
      integer                       :: NC_DimID_single

      integer                       :: NC_VarID_Mesh
      integer                       :: NC_VarID_time
      integer                       :: NC_VarID_x
      integer                       :: NC_VarID_y
      integer                       :: NC_VarID_element
      integer                       :: NC_VarID_neta
      integer                       :: NC_VarID_nvdll
      integer                       :: NC_VarID_max_nvdll
      integer                       :: NC_VarID_ibtypee
      integer                       :: NC_VarID_nbdv
      integer                       :: NC_VarID_nvel
      integer                       :: NC_VarID_nvell
      integer                       :: NC_VarID_max_nvell
      integer                       :: NC_VarID_ibtype
      integer                       :: NC_VarID_nbvv
      integer                       :: NC_VarID_depth
      integer                       :: NC_VarID_zeta
      integer                       :: NC_VarID_u_vel
      integer                       :: NC_VarID_v_vel
      integer                       :: NC_VarID_maxele
      integer                       :: NC_VarID_p
      integer                       :: NC_VarID_windx
      integer                       :: NC_VarID_windy
      integer                       :: NC_VarID_dir
      integer                       :: NC_VarID_hs
      integer                       :: NC_VarID_tmm10
      integer                       :: NC_VarID_tps

      ! initializations
      meshFileName = "null"
      attFile = "null"
      menuOpt = 0
      useNetCDF4 = .false.
      meshonly = .false.
      withXDMF = .false.
      onlyXDMF = .false.

      ! jgf: Process command line options; can be used along with menu choices;
      ! if command line options provide all needed input, menu will not
      ! be presented to user; programs with command line options are
      ! slightly easier to automate than menu-based programs
      argcount = iargc() ! count up command line options
      if (argcount.gt.0) then
         i=0
         do while (i.lt.argcount)
            i = i + 1
            call getarg(i, cmdlineopt)
            select case(trim(cmdlineopt))
               case("--netcdf4")
                  useNetCDF4 = .true.
                  write(6,*) "INFO: Processing ",trim(cmdlineopt),"."
               case("--meshonly")
                  meshonly = .true.
                  menuOpt = 14
                  write(6,*) "INFO: Processing ",trim(cmdlineopt),"."
               case("--meshfile")
                  i = i + 1
                  call getarg(i, cmdlinearg)
                  write(6,*) "INFO: Processing ",trim(cmdlineopt)," ",trim(cmdlinearg),"."
                  meshFileName = trim(cmdlinearg)
               case("--attfile")
                  i = i + 1
                  call getarg(i, cmdlinearg)
                  write(6,*) "INFO: Processing ",trim(cmdlineopt)," ",trim(cmdlinearg),"."
                  attFile = trim(cmdlinearg)
               case("--datafile")
                  i = i + 1
                  call getarg(i, cmdlinearg)
                  write(6,*) "INFO: Processing ",trim(cmdlineopt)," ",trim(cmdlinearg),"."
                  select case(trim(cmdlinearg))
                     case("fort.63")
                        menuOpt = 1
                     case("fort.64")
                        menuOpt = 2
                     case("fort.73")
                        menuOpt = 3
                     case("fort.74")
                        menuOpt = 4
                     case("maxele.63")
                        menuOpt = 5
                     case("swan_DIR.63")
                        menuOpt = 6
                     case("swan_HS.63")
                        menuOpt = 7
                     case("swan_TMM10.63")
                        menuOpt = 8
                     case("swan_TPS.63")
                        menuOpt = 9
                     case("adcirc")
                        menuOpt = 10
                     case("swan")
                        menuOpt = 11
                     case("adcirc_swan")
                        menuOpt = 12
                     case default
                        write(6,*) "WARNING: Command line argument '",TRIM(cmdlinearg),"' was not recognized."
                  end select
               case("--with-xdmf")
                  withXDMF = .true.
                  write(6,*) "INFO: Processing ",trim(cmdlineopt),"."
               case("--xdmf-only")
                  onlyXDMF = .true.
                  write(6,*) "INFO: Processing ",trim(cmdlineopt),"."
               case default
                  write(6,*) "WARNING: Command line option '",TRIM(cmdlineopt),"' was not recognized."
            end select
         end do
      end if

      ! XDMF xml only useful with HDF5 formatted data files
      if ((withXDMF.eqv..true.).and.(useNetCDF4.eqv..false.)) then
         write(6,*) "ERROR: The option '--with-xdmf' requires the option '--netcdf4'."
         stop
      endif

      ! present file conversion menu to user if the file was not specified on the
      ! command line
  997 continue
      if (menuOpt.eq.0) then
         write(6,*)    '*************************************************'
         write(6,*)    '    Select ADCIRC Output to Convert to NETCDF    '
         write(6,*)    '*************************************************'
         write(6,*)    '  1. fort.63       '
         write(6,*)    '  2. fort.64       '
         write(6,*)    '  3. fort.73       '
         write(6,*)    '  4. fort.74       '
         write(6,*)    '  5. maxele.63     '
         write(6,*)    '  6. swan_DIR.63   '
         write(6,*)    '  7. swan_HS.63    '
         write(6,*)    '  8. swan_TMM10.63 '
         write(6,*)    '  9. swan_TPS.63   '
         write(6,*)    '  10. Options 1-5   '
         write(6,*)    '  11. Options 6-9  '
         write(6,*)    '  12. Options 1-9  '
         write(6,*)    '*************************************************'
         write(6,'(A)',ADVANCE="NO")    ' Select Option: '
         read(5,'(i10)',ERR=997) menuOpt
      endif
      !
      ! jgf: make a list of files to convert, based on use menu selection;
      ! set names of files that will contain more than one type of data
      select case(menuOpt)
         case(1,2,3,4,5,6,7,8,9,14)
            nopt = 1       ! only need to convert 1 file
            allocate(iopt(nopt))
            iopt(1) = menuOpt ! file to convert has been selected from the menu
         case(10)
            nopt = 5
            allocate(iopt(nopt))
            iopt = (/ 1, 2, 3, 4, 5 /)
            Outputfile = 'adcirc.nc'
         case(11)
            nopt = 4
            allocate(iopt(nopt))
            iopt = (/ 6, 7, 8, 9 /)
            Outputfile = 'swan.nc'
         case(12)
            nopt = 9
            allocate(iopt(nopt))
            iopt = (/ 1, 2, 3, 4, 5, 6, 7, 8, 9 /)
            Outputfile = 'adcirc_swan.nc'
         case default
            write(6,*) 'ERROR: Your selection was invalid. Please try again.'
            goto 997
      end select

      ! now set NETCDF file name for files containing only one type of data
      select case(menuOpt)
         case(1) !63
            Outputfile = 'fort.63.nc'
         case(2) !64
            Outputfile = 'fort.64.nc'
         case(3) !73
            Outputfile = 'fort.73.nc'
         case(4) !74
            Outputfile = 'fort.74.nc'
         case(5) !MAXELE
            Outputfile = 'maxele.63.nc'
         case(6) !DIR
            Outputfile = 'swan_DIR.63.nc'
         case(7) !HS
            Outputfile = 'swan_HS.63.nc'
         case(8) !TMM10
            Outputfile = 'swan_TMM10.63.nc'
         case(9) !TPS
            Outputfile = 'swan_TPS.63.nc'
         case(14) !TPS
            Outputfile = 'fort.14.nc'
         case default
            ! 10, 11, and 12 were assigned previously
      end select

      ! if the (netcdf4) file already exists, and we just want to generate
      ! XDMF xml for it,
      if (onlyXDMF.eqv..true.) then
         call generateXDMF(OutputFile)
         stop
      endif

      ! Load fort.14
      call read14()

      ! Load Global Attributes
      write(6,*)    '*************************************************'
      if (trim(attFile).eq."null") then
         WRITE(6,'(A)',ADVANCE='NO') "Enter name of attribute file: "
         READ(5,'(A)') AttFile
      endif
      call openFileForRead(100,AttFile)
      read(100,*) natt
      allocate(att(1:2,1:natt))
      read(100,'(A)') datenum !seconds since 2008-07-31 12:00:00 +00:00
      do i = 1,natt
        read(100,*) att(1,i), att(2,i)
      enddo
      close(100)

      ! create netcdf file
      ncFileType = NF90_CLOBBER ! netcdf3 format, netcdf classic model
      if (useNetCDF4.eqv..true.) then
         ncFileType = ior(NF90_HDF5,NF90_CLASSIC_MODEL) ! netcdf4 (i.e., hdf5) format, netcdf classic model
      endif
      CALL Check(NF90_CREATE(TRIM(OutputFile),ncFileType,NC_ID))

      ! create time dimension and create global attributes
      CALL Check(NF90_DEF_DIM(NC_ID,'time',NF90_UNLIMITED,NC_DimID_time))
      CALL Check(NF90_DEF_VAR(NC_ID,'time',NF90_DOUBLE,NC_DimID_time,NC_VarID_time))
      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_time,'units',datenum))
      do i = 1,natt
        CALL Check(NF90_PUT_ATT(NC_ID,NF90_GLOBAL,att(1,i),att(2,i)))
      enddo

      ! create mesh variables and associated attributes
      CALL Check(NF90_DEF_DIM(NC_ID,'node',np,NC_DimID_node))
      CALL Check(NF90_DEF_DIM(NC_ID,'nele',ne,NC_DimID_nele))
      CALL Check(NF90_DEF_DIM(NC_ID,'nvertex',3,NC_DimID_nvertex))
      CALL Check(NF90_DEF_DIM(NC_ID,'single',1,NC_DimID_single))
      if (nope.ne.0) CALL Check(NF90_DEF_DIM(NC_ID,'nope',nope,NC_DimID_nope))
      if (nvdl_max.ne.0) CALL Check(NF90_DEF_DIM(NC_ID,'max_nvdll',nvdl_max,NC_DimID_max_nvdll))
      if (neta.ne.0) CALL Check(NF90_DEF_DIM(NC_ID,'neta',neta,NC_DimID_neta))
      if (nbou.ne.0) CALL Check(NF90_DEF_DIM(NC_ID,'nbou',nbou,NC_DimID_nbou))
      if (nvel.ne.0) CALL Check(NF90_DEF_DIM(NC_ID,'nvel',nvel,NC_DimID_nvel))
      if (nvel_max.ne.0) CALL Check(NF90_DEF_DIM(NC_ID,'max_nvell',nvel_max,NC_DimID_max_nvell))

      ! ibtypee, ibconn, bars are ignored

      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_time,'long_name','model time'))
      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_time,'standard_name','time'))

      CALL Check(NF90_DEF_VAR(NC_ID,'x',NF90_DOUBLE,NC_DimID_node,NC_VarID_x))
      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_x,'long_name','longitude'))
      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_x,'standard_name','longitude'))
      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_x,'units','degrees_east'))
      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_x,'positive','east'))

      CALL Check(NF90_DEF_VAR(NC_ID,'y',NF90_DOUBLE,NC_DimID_node,NC_VarID_y))
      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_y,'long_name','latitude'))
      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_y,'standard_name','latitude'))
      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_y,'units','degrees_north'))
      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_y,'positive','north'))

      CALL Check(NF90_DEF_VAR(NC_ID,'element',NF90_int,(/NC_DimID_nvertex, NC_DimID_nele /),NC_VarID_element))
      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_element,'long_name','element'))
      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_element,'standard_name','face_node_connectivity'))
      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_element,'units','nondimensional'))
      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_element,'start_index',1))

      if (nope.ne.0) then
         CALL Check(NF90_DEF_VAR(NC_ID,'nvdll',NF90_DOUBLE,NC_DimID_nope,NC_VarID_nvdll))
         CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_nvdll,'long_name','total number of nodes in each elevation specified & boundary segment'))
         CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_nvdll,'units','nondimensional'))

         CALL Check(NF90_DEF_VAR(NC_ID,'nbdv',NF90_DOUBLE,(/ NC_DimID_nope, NC_DimID_max_nvdll /),NC_VarID_nbdv))
         CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_nbdv,'long_name','node numbers on each elevation specified boundary & segment'))
         CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_nbdv,'units','nondimensional'))
      endif

      if (nbou.ne.0) then
         CALL Check(NF90_DEF_VAR(NC_ID,'nvell',NF90_DOUBLE,NC_DimID_nbou,NC_VarID_nvell))
         CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_nvell,'long_name','number of nodes in each normal flow specified boundary segment'))
         CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_nvell,'units','nondimensional'))

         CALL Check(NF90_DEF_VAR(NC_ID,'ibtype',NF90_DOUBLE,NC_DimID_nbou,NC_VarID_ibtype))
         CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_ibtype,'long_name','type of normal flow (discharge) boundary'))
         CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_ibtype,'units','nondimensional'))

         CALL Check(NF90_DEF_VAR(NC_ID,'nbvv',NF90_DOUBLE,(/ NC_DimID_nbou, NC_DimID_max_nvell /),NC_VarID_nbvv))
         CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_nbvv,'long_name','node numbers on normal flow boundary segment'))
         CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_nbvv,'units','nondimensional'))
      endif

      CALL Check(NF90_DEF_VAR(NC_ID,'depth',NF90_DOUBLE,NC_DimID_node,NC_VarID_depth))
      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_depth,'long_name','distance from geoid'))
      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_depth,'standard_name','depth_below_geoid'))
      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_depth,'coordinates','time y x'))
      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_depth,'location','node'))
      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_depth,'mesh','adcirc_mesh'))
      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_depth,'units','m'))
!      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_depth,'positive','down')) !DO NOT USE?

      CALL Check(NF90_DEF_VAR(NC_ID,'adcirc_mesh',NF90_INT,NC_DimID_single,NC_VarID_mesh))
      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_mesh,'long_name','mesh topology'))
      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_mesh,'standard_name','mesh_topology'))
      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_mesh,'dimension',2))
      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_mesh,'node_coordinates','x y'))
      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_mesh,'face_node_connectivity','element'))
      if (useNetCDF4.eqv..true.) then
         if (nope.ne.0) then
            call check(nf90_def_var_deflate(NC_ID, NC_VarID_nvdll, 0, 1, 2))
            call check(nf90_def_var_deflate(NC_ID, NC_VarID_nbdv, 0, 1, 2))
         endif
         if (nbou.ne.0) then
            call check(nf90_def_var_deflate(NC_ID, NC_VarID_nvell, 0, 1, 2))
            call check(nf90_def_var_deflate(NC_ID, NC_VarID_ibtype, 0, 1, 2))
            call check(nf90_def_var_deflate(NC_ID, NC_VarID_nbvv, 0, 1, 2))
         endif
         call check(nf90_def_var_deflate(NC_ID, NC_VarID_x, 0, 1, 2))
         call check(nf90_def_var_deflate(NC_ID, NC_VarID_y, 0, 1, 2))
         call check(nf90_def_var_deflate(NC_ID, NC_VarID_element, 0, 1, 2))
         call check(nf90_def_var_deflate(NC_ID, NC_VarID_depth, 0, 1, 2))
         call check(nf90_def_var_deflate(NC_ID, NC_VarID_depth, 0, 1, 2))
         call check(nf90_def_var_deflate(NC_ID, NC_VarID_Mesh, 0, 1, 2))
      endif

      ! create adcirc output variables and associated attributes
      NC_DimID = (/ NC_DimID_node, NC_DimID_Time /)
      do i=1,nopt
         select case(iopt(i))
         case(1) !63
            CALL Check(NF90_DEF_VAR(NC_ID,'zeta',NF90_DOUBLE,NC_DimID,NC_VarID_zeta))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_zeta,'_FillValue',FillValue))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_zeta,'long_name','water surface elevation above geoid'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_zeta,'standard_name','sea_surface_height_above_geoid'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_zeta,'coordinates','time y x'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_zeta,'location','node'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_zeta,'mesh','adcirc_mesh'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_zeta,'units','m'))
            if (useNetCDF4.eqv..true.) call check(nf90_def_var_deflate(NC_ID, NC_VarID_zeta, 1, 1, 2))
            !          CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_zeta,'positive','up')) 'DO NOT USE'
         case(2) !64
            CALL Check(NF90_DEF_VAR(NC_ID,'u-vel',NF90_DOUBLE,NC_DimID,NC_VarID_u_vel))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_u_vel,'_FillValue',FillValue))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_u_vel,'long_name','water column vertically averaged east/west velocity'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_u_vel,'standard_name','barotropic_eastward_sea_water_velocity'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_u_vel,'coordinates','time y x'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_u_vel,'location','node'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_u_Vel,'mesh','adcirc_mesh'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_u_vel,'units','m s-1'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_u_vel,'positive','east'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_u_vel,'dry_Value',-99999.0d0))
            if (useNetCDF4.eqv..true.) call check(nf90_def_var_deflate(NC_ID, NC_VarID_u_vel, 1, 1, 2))
            CALL Check(NF90_DEF_VAR(NC_ID,'v-vel',NF90_DOUBLE,NC_DimID,NC_VarID_v_vel))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_v_vel,'_FillValue',FillValue))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_v_vel,'long_name','water column vertically averaged north/south velocity'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_v_vel,'standard_name','barotropic_northward_sea_water_velocity'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_v_vel,'coordinates','time y x'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_v_vel,'location','node'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_v_vel,'mesh','adcirc_mesh'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_v_vel,'units','m s-1'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_v_vel,'positive','north'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_v_vel,'dry_Value',-99999.0d0))
            if (useNetCDF4.eqv..true.) call check(nf90_def_var_deflate(NC_ID, NC_VarID_v_vel, 1, 1, 2))
         case(3) !73
            CALL Check(NF90_DEF_VAR(NC_ID,'pressure',NF90_DOUBLE,NC_DimID,NC_VarID_p))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_p,'_FillValue',FillValue))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_p,'long_name','air pressure at sea level'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_p,'standard_name','air_pressure'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_p,'coordinates','time y x'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_p,'location','node'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_p,'mesh','adcirc_mesh'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_p,'units','meters of water'))
            if (useNetCDF4.eqv..true.) call check(nf90_def_var_deflate(NC_ID, NC_VarID_p, 1, 1, 2))
!          CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_p,'positive','up')) 'DO NOT USE'
         case(4) !74
            CALL Check(NF90_DEF_VAR(NC_ID,'windx',NF90_DOUBLE,NC_DimID,NC_VarID_windx))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_windx,'_FillValue',FillValue))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_windx,'long_name','e/w wind velocity'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_windx,'standard_name','eastward_wind'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_windx,'coordinates','time y x'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_windx,'location','node'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_windx,'mesh','adcirc_mesh'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_windx,'units','m s-1'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_windx,'positive','east'))
            if (useNetCDF4.eqv..true.) call check(nf90_def_var_deflate(NC_ID, NC_VarID_windx, 1, 1, 2))
            CALL Check(NF90_DEF_VAR(NC_ID,'windy',NF90_DOUBLE,NC_DimID,NC_VarID_windy))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_windy,'_FillValue',FillValue))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_windy,'long_name','n/s wind velocity'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_windy,'standard_name','northward_wind'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_windy,'coordinates','time y x'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_windy,'location','node'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_windy,'mesh','adcirc_mesh'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_windy,'units','m s-1'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_windy,'positive','north'))
            if (useNetCDF4.eqv..true.) call check(nf90_def_var_deflate(NC_ID, NC_VarID_windy, 1, 1, 2))
         case(5) !MAXELE
            CALL Check(NF90_DEF_VAR(NC_ID,'maxele',NF90_DOUBLE,NC_DimID,NC_VarID_maxele))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_maxele,'_FillValue',FillValue))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_maxele,'long_name','maximum water surface elevation above geoid'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_maxele,'standard_name','maximum_sea_surface_height_above_geoid'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_maxele,'coordinates','time y x'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_maxele,'location','node'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_maxele,'mesh','adcirc_mesh'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_maxele,'units','m'))
            if (useNetCDF4.eqv..true.) call check(nf90_def_var_deflate(NC_ID, NC_VarID_maxele, 1, 1, 2))
             !          CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_zeta,'positive','up')) 'DO NOT USE'
         case(6) !DIR
            CALL Check(NF90_DEF_VAR(NC_ID,'dir',NF90_DOUBLE,NC_DimID,NC_VarID_dir))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_dir,'_FillValue',FillValue))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_dir,'long_name','wave direction'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_dir,'standard_name','wave_direction'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_dir,'coordinates','time y x'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_dir,'location','node'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_dir,'mesh','adcirc_mesh'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_dir,'units','degrees_CW_from_East'))
            if (useNetCDF4.eqv..true.) call check(nf90_def_var_deflate(NC_ID, NC_VarID_dir, 1, 1, 2))
         case(7) !HS
            CALL Check(NF90_DEF_VAR(NC_ID,'hs',NF90_DOUBLE,NC_DimID,NC_VarID_hs))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_hs,'_FillValue',FillValue))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_hs,'long_name','significant wave height'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_hs,'standard_name','significant_wave_height'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_hs,'coordinates','time y x'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_hs,'location','node'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_hs,'mesh','adcirc_mesh'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_hs,'units','m'))
            if (useNetCDF4.eqv..true.) call check(nf90_def_var_deflate(NC_ID, NC_VarID_hs, 1, 1, 2))
         case(8) !TMM10
            CALL Check(NF90_DEF_VAR(NC_ID,'tmm10',NF90_DOUBLE,NC_DimID,NC_VarID_tmm10))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_tmm10,'_FillValue',FillValue))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_tmm10,'long_name','Mean Period'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_tmm10,'standard_name','mean_period'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_tmm10,'coordinates','time y x'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_tmm10,'location','node'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_tmm10,'mesh','adcirc_mesh'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_tmm10,'units','s'))
            if (useNetCDF4.eqv..true.) call check(nf90_def_var_deflate(NC_ID, NC_VarID_tmm10, 1, 1, 2))
         case(9) !TPS
            CALL Check(NF90_DEF_VAR(NC_ID,'tps',NF90_DOUBLE,NC_DimID,NC_VarID_tps))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_tps,'_FillValue',FillValue))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_tps,'long_name','Peak Period'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_tps,'standard_name','peak_period'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_tps,'coordinates','time y x'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_tps,'location','node'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_tps,'mesh','adcirc_mesh'))
            CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_tps,'units','s'))
            if (useNetCDF4.eqv..true.) call check(nf90_def_var_deflate(NC_ID, NC_VarID_tps, 1, 1, 2))
         case(14) ! just the mesh
            cycle
         end select
      enddo

      ! end variable and attributes definitions
      CALL Check(NF90_ENDDEF(NC_ID))

      ! place mesh-related data into the file
      NC_Count = (/ np, 1 /)
      NC_Start = (/ 1, 1 /)
      CALL Check(NF90_PUT_VAR(NC_ID,NC_VarID_x,xyd(1,1:np),NC_Start,NC_Count))
      CALL Check(NF90_PUT_VAR(NC_ID,NC_VarID_y,xyd(2,1:np),NC_Start,NC_Count))
      CALL Check(NF90_PUT_VAR(NC_ID,NC_VarID_depth,xyd(3,1:np),NC_Start,NC_Count))
      NC_Count = (/ 3, ne /)
      CALL Check(NF90_PUT_VAR(NC_ID,NC_VarID_element,nm,NC_Start,NC_Count))
      if (nope.ne.0) then
         NC_Count = (/ nope, 1 /)
         CALL Check(NF90_PUT_VAR(NC_ID,NC_VarID_nvdll,nvdll,NC_Start,NC_Count))
         NC_Count = (/ nope, nvdl_max /)
         CALL Check(NF90_PUT_VAR(NC_ID,NC_VarID_nbdv,nbdv,NC_Start,NC_Count))
      endif
      if (nbou.ne.0) then
         NC_Count = (/ nbou, 1 /)
         CALL Check(NF90_PUT_VAR(NC_ID,NC_VarID_nvell,nvell,NC_Start,NC_Count))
         NC_Count = (/ nbou, 1 /)
         CALL Check(NF90_PUT_VAR(NC_ID,NC_VarID_ibtype,ibtype,NC_Start,NC_Count))
         NC_Count = (/ nbou, nvel_max /)
         CALL Check(NF90_PUT_VAR(NC_ID,NC_VarID_nbvv,nbvv,NC_Start,NC_Count))
      end if

      write(6,*)    '*************************************************'
      write(6,*) 'Grid has been written to NETCDF'
      write(6,*)    '*************************************************'

      if (meshonly.eqv..true.) then
         CALL Check(NF90_CLOSE(NC_ID))
         stop
      endif

      ! now moving on to the actual adcirc output data; first, set name
      ! of ascii output file to read, based on menu choice
      do i=1,nopt
         select case(iopt(i))
            case(1) !63
               Inputfile = 'fort.63'
            case(2) !64
               Inputfile = 'fort.64'
            case(3) !73
               Inputfile = 'fort.73'
            case(4) !74
               Inputfile = 'fort.74'
            case(5) !MAXELE
               Inputfile = 'maxele.63'
            case(6) !DIR
               Inputfile = 'swan_DIR.63'
            case(7) !HS
               Inputfile = 'swan_HS.63'
            case(8) !TMM10
               Inputfile = 'swan_TMM10.63'
            case(9) !TPS
               Inputfile = 'swan_TPS.63'
         end select
         UnitNumber = 100+iopt(i)
         call openFileForRead(UnitNumber, trim(InputFile))
         READ(UnitNumber,'(A)') JunkC
         ! jgf: Can't rely on the NumSnaps value; in general, it will not
         ! actually reflect the number of datasets in the file.
         READ(UnitNumber,*) NumSnaps, NumNodes, Interval, Interval, nCol
         if (np.ne.NumNodes) then
           write(6,*) 'ERROR: The output file contains ',NumNodes,        &
             ' nodes, but the mesh file contains ',np,' nodes.'
           write(6,*) 'ERROR: The output file does not correspond to the mesh file.'
           close(UnitNumber)
           stop
         endif
         ALLOCATE(Global1(1:NumNodes))
         ALLOCATE(Global2(1:NumNodes))
         ALLOCATE(Global3(1:1))
         SS=1 ! jgf: initialize the dataset counter
         DO   ! jgf: loop until we run out of data
            read(UnitNumber,'(A)',END=123,ERR=123) Line
            read(Line,*) SnapR, SnapI
            read(Line,*,ERR=907,END=907) SnapR, SnapI, NumNodesNonDefault, DefaultValue
            goto 908  ! jgf: this file is sparse ascii
   907      NumNodesNonDefault = NumNodes
            DefaultValue = -99999.0d0
   908      DO N=1,NumNodes
               Global1(N)=DefaultValue
               Global2(N)=DefaultValue
            ENDDO
            do N=1,NumNodesNonDefault
              select case(iopt(i))
                case(1,3,5,6,7,8,9) ! scalar data
                  READ(UnitNumber,*) j,Temp1
                  Global1(j) = Temp1
                case(2,4)           ! 2D vector data
                  READ(UnitNumber,*) j,Temp1,Temp2
                  Global1(j) = Temp1
                  Global2(j) = Temp2
              end select
            enddo
            Global3(1) = SnapR
            CALL Check(NF90_PUT_VAR(NC_ID,NC_VarID_time,Global3,(/SS/),(/1/)))
            NC_Count = (/ NumNodes, 1 /)
            NC_Start = (/ 1, SS /)
            ! write the dataset to the netcdf file
            select case(iopt(i))
              case(1) !63
                CALL Check(NF90_PUT_VAR(NC_ID,NC_VarID_zeta,Global1,NC_Start,NC_Count))
              case(2) !64
                CALL Check(NF90_PUT_VAR(NC_ID,NC_VarID_u_vel,Global1,NC_Start,NC_Count))
                CALL Check(NF90_PUT_VAR(NC_ID,NC_VarID_v_vel,Global1,NC_Start,NC_Count))
              case(3) !73
                CALL Check(NF90_PUT_VAR(NC_ID,NC_VarID_P,Global1,NC_Start,NC_Count))
              case(4) !74
                CALL Check(NF90_PUT_VAR(NC_ID,NC_VarID_windx,Global1,NC_Start,NC_Count))
                CALL Check(NF90_PUT_VAR(NC_ID,NC_VarID_windy,Global1,NC_Start,NC_Count))
              case(5) !MAXELE
                CALL Check(NF90_PUT_VAR(NC_ID,NC_VarID_maxele,Global1,NC_Start,NC_Count))
              case(6) !DIR
                CALL Check(NF90_PUT_VAR(NC_ID,NC_VarID_dir,Global1,NC_Start,NC_Count))
              case(7) !HS
                CALL Check(NF90_PUT_VAR(NC_ID,NC_VarID_hs,Global1,NC_Start,NC_Count))
              case(8) !TMM10
                CALL Check(NF90_PUT_VAR(NC_ID,NC_VarID_tmm10,Global1,NC_Start,NC_Count))
              case(9) !TPS
                CALL Check(NF90_PUT_VAR(NC_ID,NC_VarID_tps,Global1,NC_Start,NC_Count))
            end select
            SS = SS + 1 ! jgf: Increment the dataset counter
         ENDDO

   123   CONTINUE  ! jgf: When we've run out of datasets in the current file,
                   ! we jump to here.
         CLOSE(UnitNumber)
         DEALLOCATE(Global1,Global2,Global3)
      END DO

      CALL Check(NF90_CLOSE(NC_ID))

      write(6,*)    '*************************************************'
      write(6,*) 'INFO: adcirc2netcdf finished.'
!----------------------------------------------------------------------
   end program adcirc2netcdf
!----------------------------------------------------------------------


!-----------------------------------------------------------------------
!     S U B R O U T I N E    G E N E R A T E   X D M F
!-----------------------------------------------------------------------
!     jgf: Added subroutine for generating XDMF xml for an
!     existing netcdf4 file.
!-----------------------------------------------------------------------
   SUBROUTINE generateXDMF(fn)
      use netcdf
      implicit none
      character(120), intent(in) :: fn  ! name of netcdf4 file to generate xml for

      character(120) :: xmf ! name of XDMF xml file
C
      call check(nf90_open(trim(fn),NF_NOWRITE, nc_id))
      xmf = trim(fn)//".xmf"
      open(10,file=xmf,status='replace')
      write(10,'(A)') '<?xml version="1.0" ?>'
      write(10,'(A)') '<!DOCTYPE Xdmf SYSTEM "Xdmf.dtd" []>'
      write(10,'(A)') '<Xdmf Version="2.0">'
      write(10,'(A)') '   <Domain>'


         write(xl,'(A)') '      <Grid Name="'//adjustl(trim(AGRID))//
     &      '" GridType="Uniform">'
         write(xl,'(A)') '         <Topology Name="ADCIRCMesh"'
         write(xl,'(A)') '                   TopologyType="Triangle"'
         write(xl,'(A)') '                   NodesPerElement="3"'
         write(xl,'(A,I12,A)') '                   NumberOfElements="',
     &      myMesh%num_elems,'"'
         write(xl,'(A)') '                   BaseOffset="1">'
         write(xl,'(A,I12,A)') '            <DataItem Dimensions="',
     &      myMesh%num_elems,'  3"'
         write(xl,'(A)') '                      DataType="Int"'
         write(xl,'(A)') '                      Format="HDF">'
     &      //myFile%FILENAME//':/element'
         write(xl,'(A)') '            </DataItem>'
         write(xl,'(A)') '         </Topology>'
         write(xl,'(A)') '         <Geometry Name="NodeLocations"'
         write(xl,'(A)') '                   GeometryType="X_Y">'
         write(xl,'(A,I12,A)') '            <DataItem Dimensions="',
     &      myMesh%num_nodes,'"'
         write(xl,'(A)') '                      NumberType="Float"'
         write(xl,'(A)') '                      Precision="8"'
         write(xl,'(A)') '                      Format="HDF">'
     &      //myFile%FILENAME//':/x'
         write(xl,'(A)') '            </DataItem>'
         write(xl,'(A,I12,A)') '            <DataItem Dimensions="',
     &      myMesh%num_nodes,'"'
         write(xl,'(A)') '                      NumberType="Float"'
         write(xl,'(A)') '                      Precision="8"'
         write(xl,'(A)') '                      Format="HDF">'//
     &      myFile%FILENAME//':/y'
         write(xl,'(A)') '            </DataItem>'
         write(xl,'(A)') '         </Geometry>'
         write(xl,'(A)') '         <Attribute Name="BathymetricDepth"'
         write(xl,'(A)') '                    AttributeType="Scalar"'
         write(xl,'(A)') '                    Center="Node">'
         write(xl,'(A,I12,A)') '            <DataItem Dimensions="',
     &      myMesh%num_nodes,'"'
         write(xl,'(A)') '                      NumberType="Float"'
         write(xl,'(A)') '                      Precision="8"'
         write(xl,'(A)') '                      Format="HDF">'//
     &      myFile%FILENAME//':/depth'
         write(xl,'(A)') '            </DataItem>'
         write(xl,'(A)') '         </Attribute>'
         write(xl,'(A)') '      </Grid>'
         write(xl,'(A)') '   </Domain>'
         write(xl,'(A)') '</Xdmf>'




      write(10,'(A)') '      <Grid Name="TimeSeries"'
      write(10,'(A)') '            GridType="Collection"'
      write(10,'(A)') '            CollectionType="Temporal">'
      ! now write XDMF XML data for this time slice
      write(xl,'(A,E14.6,A)') '         <Grid Name="Time=',dat%myTime%timenc,'"'
      write(xl,'(9x,A)') '      GridType="Uniform">'
      write(xl,'(13x,A)') '<Topology Reference="//Topology[@Name=''ADCIRCMesh'']" />'
      write(xl,'(13x,A)') '<Geometry Reference="//Geometry[@Name=''NodeLocations'']" />'
        write(xl,'(13x,A)') '<Attribute Name="BathymetricDepth"'
        write(xl,'(13x,A)') '           AttributeType="Scalar"'
        write(xl,'(13x,A)') '           Center="Node">'
        write(xl,'(13x,A,I12,A)') '   <DataItem Dimensions="',
     &     dat%myMesh%num_nodes,'"'
        write(xl,'(13x,A)') '             NumberType="Float"'
        write(xl,'(13x,A)') '             Precision="8"'
        write(xl,'(13x,A)') '             Format="HDF">'
     &     //dat%myFile%FILENAME//':/depth'
        write(xl,'(13x,A)') '   </DataItem>'
        write(xl,'(13x,A)') '</Attribute>'
        write(xl,'(13x,A,E14.6,A)')
     &     '<Time Value="',dat%myTime%timenc,'"/>'
        write(xl,'(13x,A)') '<Attribute Name="'
     &                      //trim(xdmfAttributeName)//'"'
        write(xl,'(13x,A)') '           Center="Node"'
        if (descript%num_items_per_record.eq.1) then
           write(xl,'(13x,A)') '           AttributeType="Scalar">'
        else
           write(xl,'(13x,A)') '           AttributeType="Vector">'
           write(xl,'(13x,A)') '   <DataItem ItemType="Function"'
           write(xl,'(13x,A,I12,A)') '                Dimensions="',
     &        dat%myMesh%num_nodes,' 3"'
           write(xl,'(13x,A)')
     &             '                Function="JOIN($0, $1, 0*$0)">'
        endif
        do i=1,descript%num_items_per_record
           write(xl,'(13x,A)') '      <DataItem ItemType="HyperSlab"'
           write(xl,'(13x,A)') '                Dimensions="3070"'
           write(xl,'(13x,A)') '               Type="HyperSlab">'
           write(xl,'(13x,A)') '        <DataItem Dimensions="3 2"'
           write(xl,'(13x,A)') '                  Format="XML">'
           write(xl,'(13x,A,I5,A)') '                 ',
     &         dat%myFile%record_counter-1,' 0'
           write(xl,'(13x,A)') '                     1 1'
           write(xl,'(13x,A,I12)') '                     1 ',
     &         dat%myMesh%num_nodes
           write(xl,'(13x,A)') '          </DataItem>'
           write(xl,'(13x,A,I5,I12,A)')
     &                   '          <DataItem Dimensions="',
     &        dat%myTime%timenc_len-1,dat%myMesh%num_nodes,'"'
           write(xl,'(13x,A)') '                 NumberType="Float"'
           write(xl,'(13x,A)')
     &        '                 Precision="8" Format="HDF">'//
     &        trim(dat%myFile%FILENAME)//":/"//trim(dat%varnames(i))
           write(xl,'(13x,A)') '            </DataItem>'
           write(xl,'(13x,A)') '         </DataItem>'
        enddo
        if (descript%num_items_per_record.ne.1) then
           write(xl,'(13x,A)') '      </DataItem>' ! end of FUNCTION
        endif
        write(xl,'(13x,A)') '   </Attribute>'
        write(xl,'(13x,A)') '</Grid>' ! end of this time snap
        write(xl,'(A)') '      </Grid>' ! end of temporal collection
        write(xl,'(A)') '   </Domain>'
        write(xl,'(A)') '</Xdmf>'
        close(xl)

!----------------------------------------------------------------------
!  CHECK
!---------------------------------------------------------------------
   SUBROUTINE Check(ncStatus)
 !     USE DATA,ONLY: MyRank
      USE netcdf
      IMPLICIT NONE
      INTEGER,INTENT(IN) :: ncStatus
      IF(ncStatus.NE.NF90_NOERR)THEN
         WRITE(*,'(A,A)') "ERROR: NetCDF: ",TRIM(NF90_STRERROR(ncStatus))
         STOP
      ENDIF
   END SUBROUTINE check

!----------------------------------------------------------------------
!  GETMONTHDAY
!----------------------------------------------------------------------
   subroutine getmonthday(dy,yy,mo,dd)

      implicit none
      integer, intent(out)           :: mo, dd
      integer, intent(in)            :: yy, dy
      integer                       :: i
      integer, allocatable          :: cd(:)

      allocate(cd(1:13))
      cd = (/ 0,31,59,90,120,151,181,212,243,273,304,334,365 /)
      if( mod(yy,4) == 0 ) then
        cd = (/ 0,31,60,91,121,152,182,213,244,274,305,335,366 /)
      endif
      do i = 1,12
        if (dy.gt.cd(i)) then
          mo = i
          dd = dy-cd(i)
        endif
      enddo

   end subroutine getmonthday

!-----------------------------------------------------------------------
!     S U B R O U T I N E   O P E N  F I L E  F O R  R E A D
!-----------------------------------------------------------------------
!     jgf: Added general subroutine for opening an existing
!     file for reading. Includes error checking.
!-----------------------------------------------------------------------
      SUBROUTINE openFileForRead(lun, filename)
      IMPLICIT NONE
      INTEGER, intent(in) :: lun   ! fortran logical unit number
      CHARACTER(*), intent(in) :: filename ! full pathname of file
      INTEGER :: errorIO  ! zero if the file opened successfully
      LOGICAL :: fileFound    ! .true. if the file is present
      errorIO = 0
!
!     Check to see if file exists
      write(6,'("INFO: Searching for file to open on unit ",I5,"...")') lun
      inquire(FILE=trim(filename),EXIST=fileFound)
      if (fileFound.eqv..false.) then
         write(6,'("ERROR: The file ",A," was not found.")') trim(filename)
         stop
      else
         write(6,'("INFO: The file ",A," was found. The file will be opened.")') &
            trim(filename)
       endif
!
!     Open existing file
      OPEN(lun,FILE=trim(filename),STATUS='OLD',ACTION='READ',IOSTAT=errorIO)
      if (errorIO.ne.0) then
          write(6,'("ERROR: Could not open the file ",A,".")') trim(filename)
          stop
      else
         write(6,'("INFO: The file ",A," was opened successfully.")') trim(filename)
      endif
      return
!-----------------------------------------------------------------------
      END SUBROUTINE openFileForRead
!-----------------------------------------------------------------------

