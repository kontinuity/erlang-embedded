#!/bin/bash

#  Automatic build script for libssl and libcrypto 
#  for iPhoneOS and iPhoneSimulator
#
#  Created by Felix Schulze on 16.12.10.
#  Copyright 2010 Felix Schulze. All rights reserved.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

VERSION="1.0.0d"
SDKVERSION="4.2"

CURRENTPATH=$(pwd)
CRYPTOLIBPATH="${CURRENTPATH}/usr"

mkdir -p "${CRYPTOLIBPATH}/src"
mkdir -p "${CRYPTOLIBPATH}/bin"
mkdir -p "${CRYPTOLIBPATH}/lib"
mkdir -p "${CRYPTOLIBPATH}/include"

## Download
curl -s -O http://www.openssl.org/source/openssl-${VERSION}.tar.gz

## Extract
tar zxf openssl-${VERSION}.tar.gz -C "${CRYPTOLIBPATH}/src"
cd "${CRYPTOLIBPATH}/src/openssl-${VERSION}"

## Configure
export CC="/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/gcc -arch armv7"
./configure BSD-generic32 --openssldir="${CRYPTOLIBPATH}/bin"

## Make
sed -ie "s!^CFLAG=!CFLAG=-isysroot /Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS${SDKVERSION}.sdk !" "Makefile"
sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
make
make install

## Cleanup
cp ${CRYPTOLIBPATH}/bin/lib/libssl.a ${CRYPTOLIBPATH}/lib/libssl.a
cp ${CRYPTOLIBPATH}/bin/lib/libcrypto.a ${CRYPTOLIBPATH}/lib/libcrypto.a
cp -R ${CRYPTOLIBPATH}/bin/include/openssl ${CRYPTOLIBPATH}/include/
rm -rf ${CRYPTOLIBPATH}/src
rm -rf ${CRYPTOLIBPATH}/bin
