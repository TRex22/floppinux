# FLOPPINUX 💾
![FLOPPINUX boot image](cover-0.2.1.jpg)

An Embedded 🐧Linux on a Single 💾Floppy

Homepage: https://bits.p1x.in/floppinux/


## Article/Tutorial
- creating distribution on 32-bit systems: https://bits.p1x.in/floppinux-an-embedded-linux-on-a-single-floppy/
- building on 64-bit systems: https://bits.p1x.in/how-to-build-32-bit-floppinux-on-a-64-bit-os/
- creating custom application (script based) https://bits.p1x.in/creating-sample-application-on-floppinux/

## EPUB Manual
Read only the manual:

- This repo https://github.com/w84death/floppinux/tree/main/manual
- Mirror https://archive.org/details/floppinux-manual/

## UPDATE 0.2.2
![FLOPPINUX Version 0.2.2](cover-0.2.2.jpg)

Code refactored. Smaller builds. Instructions for 64-bit host OS.
Read more at: https://bits.p1x.in/floppinux-0-2-2/

## Quick start
1. Install:
### Debian
`sudo apt install flex bison libncurses-dev qemu-system-x86 syslinux`
### Arch
`pacman -S flex bison libncurses-dev qemu-system-x86 syslinux mtools qemu-arch-extras `
2. Compile:
`make all`
3. Run:
### 386 compatibility
`qemu-system-i386 -fda floppinux.img`
`qemu-system-i386 -m 24 -fda -drive format=raw,file=floppinux.img`
`qemu-system-i386 -m 24 -drive format=raw,file=floppinux.img,index=0,if=floppy`

### Modern Compatibility
`qemu-system-x86_64 -m 24 -drive format=raw,file=floppinux.img,index=0,if=floppy`
