#!/bin/bash
set -e
set -u

pushd product
    sudo ./shofel2.py cbfs.bin coreboot.rom
    sleep 5 # Give the Switch a few seconds to execute coreboot
    ./mkimage -A arm64 -T script -C none -n "boot.scr" -d switch.scr switch.scr.img
    sudo ./imx_usb -c . # This command needs root or permissions to access usb devices
popd
