#!/bin/bash
set -x
set -e
set -u

NPROC=$(grep -c ^processor /proc/cpuinfo)
export NPROC

CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE

SHA256_RYU_OPM=8f7df21829368e87123f55f8954f8b8edb52c0f77cb4a504c783dad7637dd8f4
ZIPNAME_RYU_OPM=ryu-opm1.171019.026-factory-8f7df218.zip
URL_RYU_OPM=https://dl.google.com/dl/android/aosp/ryu-opm1.171019.026-factory-8f7df218.zip

make() {
    /usr/bin/make -j"${NPROC}" "$@"
}

sha256() {
    sha256sum "$1" | awk '{ print $1 }'
}

fetch_tegra_ram_trainer() {
    echo "Checking Tegra RAM trainer blob..."
    cd /source
    if ! [ -f tegra_mtc.bin ]; then
        echo "Fetching Tegra RAM trainer blob..."
        if [ -f "${ZIPNAME_RYU_OPM}" ] && [ "$(sha256 "${ZIPNAME_RYU_OPM}")" != "${SHA256_RYU_OPM}" ]; then
            rm -rf ryu-opm1.171019.026*
        fi
        wget -N "${URL_RYU_OPM}"
        unzip "${ZIPNAME_RYU_OPM}"
        mv ryu-opm1.171019.026/bootloader-dragon-google_smaug.7900.97.0.img .
    fi
}

build_exploit() {
    echo "Building shofel2 exploit..."
    cd shofel2/exploit
    make
}

build_uboot() {
    echo "Building u-boot..."
    cd /source
    cd u-boot
    make nintendo-switch_defconfig
    make
}

build_recore() {
    echo "Building cbfstool..."
    cd /source
    cd librecore-utils
    mkdir build || true
    cd build
    cmake ..
    make
    #make install #needed?!
    #./build/util/cbfstool/cbfstool bootloader-dragon-google_smaug.7900.97.0.img extract -n fallback/tegra_mtc -f tegra_mtc.bin
}

build_coreboot() {
    echo "Building coreboot..."
    cd /source
    cd coreboot
    make nintendo_switch_defconfig
    make iasl
    pushd util/cbfstool
    make cbfstool
    popd

    if ! [ -f ../tegra_mtc.bin ]; then
        "  Extracting Tegra RAM trainer blob from Pixel C factory restore image..."
        ./util/cbfstool/cbfstool ../bootloader-dragon-google_smaug.7900.97.0.img extract -n fallback/tegra_mtc -f tegra_mtc.bin
        cp tegra_mtc.bin ..
    fi

    if ! [ -f tegra_mtc.bin ]; then
        cp ../tegra_mtc.bin .
    fi

    if [ "$(sha256 tegra_mtc.bin)" -ne "edb32e3f9ed15b55e780e8a01ef927a3b8a1f25b34a6f95467041d8953777d21" ]; then
        echo "ERROR: tegra_mtc.bin does not match stored SHA256 sum"
        exit 1
    fi

    make
}

build_imx_loader() {
    echo "Building imx loader..."
    cd /source
    cd imx_usb_loader
    # why?
    # git reset --hard 0a322b01cacf03e3be727e3e4c3d46d69f2e343e
    make
}

build_linux() {
    echo "Building Linux..."
    cd /source
    cd linux
    export ARCH=arm64
    export CROSS_COMPILE=aarch64-linux-gnu- #useless
    make nintendo-switch_defconfig
    make
}

build_all() {
    fetch_tegra_ram_trainer
    build_exploit
    build_uboot
#    build_recore
    build_coreboot
    build_imx_loader
    build_linux
}

build_all
