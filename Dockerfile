FROM ubuntu:focal as base
ARG XYCE_VERSION
ARG TRILINOS_VERSION

ENV TZ=America/Chicago DEBIAN_FRONTEND=noninteractive
# The "folly" component currently fails if "fmt" is not explicitly installed first.
RUN apt-get update && apt-get install -y cmake build-essential m4 python-dev-is-python3 \
  git gfortran bison flex libfl-dev libfftw3-dev libsuitesparse-dev libopenblas-dev \
  liblapack-dev automake autoconf libtool python3-numpy python3-scipy

RUN git clone --branch $TRILINOS_VERSION --depth 1 https://github.com/trilinos/Trilinos/
RUN git clone --branch $XYCE_VERSION --depth 1 https://github.com/Xyce/Xyce /Xyce
RUN git clone --branch=$XYCE_VERSION --depth=1 https://github.com/Xyce/Xyce_Regression /Xyce_Regression

FROM base as serial
WORKDIR /Trilinos-build
RUN SRCDIR=/Trilinos; \
  ARCHDIR=/XyceLibs/Serial; \
  FLAGS="-O3 -fPIC"; \
  cmake \
  -G "Unix Makefiles" \
    -DCMAKE_C_COMPILER=gcc \
    -DCMAKE_CXX_COMPILER=g++ \
    -DCMAKE_Fortran_COMPILER=gfortran \
    -DCMAKE_CXX_FLAGS="$FLAGS" \
    -DCMAKE_C_FLAGS="$FLAGS" \
    -DCMAKE_Fortran_FLAGS="$FLAGS" \
    -DCMAKE_INSTALL_PREFIX=$ARCHDIR \
    -DCMAKE_MAKE_PROGRAM="make" \
    -DTrilinos_ENABLE_NOX=ON \
    -DNOX_ENABLE_LOCA=ON \
    -DTrilinos_ENABLE_EpetraExt=ON \
    -DEpetraExt_BUILD_BTF=ON \
    -DEpetraExt_BUILD_EXPERIMENTAL=ON \
    -DEpetraExt_BUILD_GRAPH_REORDERINGS=ON \
    -DTrilinos_ENABLE_TrilinosCouplings=ON \
    -DTrilinos_ENABLE_Ifpack=ON \
    -DTrilinos_ENABLE_Isorropia=ON \
    -DTrilinos_ENABLE_AztecOO=ON \
    -DTrilinos_ENABLE_Belos=ON \
    -DTrilinos_ENABLE_Teuchos=ON \
    -DTeuchos_ENABLE_COMPLEX=ON \
    -DTrilinos_ENABLE_Amesos=ON \
    -DAmesos_ENABLE_KLU=ON \
    -DTrilinos_ENABLE_Sacado=ON \
    -DTrilinos_ENABLE_Kokkos=OFF \
    -DTrilinos_ENABLE_ALL_OPTIONAL_PACKAGES=OFF \
    -DTrilinos_ENABLE_CXX11=ON \
    -DTPL_ENABLE_AMD=ON \
    -DAMD_LIBRARY_DIRS="/usr/lib" \
    -DTPL_AMD_INCLUDE_DIRS="/usr/include/suitesparse" \
    -DTPL_ENABLE_BLAS=ON \
    -DTPL_ENABLE_LAPACK=ON \
    $SRCDIR
RUN make -j$(nproc) && make install

WORKDIR /Xyce
RUN ./bootstrap

WORKDIR /Xyce-serial-build
RUN ../Xyce/configure ARCHDIR=/XyceLibs/Serial \
  CXXFLAGS="-O3 -std=c++11" \
  CPPFLAGS="-I/usr/include/suitesparse" \
  --prefix=/XyceInstall/Serial
RUN make -j$(nproc) && make install

RUN /Xyce_Regression/TestScripts/run_xyce_regression \
  --timelimit=60 \
  --output=`pwd`/Xyce_Test \
  --xyce_test="/Xyce_Regression" \
  --resultfile=`pwd`/serial_results \
  --taglist="+serial+nightly?noverbose-verbose?klu?fft" \
  `pwd`/src/Xyce

FROM ubuntu:focal
COPY --from=serial /XyceInstall /XyceLibs /
