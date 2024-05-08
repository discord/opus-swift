#!/bin/sh

set -ex

# MIT License

# Copyright (c) 2021 Ybrid®, a Hybrid Dynamic Live Audio Technology

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# 
# Generates fat libopus.a for iOS and for macOS.
# 
# Preconditions: 
# - clang installed
# - git clone of https://github.com/xiph/opus in directory ../opus
# - checked iosSDKVersion and osxSDKVersion 

iosSDKVersion="17.0"
osxSDKVersion="14.0"
opusDownload="https://archive.mozilla.org/pub/opus/opus-1.3.1.tar.gz"
here=$(pwd)

rm -f opus-*.gz
wget $opusDownload

libopusDir=`basename $opusDownload | sed "s/\.tar.gz$//"` 
rm -rf $libopusDir
tar -xvzf `basename $opusDownload`
echo "opus sources ready in $libopusDir" 
echo "\n==========================="


opuspath="$here/$libopusDir"
opusArtifact=.libs/libopus.a
opusHeaders="$opuspath/include"

echo "$opuspath"

tmp=./prepare
fatLibsDest=opus-swift/libs

generateLibopus()
{
    host=$1
    arch=$2
    sdk=$3

    sdkname=`basename $sdk | sed "s/[0-9\.]*\.sdk$//"` # stripping path, version and '.sdk'
    product="libopus_${host}_${arch}_$sdkname.a"
    echo "\n----------------------------"
    echo "generating $tmp/$product ...\n"

    logfile="$here/$tmp/generate_${host}_${arch}_$sdkname.log"

    cd $opuspath
    if [ -f Makefile ]; then
      make clean > $logfile
    fi
    
    if [[ $sdkname =~ "iPhoneSimulator" ]]; then 
        minversion="-miphonesimulator-version-min=14.0"
    else
        minversion="-miphoneos-version-min=14.0"
    fi
    ./configure --enable-float-approx --disable-shared --enable-static --with-pic \
        --disable-extra-programs --disable-doc --host=$host \
        CFLAGS="-arch $arch -Ofast -flto -g -fPIE $minversion -isysroot $sdk" \
        LDFLAGS="-flto -fPIE $minversion" >> $logfile

    make >> $logfile

    cd $here
    cp "$opuspath/$opusArtifact" "$tmp/$product"
    echo "generated $product, see $logfile\n"
    lipo -i "$tmp/$product"
}

xcodePlatforms="/Applications/Xcode-15.0.0.15A240d.app/Contents/Developer/Platforms"
sdkSimulator="$xcodePlatforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator$iosSDKVersion.sdk"
sdkPhone="/$xcodePlatforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS$iosSDKVersion.sdk"
sdkMac="/$xcodePlatforms/MacOSX.platform/Developer/SDKs/MacOSX$osxSDKVersion.sdk"

#cd $opuspath
#make distclean
cd $here
rm -rf $tmp
mkdir -p $tmp
mkdir -p opus-swift/libs
mkdir -p opus-swift/include

fatProductIos="libopus_device_ios.a"
fatProductSimulatorIos="libopus_simulator_ios.a"
echo "\n==========================="
echo "generate $fatProductIos ..."
generateLibopus "arm-apple-darwin" "x86_64" $sdkSimulator
generateLibopus "arm-apple-darwin" "arm64" $sdkSimulator
generateLibopus "arm-apple-darwin" "arm64" $sdkPhone
cd $tmp
products=`ls | grep libopus | grep iPhoneOS`
echo "generating $fatProductIos from ${products} ..." 
lipo -create ${products} -output $fatProductIos
products=`ls | grep libopus | grep iPhoneSimulator`
echo "generating $fatProductSimulatorIos from ${products} ..." 
lipo -create ${products} -output $fatProductSimulatorIos
cd $here
cp -v $tmp/$fatProductIos $fatLibsDest
lipo -info $fatLibsDest/$fatProductIos
cp -v $tmp/$fatProductSimulatorIos $fatLibsDest
lipo -info $fatLibsDest/$fatProductSimulatorIos
echo "$fatLibsDest/$fatProductIos generated."
echo "$fatLibsDest/$fatProductSimulatorIos generated."
echo "\n==========================="


echo "\n==========================="
cd $here
echo "copy headers into opus-swift.xcodeproj"
for f in $opusHeaders/*.h; do
    file=`basename $f`
    cp -v $f ./opus-swift/include
done
echo "opus-swift.xcodeproj is ready"
echo "done."

