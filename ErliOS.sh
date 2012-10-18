#!/bin/bash

VERSION=R15B01
SDK_VER=6.0

################################################################################

PROJECT=ErliOS

WD=$(pwd)

OTP_SRC=otp_src_$VERSION
OTP_SRC_TAR=${OTP_SRC}.tar.gz

XCOMP_CONF=erl-xcomp-arm-darwin.conf
XCOMP_CONF_PATH=xcomp/$XCOMP_CONF

TARGET_ERL_ROOT=/usr/share/erlang

TAR_NAME="${PROJECT}_"

#standard configuration values
STRIP_BIN=false
STRIP_BEAM=false
SLIM_COMPILE=false
COMPRESS_COMPILE=false
COMPRESS_APP=false

#standard gcc opt levels [1,2,3,s]
OPT_LEVEL=s
HOST=arm-apple-darwin10

DEV_ROOT="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer"
SDK_ROOT="${DEV_ROOT}/SDKs/iPhoneOS${SDK_VER}.sdk"

SYS_ROOT="${WD}/sysroot"

#STRIP_CMD=${HOST}-strip
STRIP_CMD="${DEV_ROOT}/usr/bin/strip"

#Arguments parsing
while getopts ":sScCoH:h" Option
do
    case $Option in
        s ) #echo "Stripping beam and Slim compiles"
            STRIP_BEAM=true
            SLIM_COMPILE=true
            TAR_NAME=${TAR_NAME}s
            ;;
        S ) #echo "Stipping binaries"
            STRIP_BIN=true
            TAR_NAME=${TAR_NAME}S
            ;;
        c ) #echo "Compress compiling"
            COMPRESS_COMPILE=true
            TAR_NAME=${TAR_NAME}c
            ;;
        C ) #echo "Compressing Applications"
            COMPRESS_APP=true
            TAR_NAME=${TAR_NAME}C
            ;;
        o ) #echo "Optimization level $OPTARG"
            OPT_LEVEL=$OPTARG
            TAR_NAME=${TAR_NAME}o${OPTARG}
            ;;
        H ) #echo "Host $OPTARG"
            HOST=$OPTARG
            TAR_NAME=${TAR_NAME}H-${OPTARG}
            ;;
        h ) echo \
"./${PROJECT}.sh [options]

Available options:
-s          Strip beam files and compile with the slim flag
-S          Strip binaries
-c          Compile beams using the compress flag
-C          Compress applications into zip's
-o <arg>    Compile the virtual machine with the <arg> optimization flag
-H <arg>    Compile the virtual machine for the host <arg>
-h          Display this help message "
            exit 0
            ;;
        * ) echo "Unimplemented option chosen."   # DEFAULT 
            ;;
    esac
done

## FUNCTION DECLARATION SPACE

show()
{
    cat <<EOF

*
* $1...
*

EOF
}

# END OF FUNCTION DECLARATION

show "Preparing OpenSSL"
mkdir -p "${WD}/sysroot/usr/lib"
cp "${SDK_ROOT}/usr/lib/bundle1.o"        "${WD}/sysroot/usr/lib/bundle1.o"
cp "${SDK_ROOT}/usr/lib/libSystem.dylib"  "${WD}/sysroot/usr/lib/libSystem.dylib"
cp "${SDK_ROOT}/usr/lib/libgcc_s.1.dylib" "${WD}/sysroot/usr/lib/libgcc_s.1.dylib"

#Do not do unnecessary work
if [ -e ${TAR_NAME}.tgz ]
then
    show "The build exists... see $TAR_NAME.tgz"
    exit 0
fi

#Download the erlang source if it does not exist.
[ -e $OTP_SRC_TAR ] || (show "Downloading sources" && wget http://erlang.org/download/$OTP_SRC_TAR)

#Unpack
[ -d $OTP_SRC ] || (show "Unpacking $OTP_SRC" && tar xfz $OTP_SRC_TAR)

show "Create the erl-xcomp configuration"
cat $XCOMP_CONF_PATH.in > ${OTP_SRC}/$XCOMP_CONF_PATH
sed -i "" "s/@OPT_LEVEL@/${OPT_LEVEL}/g" ${OTP_SRC}/$XCOMP_CONF_PATH
sed -i "" "s/@HOST@/${HOST}/g" ${OTP_SRC}/$XCOMP_CONF_PATH
sed -i "" "s/@SDK_VER@/${SDK_VER}/g" ${OTP_SRC}/$XCOMP_CONF_PATH
sed -i "" "s#@SDK_ROOT@#${SYS_ROOT}#g" ${OTP_SRC}/$XCOMP_CONF_PATH

#Enter the Build directory
pushd $OTP_SRC

show "Patching files for arm-apple-darwin gcc compiler and iOS SDK compatibility"
patch -N -p2 < "${WD}/patches/configure.in.patch"
#patch -N -p2 < "${WD}/patches/configure.patch"
patch -N -p2 < "${WD}/patches/erts-configure.in.patch"
patch -N -p2 < "${WD}/patches/erts-emulator-beam-erl_init.c.patch"
patch -N -p2 < "${WD}/patches/erts-etc-unix-run_erl.c.patch"

#Do configure
#TODO: remove any SKIP files that were created previously
show "Configuring for cross compilation using $XCOMP_CONF_PATH"
./otp_build configure --xcomp-conf=$XCOMP_CONF_PATH

if [[ "$SLIM_COMPILE" == "true" || "$COMPRESS_COMPILE" == "true" ]]
then
    NEW_COMPILE_OPTS=""

    if [ "$SLIM_COMPILE" == "true" ]
    then
        NEW_COMPILE_OPTS="$NEW_COMPILE_OPTS \+slim"
    fi

    if [ "$COMPRESS_COMPILE" == "true" ]
    then
        NEW_COMPILE_OPTS="$NEW_COMPILE_OPTS \+compressed"
    fi

    OTP_MK="make/${HOST}/otp.mk"
    show "Patching $OTP_MK to edit erlc options"
    sed -i "s/ \+debug_info/$NEW_COMPILE_OPTS/" $OTP_MK
fi

#Put SKIP files in the apps we don't want.
show "Selecting applications to keep"
KEEPSIES=$(tr '\n' ' ' < ../keep)
for APP in $(ls lib); do
  [ -d lib/$APP ] &&
  echo "Not listed in keep file" >> lib/$APP/SKIP
done
for KEEP in $KEEPSIES; do
  show "Keeping $KEEP"
  rm -f lib/$KEEP/SKIP
done

sed -i "" "s/-m32//g" make/${HOST}/otp.mk
sed -i "" "s/-m32//g" make/${HOST}/otp_ded.mk
sed -i "" "s/-m32 $CFLAGS/$CFLAGS/g" erts/configure

show "Creating bootstrap and building"
./otp_build boot -a

for KEEP in $KEEPSIES; do
  show "Removing prebuilt files in $KEEP"
  rm -f lib/$KEEP/ebin/*.beam
done

show "Creating release"
./otp_build release -a

echo $(pwd)

pushd release/${HOST}/

show "Running Install script to setup paths and executables"
./Install -cross -minimal $TARGET_ERL_ROOT
rm Install

if [ $STRIP_BEAM == true ]
then
    show "Stripping beam files"
    erl -eval "beam_lib:strip_release('${WD}/otp_src_${VERSION}/release/${HOST}')" -s init stop
fi

if [ $STRIP_BIN == true ]
then
    show "Stripping erts binaries"
    $STRIP_CMD erts-*/bin/*
fi

show "Removing source code, documentation, and examples"
for DIR in $(ls | grep erts) lib/*; do
    rm -rf ${DIR}/src
    rm -rf ${DIR}/include
    rm -rf ${DIR}/doc
    rm -rf ${DIR}/man
    rm -rf ${DIR}/examples
done
rm -rf usr/include
rm -rf misc

if [ $COMPRESS_APP = true ]
then
    show "Compressing erlang applications"
    pushd lib
    for APP in $(ls); do
        zip -r ${APP}.zip $APP
        mv ${APP}.zip ${APP}.ez
        rm -f -r $APP
    done
    popd
fi

show "Creating tarball"
tar czf ${WD}/${TAR_NAME}.tgz .

## Test the resulted binary for TARGET compatability
file erts-5.8.2/bin/beam

popd # release/${HOST}
popd # ${OTP_SRC}
