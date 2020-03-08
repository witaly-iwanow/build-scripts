#!/bin/bash

# initially based on https://gist.github.com/BennettSmith/9487468ae3375d0db0cc, rev 9

# The version of Protobuf to build.  It must match
# one of the values found in the releases section of the github repo.
# It can be set to "master" when building directly from the github repo.
PROTOBUF_VERSION=3.11.4

# Set to "YES" if you would like the build script to
# pause after each major section.
INTERACTIVE=NO

# A "YES" value will build the latest code from GitHub on the master branch.
# A "NO" value will use ${PROTOBUF_VERSION} tarball downloaded from GitHub.
USE_GIT_MASTER=NO

# note that iOS 11 drops 32-bit support (BUILD_I386_IOSSIM, BUILD_IOS_ARMV7 and BUILD_IOS_ARMV7S should be set to NO)
MIN_SDK_VERSION=10.0

BUILD_I386_IOSSIM=YES
BUILD_X86_64_IOSSIM=YES

BUILD_IOS_ARMV7=YES
BUILD_IOS_ARMV7S=YES
BUILD_IOS_ARM64=YES

function printHelp {
  echo "Params:"
  echo "  -i/--interactive          stop after each step and ask for confirmation to proceed"
  echo "  -m/--master               grab the latest master from GitHub and build it"
  echo "  -r/--release [RELEASE]    build particular release of protobuf (3.11.4 is default)"
  echo "  --target [IOS RELEASE]    set iOS deployment target (10.0 is default)"
  echo "  -d/--disable [ARCH]       exclude ARCH from build (can be 386, x86_64, armv7, armv7s or arm64)"
  echo ""
  echo "Example (build 3.7.0 interactively):"
  echo "  $0 -i -r 3.7.0"
  echo ""
  echo "Example (build master without any questions asked):"
  echo "  $0 --master"
  echo ""
  echo "Example (build protobuf 3.10.1 to be deployed on iOS 11+):"
  echo "  $0 --release 3.10.1 --target 11.0 --disable 386 --disable armv7 --disable armv7s"
}

if [ "$1" == "-h" ] || [ "$1" == "--help" ]
then
  printHelp
  exit 0
fi

while [[ $# > 0 ]]
do
  key="$1"

  case $key in
    -h|--help)
      echo "--help can only be used alone"
      exit -1
      ;;
    -i|--interactive)
      INTERACTIVE=YES
      ;;
    -m|--master)
      USE_GIT_MASTER=YES
      PROTOBUF_VERSION=master
      ;;
    -r|--release)
      shift
      PROTOBUF_VERSION="$1"
      ;;
    --target)
      shift
      MIN_SDK_VERSION="$1"
      ;;
    -d|--disable)
      shift
      if [ "$1" == "386" ]
      then
        BUILD_I386_IOSSIM=NO
      elif [ "$1" == "x86_64" ]
      then
        BUILD_X86_64_IOSSIM=NO
      elif [ "$1" == "armv7" ]
      then
        BUILD_IOS_ARMV7=NO
      elif [ "$1" == "armv7s" ]
      then
        BUILD_IOS_ARMV7S=NO
      elif [ "$1" == "arm64" ]
      then
        BUILD_IOS_ARM64=NO
      else
        echo "Error: unknown architecture ($1)"
        exit -1
      fi
      ;;
    *)
      # unknown option
      ;;
  esac
  shift # past argument or value
done

function conditionalPause {
  if [ "${INTERACTIVE}" == "YES" ]
  then
    while true; do
        read -p "Proceed with build? (y/n) " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
  fi
}

# The results will be stored relative to the location
# where you stored this script, **not** relative to
# the location of the protobuf git repo.
PREFIX=`pwd`/protobuf
if [ -d ${PREFIX} ]
then
    rm -rf "${PREFIX}"
fi
mkdir -p "${PREFIX}/platform"

PROTOBUF_GIT_URL=https://github.com/protocolbuffers/protobuf.git
PROTOBUF_GIT_DIRNAME=protobuf
PROTOBUF_RELEASE_URL=https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOBUF_VERSION}/protobuf-cpp-${PROTOBUF_VERSION}.tar.gz
PROTOBUF_RELEASE_DIRNAME=protobuf-${PROTOBUF_VERSION}

# don't switch this one off, it's needed for --with-protoc
BUILD_MACOSX_X86_64=YES

PROTOBUF_SRC_DIR=`pwd`/protobuf-tmp

DARWIN=darwin`uname -r`
NPROC=`nproc`

XCODEDIR=`xcode-select --print-path`
IOS_SDK_VERSION=`xcrun --sdk iphoneos --show-sdk-version`

MACOSX_PLATFORM=`xcrun --show-sdk-platform-path`
MACOSX_SYSROOT=`xcrun --show-sdk-path`

IPHONEOS_PLATFORM=`xcrun --sdk iphoneos --show-sdk-platform-path`
IPHONEOS_SYSROOT=`xcrun --sdk iphoneos --show-sdk-path`

IPHONESIMULATOR_PLATFORM=`xcrun --sdk iphonesimulator --show-sdk-platform-path`
IPHONESIMULATOR_SYSROOT=`xcrun --sdk iphonesimulator --show-sdk-path`

# Uncomment if you want to see more information about each invocation
# of clang as the builds proceed.
# CLANG_VERBOSE="--verbose"

CC=clang
CXX=clang

SILENCED_WARNINGS="-Wno-unused-local-typedef -Wno-unused-function"

# NOTE: Google Protobuf does not currently build if you specify 'libstdc++'
# instead of `libc++` here.
STDLIB=libc++

CFLAGS="${CLANG_VERBOSE} ${SILENCED_WARNINGS} -DNDEBUG -g -O0 -pipe -fPIC -fcxx-exceptions"
CXXFLAGS="${CLANG_VERBOSE} ${CFLAGS} -std=c++11 -stdlib=${STDLIB}"

LDFLAGS="-stdlib=${STDLIB}"
LIBS="-lc++ -lc++abi"

echo "$(tput setaf 2)"
echo "###################################################################"
echo "# Preparing to build Google Protobuf"
echo "###################################################################"
echo "$(tput sgr0)"

echo "PREFIX ..................... ${PREFIX}"
echo "USE_GIT_MASTER ............. ${USE_GIT_MASTER}"
echo "PROTOBUF_GIT_URL ........... ${PROTOBUF_GIT_URL}"
echo "PROTOBUF_GIT_DIRNAME ....... ${PROTOBUF_GIT_DIRNAME}"
echo "PROTOBUF_VERSION ........... ${PROTOBUF_VERSION}"
echo "PROTOBUF_RELEASE_URL ....... ${PROTOBUF_RELEASE_URL}"
echo "PROTOBUF_RELEASE_DIRNAME ... ${PROTOBUF_RELEASE_DIRNAME}"
echo "BUILD_MACOSX_X86_64 ........ ${BUILD_MACOSX_X86_64}"
echo "BUILD_I386_IOSSIM .......... ${BUILD_I386_IOSSIM}"
echo "BUILD_X86_64_IOSSIM ........ ${BUILD_X86_64_IOSSIM}"
echo "BUILD_IOS_ARMV7 ............ ${BUILD_IOS_ARMV7}"
echo "BUILD_IOS_ARMV7S ........... ${BUILD_IOS_ARMV7S}"
echo "BUILD_IOS_ARM64 ............ ${BUILD_IOS_ARM64}"
echo "PROTOBUF_SRC_DIR ........... ${PROTOBUF_SRC_DIR}"
echo "DARWIN ..................... ${DARWIN}"
echo "XCODEDIR ................... ${XCODEDIR}"
echo "IOS_SDK_VERSION ............ ${IOS_SDK_VERSION}"
echo "MIN_SDK_VERSION ............ ${MIN_SDK_VERSION}"
echo "MACOSX_PLATFORM ............ ${MACOSX_PLATFORM}"
echo "MACOSX_SYSROOT ............. ${MACOSX_SYSROOT}"
echo "IPHONEOS_PLATFORM .......... ${IPHONEOS_PLATFORM}"
echo "IPHONEOS_SYSROOT ........... ${IPHONEOS_SYSROOT}"
echo "IPHONESIMULATOR_PLATFORM ... ${IPHONESIMULATOR_PLATFORM}"
echo "IPHONESIMULATOR_SYSROOT .... ${IPHONESIMULATOR_SYSROOT}"
echo "CC ......................... ${CC}"
echo "CFLAGS ..................... ${CFLAGS}"
echo "CXX ........................ ${CXX}"
echo "CXXFLAGS ................... ${CXXFLAGS}"
echo "LDFLAGS .................... ${LDFLAGS}"
echo "LIBS ....................... ${LIBS}"

conditionalPause

echo "$(tput setaf 2)"
echo "###################################################################"
echo "# Fetch Google Protobuf"
echo "###################################################################"
echo "$(tput sgr0)"

(
    if [ -d ${PROTOBUF_SRC_DIR} ]
    then
        rm -rf ${PROTOBUF_SRC_DIR}
    fi

    cd `dirname ${PROTOBUF_SRC_DIR}`

    if [ "${USE_GIT_MASTER}" == "YES" ]
    then
        git clone ${PROTOBUF_GIT_URL}
        cd protobuf
        git submodule update --init --recursive
    else
        if [ -d ${PROTOBUF_RELEASE_DIRNAME} ]
        then
            rm -rf "${PROTOBUF_RELEASE_DIRNAME}"
        fi
        curl --location ${PROTOBUF_RELEASE_URL} --output ${PROTOBUF_RELEASE_DIRNAME}.tar.gz
        tar xf ${PROTOBUF_RELEASE_DIRNAME}.tar.gz
        mv "${PROTOBUF_RELEASE_DIRNAME}" "${PROTOBUF_SRC_DIR}"
        rm ${PROTOBUF_RELEASE_DIRNAME}.tar.gz
    fi
)

conditionalPause

echo "$(tput setaf 2)"
echo "###################################################################"
echo "# Run autogen.sh to prepare for build."
echo "###################################################################"
echo "$(tput sgr0)"
(
  cd ${PROTOBUF_SRC_DIR}
  ( exec ./autogen.sh )
)

conditionalPause

###################################################################
# This section contains the build commands to create the native
# protobuf library for Mac OS X.  This is done first so we have
# a copy of the protoc compiler.  It will be used in all of the
# susequent iOS builds.
###################################################################

echo "$(tput setaf 2)"
echo "###################################################################"
echo "# x86_64 for Mac OS X"
echo "###################################################################"
echo "$(tput sgr0)"

if [ "${BUILD_MACOSX_X86_64}" == "YES" ]
then
    cd ${PROTOBUF_SRC_DIR}
    make distclean
    ./configure --disable-shared --prefix=${PREFIX} --exec-prefix=${PREFIX}/platform/x86_64-mac "CC=${CC}" "CFLAGS=${CFLAGS} -arch x86_64" "CXX=${CXX}" "CXXFLAGS=${CXXFLAGS} -arch x86_64" "LDFLAGS=${LDFLAGS}" "LIBS=${LIBS}"
    make -j${NPROC}
    make install
fi

PROTOC=${PREFIX}/platform/x86_64-mac/bin/protoc

conditionalPause

###################################################################
# This section contains the build commands for each of the
# architectures that will be included in the universal binaries.
###################################################################

if [ "${BUILD_I386_IOSSIM}" == "YES" ]
then
    echo "$(tput setaf 2)"
    echo "###########################"
    echo "# i386 for iPhone Simulator"
    echo "###########################"
    echo "$(tput sgr0)"
    cd ${PROTOBUF_SRC_DIR}
    make distclean
    ./configure --build=x86_64-apple-${DARWIN} --host=i386-apple-${DARWIN} --with-protoc=${PROTOC} --disable-shared --prefix=${PREFIX} --exec-prefix=${PREFIX}/platform/i386-sim "CC=${CC}" "CFLAGS=${CFLAGS} -mios-simulator-version-min=${MIN_SDK_VERSION} -arch i386 -isysroot ${IPHONESIMULATOR_SYSROOT}" "CXX=${CXX}" "CXXFLAGS=${CXXFLAGS} -mios-simulator-version-min=${MIN_SDK_VERSION} -arch i386 -isysroot ${IPHONESIMULATOR_SYSROOT}" LDFLAGS="-arch i386 -mios-simulator-version-min=${MIN_SDK_VERSION} ${LDFLAGS} -L${IPHONESIMULATOR_SYSROOT}/usr/lib/ -L${IPHONESIMULATOR_SYSROOT}/usr/lib/system" "LIBS=${LIBS}"
    make -j${NPROC}
    make install
    I386_LIB="i386-sim/lib/libprotobuf.a"
    I386_LIB_LITE="i386-sim/lib/libprotobuf-lite.a"
    conditionalPause
fi

if [ "${BUILD_X86_64_IOSSIM}" == "YES" ]
then
    echo "$(tput setaf 2)"
    echo "#############################"
    echo "# x86_64 for iPhone Simulator"
    echo "#############################"
    echo "$(tput sgr0)"
    cd ${PROTOBUF_SRC_DIR}
    make distclean
    ./configure --host=x86_64-apple-${DARWIN} --with-protoc=${PROTOC} --disable-shared --prefix=${PREFIX} --exec-prefix=${PREFIX}/platform/x86_64-sim "CC=${CC}" "CFLAGS=${CFLAGS} -mios-simulator-version-min=${MIN_SDK_VERSION} -arch x86_64 -isysroot ${IPHONESIMULATOR_SYSROOT}" "CXX=${CXX}" "CXXFLAGS=${CXXFLAGS} -mios-simulator-version-min=${MIN_SDK_VERSION} -arch x86_64 -isysroot ${IPHONESIMULATOR_SYSROOT}" LDFLAGS="-arch x86_64 -mios-simulator-version-min=${MIN_SDK_VERSION} ${LDFLAGS} -L${IPHONESIMULATOR_SYSROOT}/usr/lib/ -L${IPHONESIMULATOR_SYSROOT}/usr/lib/system" "LIBS=${LIBS}"
    make -j${NPROC}
    make install
    X86_64_LIB="x86_64-sim/lib/libprotobuf.a"
    X86_64_LIB_LITE="x86_64-sim/lib/libprotobuf-lite.a"
    conditionalPause
fi

if [ "${BUILD_IOS_ARMV7}" == "YES" ]
then
    echo "$(tput setaf 2)"
    echo "##################"
    echo "# armv7 for iPhone"
    echo "##################"
    echo "$(tput sgr0)"
    cd ${PROTOBUF_SRC_DIR}
    make distclean
    ./configure --build=x86_64-apple-${DARWIN} --host=armv7-apple-${DARWIN} --with-protoc=${PROTOC} --disable-shared --prefix=${PREFIX} --exec-prefix=${PREFIX}/platform/armv7-ios "CC=${CC}" "CFLAGS=${CFLAGS} -miphoneos-version-min=${MIN_SDK_VERSION} -arch armv7 -isysroot ${IPHONEOS_SYSROOT}" "CXX=${CXX}" "CXXFLAGS=${CXXFLAGS} -arch armv7 -isysroot ${IPHONEOS_SYSROOT}" LDFLAGS="-arch armv7 -miphoneos-version-min=${MIN_SDK_VERSION} ${LDFLAGS}" "LIBS=${LIBS}"
    make -j${NPROC}
    make install
    ARMV7_LIB="armv7-ios/lib/libprotobuf.a"
    ARMV7_LIB_LITE="armv7-ios/lib/libprotobuf-lite.a"
    conditionalPause
fi

if [ "${BUILD_IOS_ARMV7S}" == "YES" ]
then
    echo "$(tput setaf 2)"
    echo "###################"
    echo "# armv7s for iPhone"
    echo "###################"
    echo "$(tput sgr0)"
    cd ${PROTOBUF_SRC_DIR}
    make distclean
    ./configure --build=x86_64-apple-${DARWIN} --host=armv7s-apple-${DARWIN} --with-protoc=${PROTOC} --disable-shared --prefix=${PREFIX} --exec-prefix=${PREFIX}/platform/armv7s-ios "CC=${CC}" "CFLAGS=${CFLAGS} -miphoneos-version-min=${MIN_SDK_VERSION} -arch armv7s -isysroot ${IPHONEOS_SYSROOT}" "CXX=${CXX}" "CXXFLAGS=${CXXFLAGS} -miphoneos-version-min=${MIN_SDK_VERSION} -arch armv7s -isysroot ${IPHONEOS_SYSROOT}" LDFLAGS="-arch armv7s -miphoneos-version-min=${MIN_SDK_VERSION} ${LDFLAGS}" "LIBS=${LIBS}"
    make -j${NPROC}
    make install
    ARMV7S_LIB="armv7s-ios/lib/libprotobuf.a"
    ARMV7S_LIB_LITE="armv7s-ios/lib/libprotobuf-lite.a"
    conditionalPause
fi

if [ "${BUILD_IOS_ARM64}" == "YES" ]
then
    echo "$(tput setaf 2)"
    echo "##################"
    echo "# arm64 for iPhone"
    echo "##################"
    echo "$(tput sgr0)"
    cd ${PROTOBUF_SRC_DIR}
    make distclean
    ./configure --build=x86_64-apple-${DARWIN} --host=arm --with-protoc=${PROTOC} --disable-shared --prefix=${PREFIX} --exec-prefix=${PREFIX}/platform/arm64-ios "CC=${CC}" "CFLAGS=${CFLAGS} -miphoneos-version-min=${MIN_SDK_VERSION} -arch arm64 -isysroot ${IPHONEOS_SYSROOT}" "CXX=${CXX}" "CXXFLAGS=${CXXFLAGS} -miphoneos-version-min=${MIN_SDK_VERSION} -arch arm64 -isysroot ${IPHONEOS_SYSROOT}" LDFLAGS="-arch arm64 -miphoneos-version-min=${MIN_SDK_VERSION} ${LDFLAGS}" "LIBS=${LIBS}"
    make -j${NPROC}
    make install
    ARM64_LIB="arm64-ios/lib/libprotobuf.a"
    ARM64_LIB_LITE="arm64-ios/lib/libprotobuf-lite.a"
    conditionalPause
fi

echo "$(tput setaf 2)"
echo "###################################################################"
echo "# Create Universal Libraries and Finalize the packaging"
echo "###################################################################"
echo "$(tput sgr0)"

(
    cd ${PREFIX}/platform
    mkdir universal
    lipo ${I386_LIB} ${X86_64_LIB} ${ARMV7_LIB} ${ARMV7S_LIB} ${ARM64_LIB} -create -output universal/libprotobuf.a
    lipo ${I386_LIB_LITE} ${X86_64_LIB_LITE} ${ARMV7_LIB_LITE} ${ARMV7S_LIB_LITE} ${ARM64_LIB_LITE} -create -output universal/libprotobuf-lite.a
)

(
    cd ${PREFIX}
    mkdir bin
    mkdir lib
    cp -r platform/x86_64-mac/bin/protoc bin
    cp -r platform/x86_64-mac/lib/* lib
    cp -r platform/universal/* lib
    lipo -info lib/libprotobuf.a
    lipo -info lib/libprotobuf-lite.a
)

if [ "${USE_GIT_MASTER}" == "YES" ]
then
    if [ -d "${PREFIX}-master" ]
    then
        rm -rf "${PREFIX}-master"
    fi
    mv "${PREFIX}" "${PREFIX}-master"
else
    if [ -d "${PREFIX}-${PROTOBUF_VERSION}" ]
    then
        rm -rf "${PREFIX}-${PROTOBUF_VERSION}"
    fi
    mv "${PREFIX}" "${PREFIX}-${PROTOBUF_VERSION}"
fi

rm -rf "${PROTOBUF_SRC_DIR}"

echo Done!
