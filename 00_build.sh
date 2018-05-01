#!/bin/bash
#set -x
set -e
set -u

# Global variables
NPROC=$(grep -c ^processor /proc/cpuinfo)
export NPROC

CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE

ROOTDIR=/source

# Pixel C factory image metadata
SHA256_RYU_OPM=8f7df21829368e87123f55f8954f8b8edb52c0f77cb4a504c783dad7637dd8f4
SHA256_SMAUG=ed121ba1f5dbbf756f2b0b559fef97b2def88afa9217916686aa88c8c2760ce9
URL_RYU_OPM=https://dl.google.com/dl/android/aosp/ryu-opm1.171019.026-factory-8f7df218.zip
ZIPNAME_RYU_OPM=ryu-opm1.171019.026-factory-8f7df218.zip
DIRNAME_RYU_OPM=ryu-opm1.171019.026
IMGNAME_SMAUG=bootloader-dragon-google_smaug.7900.97.0.img

# Helper functions
make() {
    /usr/bin/make -j"${NPROC}" "$@"
}

sha256() {
    sha256sum "$1" | awk '{ print $1 }'
}

copy_products() {
    for product in "$@" ; do
        cp "${product}" "${ROOTDIR}/product"
    done
}

# FIXME: Add a function here that prints things in green, to replace our echo calls below

# Get ourselves in the right place
cd "${ROOTDIR}"

fetch_tegra_ram_trainer() {
    echo "Checking Tegra RAM trainer blob..."
    pushd "${ROOTDIR}/vendor"
    if ! [ -f tegra_mtc.bin ]; then
        echo "Fetching Tegra RAM trainer blob..."
        if ! [ -f "${ZIPNAME_RYU_OPM}" ] || [ "$(sha256 "${ZIPNAME_RYU_OPM}")" != "${SHA256_RYU_OPM}" ]; then
            rm -rf "${DIRNAME_RYU_OPM}" "${ZIPNAME_RYU_OPM}"
            wget "${URL_RYU_OPM}"
        fi
        if ! [ -f "${DIRNAME_RYU_OPM}/${IMGNAME_SMAUG}" ] || [ "$(sha256 "${DIRNAME_RYU_OPM}/${IMGNAME_SMAUG}")" != "${SHA256_SMAUG}" ]; then
            rm -rf "${DIRNAME_RYU_OPM}"
            unzip "${ZIPNAME_RYU_OPM}"
        fi
    fi
    popd
}

build_exploit() {
    echo "Building shofel2 exploit..."
    pushd "${ROOTDIR}/shofel2/exploit"
    make
    copy_products shofel2.py cbfs.bin
    popd
    pushd "${ROOTDIR}/shofel2/usb_loader"
    copy_products switch.scr switch.conf imx_usb.conf
    popd
}

build_uboot() {
    echo "Building u-boot..."
    pushd "${ROOTDIR}/u-boot"
    make nintendo-switch_defconfig
    make
    copy_products tools/mkimage
    popd
}

build_coreboot() {
    echo "Building coreboot..."
    pushd "${ROOTDIR}/coreboot"
    make distclean # coreboot doesn't seem to take kindly to being rebuilt without a good clean first
    make nintendo_switch_defconfig
    make iasl
    pushd util/cbfstool
    make cbfstool
    popd

    if ! [ -f ../vendor/tegra_mtc.bin ]; then
        echo "  Extracting Tegra RAM trainer blob from Pixel C factory restore image..."
        ./util/cbfstool/cbfstool "../vendor/${DIRNAME_RYU_OPM}/${IMGNAME_SMAUG}" extract -n fallback/tegra_mtc -f tegra_mtc.bin
        cp tegra_mtc.bin ../vendor
    fi

    if ! [ -f tegra_mtc.bin ]; then
        cp ../vendor/tegra_mtc.bin .
    fi

    if [ "$(sha256 tegra_mtc.bin)" != "edb32e3f9ed15b55e780e8a01ef927a3b8a1f25b34a6f95467041d8953777d21" ]; then
        echo "ERROR: tegra_mtc.bin does not match stored SHA256 sum"
        exit 1
    fi

    make
    copy_products build/coreboot.rom
    popd
}

build_imx_loader() {
    echo "Building imx loader..."
    pushd "${ROOTDIR}/imx_usb_loader"
    make
    copy_products imx_usb
    popd
}

build_linux() {
    echo "Building Linux..."
    pushd "${ROOTDIR}/linux"
    export ARCH=arm64
    make nintendo-switch_defconfig
    make
    copy_products arch/arm64/boot/Image.gz arch/arm64/boot/dts/nvidia/tegra210-nintendo-switch.dtb
    popd
}

# FIXME: Add a rootfs builder here

build_all() {
    fetch_tegra_ram_trainer
    build_exploit
    build_uboot
    build_coreboot
    build_imx_loader
    build_linux
}

build_all
