### Unofficial Ubuntu builder for Nintendo Switch
This repo allows you to build the exploit, bootloaders, kernel and root filesystem for running Ubuntu on a Nintendo Switch.

Note that this is an unofficial project and is not connected to, or endorsed by, Ubuntu. All trademarks are deeply loved.

Also note that the [build toolchain](https://hub.docker.com/r/cmsj/aarch64_toolchain/) is based around Docker, so you should have Docker installed.

### Cloning
```
git clone https://github.com/cmsj/switch_linux_kit
cd switch_linux_kit
git submodule update --init --recursive
docker pull cmsj/aarch64_toolchain
```

### Compiling
```
docker run --privileged -ti --rm -v/dev:/dev -v$(pwd):/source cmsj/aarch64_toolchain bash 00_build.sh
```

The build script is pretty modular, so with some simple edits you could choose to build just the exploit chain, bootloader, kernel, rootfs, etc. if you so desire.

### Micro SD Card Preparation

You need a microSD card with a Linux root filesystem on it (see previous step), and that rootfs needs to include the following files in /boot:
 * `Image.gz` (Linux kernel - found in `product/` after the build has finished)
 * `tegra210-nintendo-switch.dtb` (Device Tree binary - found in `product/` after the build has finished)

The steps for creating such a card would be:
 * Create a new Master Boot Record (MBR) on an SD card
 * Add a small (tens or hundreds of MB) FAT32 partition and format it
 * Fill the rest of the space with an ext4 partition and format it
 * Unpack product/rootfs.tgz onto the ext4 partition (e.g. tar xvf product/rootfs.tgz -C /path/to/SD/partition/)
 * Copy product/Image.gz and product/tegra210-nintendo-switch.dtb to /path/to/SD/partition/boot/
 * Unmount/eject the SD card and pop it in your Switch

Note that many of the community provided Linux rootfs images for the Switch do not include a kernel/DTB. You can add them yourself by mounting the SD card on a Linux machine and copying the two files from `product/` into `/path/to/SD/mount/boot/`

### Running

Attach your Switch to USB, trigger the hardware exploit (ie short pin 10 of the right joycon slot, to ground), and run:
```
cd products/exploit/
sudo ./boot_linux.sh

```

(If you want to run the exploit from a separate host to your build host, you'll find `exploit.tar.gz` in `products/` with all of the scripts, executables and data that are needed)
