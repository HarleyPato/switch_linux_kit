### Unofficial Ubuntu builder for Nintendo Switch

This repo allows you to build the exploit, bootloaders, kernel and root filesystem for running Ubuntu on a Nintendo Switch.

Note that this is an unofficial project and is not connected to, or endorsed by, Ubuntu. All trademarks are deeply loved.

Also note that the [build toolchain](https://hub.docker.com/r/cmsj/aarch64_toolchain/) is based around Docker, so you should have Docker installed.

### Preparation

```
docker pull cmsj/aarch64_toolchain
git clone https://github.com/cmsj/switch_linux_kit
cd switch_linux_kit
```

### Compiling

```
modprobe binfmt_misc
docker run --privileged -ti --rm -v/dev:/dev -v$(pwd):/source cmsj/aarch64_toolchain bash 00_build.sh
```

The build script is pretty modular, so with some simple edits you could choose to build just the exploit chain, bootloader, kernel, rootfs, etc. if you so desire.

So far this has only been tested on a CentOS 7 host, please report issues/success with other distros.

### Micro SD Card Preparation

You need a microSD card for Linux, which you can prepare with these steps:

* Use a tool that can write disk images (e.g. dd or Etch)
* Unzip `sd.img.gz` and write it to the SD card

Notes:

* The Linux partition on the SD card is quite small, quite full and does not resize itself automatically. This will be fixed soon.
* The Linux partition contains both the kernel and device tree (the `.dtb` file) in `/boot/` and the exploit chain produced by this builder expects to find them there (ie you can't use a f0f exploit chain obtained elsewhere that is expecting to send `Image.gz` and the `.dtb` file over USB)

### Running

Attach your Switch to USB, trigger the hardware exploit (ie short pin 10 of the right joycon slot, to ground), and run:

```
cd products/exploit/
sudo ./boot_linux.sh
```

(If you want to run the exploit from a separate host to your build host, you'll find `exploit.tar.gz` in `products/` with all of the scripts, executables and data that are needed)
