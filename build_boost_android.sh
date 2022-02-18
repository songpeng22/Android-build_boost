#!/bin/bash

# Example
# buildboostandroid 1 65 1

# Script arguments:
# $1: <major> representing the major boost version number to install
# $2: <minor> representing the minor boost version number to install
# $3: <patch> representing the patch boost version number to install
# $4: 'force' if installation should proceed even if /usr/local/include/boost already exists, it removes /usr/local/include/boost and /usr/local/lib/lobboost_*!

SAVE=`pwd`

# boost major version number, typically 1
MAJOR=$1

# boost minor version number, e.g. 65 
MINOR=$2

# boost patch number, typically a low number, often 0
PATCH=$3

# Directory where to unzip the tarball
BOOSTDIR1=boost_${MAJOR}_${MINOR}_${PATCH}

# Directory where to copy from BOOSTDIR1, and having some subsequent changes
BOOSTDIR2=${MAJOR}.${MINOR}.${PATCH}

TARNAME=boost_${MAJOR}_${MINOR}_${PATCH}.tar.bz2
BOOSTDOWNLOAD="http://sourceforge.net/projects/boost/files/boost/${BOOSTDIR2}/${TARNAME}/download"

BUILD_DIR=~/boost/build/arm64-v8a
INSTALL_DIR=~/boost/install/arm64-v8a

# $NDK is the installation root for the Android NDK
# After Android Studio is installed we assume the Android NDK is located here
NDK=/opt/android-ndk/ndk

# Path to Android toolchain (i.e. android compilers etc), relative to ~/boost
REL_TOOLCHAIN=android-tool-chain/arm64-v8a

ABS_TOOLCHAIN=~/boost/${REL_TOOLCHAIN}

mkdir -p ~/boost
cd ~/boost

if [ "$4" = "force" ]; then
    # Force boost to be downloaded and unpacked again
    rm -f ${TARNAME}
    sudo rm -rf ${BOOSTDIR1}
    sudo rm -rf ${BOOSTDIR2}
fi

if [ -e ${TARNAME} ]; then
    echo ${TARNAME} already exists, no need to download from ${BOOSTDOWNLOAD}
else
    echo Downloading ${TARNAME}
    wget -c "$BOOSTDOWNLOAD" -O ${TARNAME}
fi

if [ -d ${BOOSTDIR1} ]; then
    echo folder ${BOOSTDIR1} already exists, no need to uncompress tarball ${TARNAME}
else
    echo uncompressing tarball
    tar --bzip2 -xf ${TARNAME}
fi

if [ -d ${BOOSTDIR2} ]; then
    echo folder ${BOOSTDIR2} already exists, no need to copy from ${BOOSTDIR1}
else
    cp -R ${BOOSTDIR1} ${BOOSTDIR2}
fi

if [ -d ${ABS_TOOLCHAIN} ]; then
    echo folder ${ABS_TOOLCHAIN} already exists, no need to use make_standalone_toolchain.py to create standalone toolchain.
else
    # Create a standalone toolchain for arm64-v8a as described in https://developer.android.com/ndk/guides/standalone_toolchain.html
    # arm64 implies arm64-v8a, and the default STL is gnustl and api=21, but we set it anyway.
    # The install dir is relative to the current directory - i.e. so it is ~/boost/android-tool-chain/arm64-v8a, these folders are created automatically
    echo creating toolchain ${ABS_TOOLCHAIN}
    $NDK/build/tools/make_standalone_toolchain.py --arch arm64 --api 21 --stl=gnustl --install-dir=$REL_TOOLCHAIN
fi

# Add the standalone toolchain to the search path.
export PATH=${ABS_TOOLCHAIN}/bin:$PATH

echo "PATH=$PATH"
echo

# Tell configure what tools to use.
target_host=aarch64-linux-android
export AR=$target_host-ar
export AS=$target_host-gcc
export CC=$target_host-gcc
export CXX=$target_host-g++
export LD=$target_host-ld
export STRIP=$target_host-strip

echo "------------ $AR --------------"
$AR -V

echo "------------ $CC --------------"
$CC --version

echo "------------ $LD --------------"
$LD --version

echo "------------ $STRIP --------------"
$STRIP --version

# Tell configure what flags Android requires.
export CFLAGS="-fPIE -fPIC"
export LDFLAGS="-pie"

#" -march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=softfp"\
#" --sysroot=/home/david/Android/Sdk/ndk-bundle/platforms/android-9/arch-arm"\

CXXFLAGS=\
"-I${ABS_TOOLCHAIN}/sysroot/usr/include"\
" -I${ABS_TOOLCHAIN}/include/c++/4.9.x"\
" -fPIC -Wno-unused-variable"\
" -std=c++11"

echo "CXXFLAGS=$CXXFLAGS"
echo

LINKFLAGS=\
" -L${ABS_TOOLCHAIN}/sysroot/usr/lib"

echo "LINKFLAGS=$LINKFLAGS"
echo

cd ${BOOSTDIR2}

# This is what was done in the "Boost for Android" project on GitHub. https://github.com/dec1/Boost-for-Android
# However that appears to be causing problems here (not how we exclude building the graph_parallel and mpi libraries)
rm user-config.jam
echo "using mpi ;" > user-config.jam

echo "using gcc : arm : ${ABS_TOOLCHAIN}/bin/$CXX ; " >> user-config.jam

./bootstrap.sh 

echo
echo
echo
    
# -d+2   Show commands as they are executed
# -q     Stop at first error
# -j16   Run up to 16 commands concurrently

#    binary-format=elf \
#    address-model=32 \
#    abi=aapcs \

# The following libraries cannot be built currently
# --with-graph_parallel \
# --with-mpi \
# --with-python \

echo "Building both static and shared boost libraries"
echo "Headers will be installed under ~/boost/install/arm64-v8a/include"
echo "Libraries will be installed under ~/boost/install/arm64-v8a/lib"
echo "Writing stdout to ~/boost/out.txt and stderr to ~/boost/err.txt"
echo "Have patience this takes a long time..."

./b2 -d+2 -q -j16 \
    variant=release \
    link=shared,static \
    runtime-link=shared \
    threading=multi \
    target-os=android \
    architecture=arm \
    cxxflags="$CXXFLAGS" \
    linkflags="$LINKFLAGS" \
    --user-config=user-config.jam \
    --layout=system \
    --prefix=$INSTALL_DIR \
    --build-dir=$BUILD_DIR \
    --with-atomic \
    --with-chrono \
    --with-container \
    --with-context \
    --with-coroutine \
    --with-date_time \
    --with-exception \
    --with-fiber \
    --with-filesystem \
    --with-graph \
    --with-iostreams \
    --with-locale \
    --with-log \
    --with-math \
    --with-program_options \
    --with-random \
    --with-regex \
    --with-serialization \
    --with-signals \
    --with-stacktrace \
    --with-system \
    --with-test \
    --with-thread \
    --with-timer \
    --with-type_erasure \
    --with-wave \
    install \
    1>~/boost/out.txt 2>~/boost/err.txt

echo
if [ $? -eq 0 ]
then
  echo "Successfully built boost libraries"
else
  echo "Error building boost libraries, return code: $?" >&2
fi

cd $SAVE
