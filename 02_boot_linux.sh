#!/bin/bash
set -e
set -u

LOGFILE="../exploit.log"
echo "" > "${LOGFILE}"

pushd product
    echo "Exploiting Switch recovery mode and loading coreboot..."
    sudo ./shofel2.py cbfs.bin coreboot.rom >> "${LOGFILE}" 2>&1
    echo "Waiting for Switch to run coreboot..."
    sleep 5 # Give the Switch a few seconds to execute coreboot
    echo "Creating u-boot script image..."
    ./mkimage -A arm64 -T script -C none -n "boot.scr" -d switch.scr switch.scr.img >> "${LOGFILE}" 2>&1
    echo "Sending u-boot script..."
    sudo ./imx_usb -c . >> "${LOGFILE}" 2>&1
    echo "Switch should boot Linux momentarily."
popd
