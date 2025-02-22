# Detected Variables
CORES 					:= $(shell nproc)
BASE 						:= $(shell pwd)
SYS_ARCH 				:= $(shell uname -p)
SHELL 					:= /bin/bash

# Config Variables
ARCH						= x86
LINUX_DIR				= linux
LINUX_CFG				= $(LINUX_DIR)/.config
BUSYBOX_DIR			= busybox
BUSYBOX_CFG			= $(BUSYBOX_DIR)/.config
NANO_DIR        = nano
FILES_DIR				= files
FILESYSTEM_DIR	= filesystem
MOUNT_POINT			= /mnt/disk
INITTAB					= $(FILES_DIR)/inittab
RC							= $(FILES_DIR)/rc
SYSLINUX_CFG		= $(FILES_DIR)/syslinux.cfg
TOOLCHAIN_DIR		= i486-linux-musl-cross
WELCOME					= $(FILES_DIR)/welcome
ROOTFS_SIZE			= 1440

# Generated Files
KERNEL					= bzImage
ROOTFS					= rootfs.cpio.xz
FSIMAGE					= floppinux.img

# Recipe Files
BZIMAGE					= $(LINUX_DIR)/arch/$(ARCH)/boot/$(KERNEL)
INIT						= $(FILESYSTEM_DIR)/sbin/init

.SILENT: download_toolchain

.PHONY: all allconfig rebuild test_filesystem test_floppy_image size clean clean_linux clean_busybox clean_filesystem

base: get_linux compile_linux download_toolchain get_busybox compile_busybox

create_floppy_image: make_rootfs make_floppy_image

all: base create_floppy_image

allconfig: get_linux configure_linux compile_linux download_toolchain get_busybox configure_busybox \
		compile_busybox make_rootfs make_floppy_image

with_nano: base get_nano compile_nano create_floppy_image

rebuild: clean_filesystem compile_linux compile_busybox make_rootfs make_floppy_image

cleanbuild: clean compile_linux compile_busybox make_rootfs make_floppy_image

get_linux:
ifneq ($(wildcard $(LINUX_DIR)),)
	@echo "Linux directory found, pulling latest changes..."
	cd $(LINUX_DIR) && git pull
else
	@echo "Linux directory not found, cloning repo..."
	git clone --depth=1 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git $(LINUX_DIR)
	cp $(FILES_DIR)/linux-config $(LINUX_CFG)
endif

configure_linux:
	$(MAKE) ARCH=x86 -C $(LINUX_DIR) mrproper
	$(MAKE) ARCH=x86 -C $(LINUX_DIR) tinyconfig
	$(MAKE) ARCH=x86 -C $(LINUX_DIR) menuconfig

compile_linux:
	$(MAKE) ARCH=x86 -C $(LINUX_DIR) -j $(CORES) $(KERNEL)
	@echo Kernel size
	ls -la $(BZIMAGE)
	cp $(BZIMAGE) .

download_toolchain:
ifeq ($(SYS_ARCH),x86_64)
	if [ ! -d $(TOOLCHAIN_DIR) ]; then \
	echo "Downloading musl toolchain..."; \
	wget https://musl.cc/i486-linux-musl-cross.tgz; \
	tar xf i486-linux-musl-cross.tgz; \
	fi
else
	echo "Compiling on i386, toolchain not needed"
endif

get_busybox:
ifneq ($(wildcard $(BUSYBOX_DIR)),)
	@echo "Busybox directory found, pulling latest changes..."
	cd $(BUSYBOX_DIR) && git pull
else
	@echo "Busybox directory not found, cloning repo..."
	git clone https://git.busybox.net/busybox/ $(BUSYBOX_DIR)
endif

configure_busybox:
	cp $(FILES_DIR)/busybox-config $(BUSYBOX_CFG)
	$(MAKE) ARCH=x86 -C $(BUSYBOX_DIR) allnoconfig
	$(MAKE) ARCH=x86 -C $(BUSYBOX_DIR) menuconfig

compile_busybox:
ifeq ($(SYS_ARCH),x86_64)
	@sed -i "s|.*CONFIG_CROSS_COMPILER_PREFIX.*|CONFIG_CROSS_COMPILER_PREFIX="\"$(BASE)"/i486-linux-musl-cross/bin/i486-linux-musl-\"|" $(BUSYBOX_DIR)/.config
	@sed -i "s|.*CONFIG_SYSROOT.*|CONFIG_SYSROOT=\""$(BASE)"/i486-linux-musl-cross\"|" $(BUSYBOX_DIR)/.config
	@sed -i "s|.*CONFIG_EXTRA_CFLAGS.*|CONFIG_EXTRA_CFLAGS=\"-I"$(BASE)"/i486-linux-musl-cross/include\"|" $(BUSYBOX_DIR)/.config
	@sed -i "s|.*CONFIG_EXTRA_LDFLAGS.*|CONFIG_EXTRA_LDFLAGS=\"-L"$(BASE)"/i486-linux-musl-cross/lib\"|" $(BUSYBOX_DIR)/.config
endif
	$(MAKE) ARCH=x86 -C $(BUSYBOX_DIR) -j $(CORES)
	$(MAKE) ARCH=x86 -C $(BUSYBOX_DIR) install
	mv $(BUSYBOX_DIR)/_install $(FILESYSTEM_DIR)

get_nano:
ifneq ($(wildcard $(BUSYBOX_DIR)),)
	@echo "Nano directory found, removing folder..."
	rm -rf $(NANO_DIR)
endif

	mkdir -p $(NANO_DIR)
	wget -c https://www.nano-editor.org/dist/v6/nano-6.2.tar.xz -O $(NANO_DIR)/nano-6.2.tar.xz
	tar -xvf $(NANO_DIR)/nano-6.2.tar.xz -C $(NANO_DIR)/
	mv -f $(NANO_DIR)/nano-6.2/* $(NANO_DIR) # TODO: Fix this

compile_nano:
	cd $(NANO_DIR) && ./configure --enable-tiny
	$(MAKE) ARCH=x86 -C $(NANO_DIR) -j $(CORES)
	mkdir -p $(FILESYSTEM_DIR)/bin
	mv $(NANO_DIR)/src/nano $(FILESYSTEM_DIR)/bin

make_rootfs:
	mkdir -p $(FILESYSTEM_DIR)/{dev,proc,etc/init.d,sys,tmp}
	sudo mknod $(FILESYSTEM_DIR)/dev/console c 5 1
	sudo mknod $(FILESYSTEM_DIR)/dev/null c 1 3
	cp $(INITTAB) $(FILESYSTEM_DIR)/etc/
	cp $(RC) $(FILESYSTEM_DIR)/etc/init.d/
	cp $(WELCOME) $(FILESYSTEM_DIR)/
	chmod +x $(FILESYSTEM_DIR)/etc/init.d/rc
	sudo chown -R root:root $(FILESYSTEM_DIR)/
	cd $(FILESYSTEM_DIR); find . | cpio -H newc -o | xz --check=crc32 > ../$(ROOTFS)

make_floppy_image:
	dd if=/dev/zero of=$(FSIMAGE) bs=1k count=$(ROOTFS_SIZE)
	mkdosfs $(FSIMAGE)
	syslinux --install $(FSIMAGE)
	sudo mkdir -p $(MOUNT_POINT)
	sudo mount -o loop $(FSIMAGE) $(MOUNT_POINT)
	sudo cp $(KERNEL) $(ROOTFS) $(SYSLINUX_CFG) $(MOUNT_POINT)
	sync
	sudo umount $(MOUNT_POINT)

test_filesystem:
	qemu-system-i386 -kernel $(KERNEL) -initrd $(ROOTFS)

test_floppy_image:
	qemu-system-i386 -fda $(FSIMAGE)

size:
	sudo mount -o loop $(FSIMAGE) $(MOUNT_POINT)
	df -h $(MOUNT_POINT)
	ls -lah $(MOUNT_POINT)
	sudo umount $(MOUNT_POINT)

clean: clean_linux clean_busybox clean_nano clean_filesystem

clean_linux:
	$(MAKE) -C $(LINUX_DIR) clean
	rm -f $(KERNEL)

clean_busybox:
	$(MAKE) -C $(BUSYBOX_DIR) clean

clean_nano:
	rm -rf $(NANO_DIR)
	rm -f $(FILESYSTEM_DIR)/nano

clean_filesystem:
	sudo rm -rf $(FILESYSTEM_DIR)
	rm -f $(FSIMAGE) $(ROOTFS)

reset: clean_filesystem
	sudo rm -rf $(LINUX_DIR) $(BUSYBOX_DIR) $(TOOLCHAIN_DIR) i486-linux-musl-cross.tgz
