#!/bin/bash
#set -x
set -eE
set -u

# Global variables
CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE

ROOTDIR=/source
BUILDLOG="${ROOTDIR}/build.log"
echo "" > "${BUILDLOG}"

function build_failed() {
    echo "ERROR: Build failed. Build log follows:"
    cat "${BUILDLOG}"
}

trap build_failed ERR

NPROC=$(grep -c ^processor /proc/cpuinfo)
export NPROC

# Pixel C factory image metadata
SHA256_RYU_OPM=8f7df21829368e87123f55f8954f8b8edb52c0f77cb4a504c783dad7637dd8f4
SHA256_SMAUG=ed121ba1f5dbbf756f2b0b559fef97b2def88afa9217916686aa88c8c2760ce9
URL_RYU_OPM=https://dl.google.com/dl/android/aosp/ryu-opm1.171019.026-factory-8f7df218.zip
ZIPNAME_RYU_OPM=ryu-opm1.171019.026-factory-8f7df218.zip
DIRNAME_RYU_OPM=ryu-opm1.171019.026
IMGNAME_SMAUG=bootloader-dragon-google_smaug.7900.97.0.img

TSFMT='[%Y-%m-%d %H:%M:%S]'

# Helper functions
make() {
    /usr/bin/make -j"${NPROC}" "$@" | ts "${TSFMT}" >> "${BUILDLOG}" 2>&1
}

sha256() {
    sha256sum "$1" | awk '{ print $1 }'
}

copy_products() {
    for product in "$@" ; do
        cp -v "${product}" "${ROOTDIR}/product" | ts "${TSFMT}" >> "${BUILDLOG}"
    done
}

mypushd() {
    pushd "$1" >> "${BUILDLOG}" 2>&1
}

mypopd() {
    popd  >> "${BUILDLOG}" 2>&1
}

myecho() {
    echo "$@" | ts "${TSFMT}" | tee -a "${BUILDLOG}"
}

# Get ourselves in the right place
cd "${ROOTDIR}"

fetch_tegra_ram_trainer() {
    myecho "Checking Tegra RAM trainer blob..."
    mypushd "${ROOTDIR}/vendor"
        if ! [ -f tegra_mtc.bin ]; then
            if ! [ -f "${ZIPNAME_RYU_OPM}" ] || [ "$(sha256 "${ZIPNAME_RYU_OPM}")" != "${SHA256_RYU_OPM}" ]; then
                myecho "Fetching Tegra RAM trainer blob..."
                rm -rf "${DIRNAME_RYU_OPM}" "${ZIPNAME_RYU_OPM}"
                wget "${URL_RYU_OPM}" | ts "${TSFMT}" >> "${BUILDLOG}"
            fi
            if ! [ -f "${DIRNAME_RYU_OPM}/${IMGNAME_SMAUG}" ] || [ "$(sha256 "${DIRNAME_RYU_OPM}/${IMGNAME_SMAUG}")" != "${SHA256_SMAUG}" ]; then
                myecho "Unpacking Tegra RAM trainer blob..."
                rm -rf "${DIRNAME_RYU_OPM}"
                unzip "${ZIPNAME_RYU_OPM}" | ts "${TSFMT}" >> "${BUILDLOG}"
            fi
        fi
    mypopd
}

build_exploit() {
    myecho "Building shofel2 exploit..."
    mypushd "${ROOTDIR}/shofel2/exploit"
        make
        copy_products shofel2.py cbfs.bin
    mypopd
    mypushd "${ROOTDIR}/shofel2/usb_loader"
        copy_products switch.scr switch.conf imx_usb.conf
    mypopd
}

build_uboot() {
    myecho "Building u-boot..."
    mypushd "${ROOTDIR}/u-boot"
        make nintendo-switch_defconfig
        make
        copy_products tools/mkimage
    mypopd
}

build_coreboot() {
    myecho "Building coreboot..."
    mypushd "${ROOTDIR}/coreboot"
        make distclean # coreboot doesn't seem to take kindly to being rebuilt without a good clean first
        make nintendo_switch_defconfig
        make iasl
        mypushd util/cbfstool
            make cbfstool
        mypopd

        if ! [ -f ../vendor/tegra_mtc.bin ]; then
            myecho "  Extracting Tegra RAM trainer blob from Pixel C factory restore image..."
            ./util/cbfstool/cbfstool "../vendor/${DIRNAME_RYU_OPM}/${IMGNAME_SMAUG}" extract -n fallback/tegra_mtc -f tegra_mtc.bin | ts "${TSFMT}" >> "${BUILDLOG}"
            cp tegra_mtc.bin ../vendor
        fi

        if ! [ -f tegra_mtc.bin ]; then
            cp ../vendor/tegra_mtc.bin .
        fi

        if [ "$(sha256 tegra_mtc.bin)" != "edb32e3f9ed15b55e780e8a01ef927a3b8a1f25b34a6f95467041d8953777d21" ]; then
            myecho "ERROR: tegra_mtc.bin does not match stored SHA256 sum"
            exit 1
        fi

        make
        copy_products build/coreboot.rom
    mypopd
}

build_imx_loader() {
    myecho "Building imx loader..."
    mypushd "${ROOTDIR}/imx_usb_loader"
        make
        copy_products imx_usb
    mypopd
}

build_linux() {
    myecho "Building Linux..."
    mypushd "${ROOTDIR}/linux"
        export ARCH=arm64
        make nintendo-switch_defconfig
        make
        copy_products arch/arm64/boot/Image.gz arch/arm64/boot/dts/nvidia/tegra210-nintendo-switch.dtb
    mypopd
}

build_rootfs() {
    myecho "Building Ubuntu filesystem..."
    mkdir -p "${ROOTDIR}/rootfs"
    mypushd "${ROOTDIR}/rootfs"
        sudo ../ubuntu_builder/build-image.sh .
    mypopd
}

build_all() {
    fetch_tegra_ram_trainer
    build_exploit
    build_uboot
    build_coreboot
    build_imx_loader
    build_linux
    build_rootfs
}

build_all
