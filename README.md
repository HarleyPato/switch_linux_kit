### Switch Linux Kit
Build Linux for Nintendo Switch from Sourcecode using [Docker Toolchain](https://hub.docker.com/r/nold360/switch_linux_toolchain/)

### Cloning
```
git clone https://github.com/cmsj/switch_linux_kit
cd switch_linux_kit
git submodule update --init
```

### Compiling
```
docker run -ti --rm -v$(pwd):/source cmsj/aarch64_toolchain bash 00_build.sh
```

### Profit!
***Note:*** You still need to prepare a rootfs SD-Card like described [here](https://github.com/fail0verflow/shofel2)

Then simply run the exploit & uboot-scripts:
```
bash -x 02_exploit.sh
bash -x 03_uboot.sh

```
