# Amlogic

## Build SD Image
```
git clone https://github.com/libre-computer-project/libretech-amlogic.git --single-branch --branch suspend-resume/aml-a311d-cc
cd libretech-amlogic
./setup.sh
./build.sh
sudo dd if=sdcard.img of=/dev/mmcblk0 bs=1M
```

## Operation

1. Move the MMC/SPI switch to the MMC position. Please note some early boards are marked incorrectly so try both.
2. Connect UART cable to the 3-pin header next to the 40-pin header.
3. Insert the MicroSD card into the board.
4. Attach Type-C power.
5. Board will boot and run minimal Linux initramfs.
6. Manually trigger suspend via `echo mem > /sys/power/state`.
7. Observe UART output.
8. Wake board by sending space key over UART.
9. Linux should resume back to console if no glitch.

## Automated Script

1. Use `suspend.sh`.

## Composition

* libretech-amlogic-boot: LAB provides and compiles Amlogic blx
* libretech-builder-simple: LBS compiles upstream u-boot and signs with Amlogic blx tools
* libretech-buildroot: LBR compiles upstream buildroot with a minimal Linux and generates flashable images
* build.sh: glue code to link output and input between components

