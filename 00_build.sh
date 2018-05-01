#!/bin/bash
set -x
set -e
set -u

NPROC=$(grep -c ^processor /proc/cpuinfo)
export NPROC

fetch_tegra_ram_trainer() {
    echo "Checking Tegra RAM trainer blob..."
    cd /source
    if ! [ -f tegra_mtc.bin ]; then
        echo "Fetching Google Pixel C factory restore image for Tegra RAM trainer blob..."
        rm -f ryu-opm1.171019.026-factory-8f7df218.zip
        wget https://dl.google.com/dl/android/aosp/ryu-opm1.171019.026-factory-8f7df218.zip
        unzip ryu-opm1.171019.026-factory-8f7df218.zip
        mv ryu-opm1.171019.026/bootloader-dragon-google_smaug.7900.97.0.img .
    fi
}

build_exploit() {
    echo "Building shofel2 exploit..."
    cd shofel2/exploit
    make -j"${NPROC}"
}

build_uboot() {
    echo "Building u-boot..."
    cd /source
    cd u-boot
    export CROSS_COMPILE=aarch64-linux-gnu-
    make nintendo-switch_defconfig
    make -j"${NPROC}"
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
    make util/cbfstool/cbfstool

    if ! [ -f ../tegra_mtc.bin ]; then
        "  Extracting Tegra RAM trainer blob from Pixel C factory restore image..."
        ./util/cbfstool/cbfstool ../bootloader-dragon-google_smaug.7900.97.0.img extract -n fallback/tegra_mtc -f tegra_mtc.bin
        cp tegra_mtc.bin ..
    fi

    if ! [ -f tegra_mtc.bin ]; then
        cp ../tegra_mtc.bin .
    fi

    if [ "$(sha256sum tegra_mtc.bin | awk '{ print $1 }')" -ne "edb32e3f9ed15b55e780e8a01ef927a3b8a1f25b34a6f95467041d8953777d21" ]; then
        echo "ERROR: tegra_mtc.bin does not match stored SHA256 sum"
        exit 1
    fi

    make iasl
    make -j"${NPROC}"
}

build_imx_loader() {
    echo "Building imx loader..."
    cd /source
    cd imx_usb_loader
    # why?
    # git reset --hard 0a322b01cacf03e3be727e3e4c3d46d69f2e343e
    make -j"${NPROC}"
}

build_linux() {
    echo "Building Linux..."
    cd /source
    cd linux
    export ARCH=arm64
    export CROSS_COMPILE=aarch64-linux-gnu- #useless
    make nintendo-switch_defconfig
    make -j"${NPROC}"
}

build_all() {
    build_exploit
    build_uboot
#    build_recore
    build_coreboot
    build_imx_loader
    build_linux
}
