# Makefile for automatic VPS installation. Designed for running from Arch iso.
SHELL := bash

ETC_FILES :=
MISC_FILES :=
MOUNT_POINT ?= /mnt
RUN_IN_CHROOT := arch-chroot $(MOUNT_POINT)

define disk_error_msg
You need to specify a disk. (ex. DISK=/dev/sda)
Additionally, if you haven't erased your disk you must use `parted -s $$DISK mktable gpt` in order to re-create your partition table.
endef
ifeq ($(DISK),)
$(error $(disk_error_msg))
endif

# A target that forces the runner of Makefile to at least know which target they
# are triggering.
dummy:
	echo "Please specify a target." && false

$(DISK)1:
	parted -a optimal -s $(DISK) mkpart bootloader 34s 2047s
	parted -s $(DISK) set 1 bios_grub on

$(DISK)2:
	parted -a optimal -s $(DISK) mkpart primary ext4 2048s 100%
	yes | mkfs.ext4 -q $(DISK)2

# Canary to see if the mount point is mounted.
$(MOUNT_POINT)/root:
	@:

$(MOUNT_POINT): $(DISK)2 $(MOUNT_POINT)/root
	mount $(DISK)2 $(MOUNT_POINT)
	pacstrap $(MOUNT_POINT) base linux-hardened linux-firmware openssh grub dhcpcd
	$(RUN_IN_CHROOT) systemctl enable dhcpcd
	$(RUN_IN_CHROOT) systemctl enable sshd
	$(RUN_IN_CHROOT) passwd -l root

ETC_FILES += $(MOUNT_POINT)/etc/fstab
$(MOUNT_POINT)/etc/fstab: $(DISK)1 $(DISK)2 $(MOUNT_POINT)
	genfstab -U $(MOUNT_POINT) >> $(MOUNT_POINT)/etc/fstab

ETC_FILES += $(MOUNT_POINT)/etc/locale.conf
$(MOUNT_POINT)/etc/locale.conf: $(MOUNT_POINT)
	echo "LANG=en_US.UTF-8" > $(MOUNT_POINT)/etc/locale.conf
	echo "LC_TIME=en_DK.UTF-8" >> $(MOUNT_POINT)/etc/locale.conf
	echo "en_US.UTF-8 UTF-8" > $(MOUNT_POINT)/etc/locale.gen
	echo "en_DK.UTF-8 UTF-8" >> $(MOUNT_POINT)/etc/locale.gen
	$(RUN_IN_CHROOT) locale-gen

ETC_FILES += $(MOUNT_POINT)/etc/localtime
$(MOUNT_POINT)/etc/localtime: $(MOUNT_POINT)
	ln -sf $(MOUNT_POINT)/usr/share/zoneinfo/UTC $(MOUNT_POINT)/etc/localtime
	$(RUN_IN_CHROOT) hwclock --systohc

MISC_FILES += $(MOUNT_POINT)/root/.ssh/authorized_keys
$(MOUNT_POINT)/root/.ssh/authorized_keys: $(MOUNT_POINT)
	@mkdir -p $(MOUNT_POINT)/root/.ssh
	@cp ~/.ssh/authorized_keys $(MOUNT_POINT)/root/.ssh/authorized_keys || echo "Failed to copy SSH keys to target. Please do so before rebooting."

MISC_FILES += $(MOUNT_POINT)/boot/grub/grub.cfg
$(MOUNT_POINT)/boot/grub/grub.cfg: $(MOUNT_POINT)
	# TODO: use additional conf files instead of editing /etc/default/grub.
	sed -i -r -e "s/GRUB_TIMEOUT=[0-9.]*/GRUB_TIMEOUT=0/g" $(MOUNT_POINT)/etc/default/grub
	sed -i -r -e "s/GRUB_HIDDEN_TIMEOUT=[0-9.]*/#GRUB_HIDDEN_TIMEOUT=0.0/g" $(MOUNT_POINT)/etc/default/grub
	$(RUN_IN_CHROOT) grub-install --target=i386-pc $(DISK)
	$(RUN_IN_CHROOT) grub-mkconfig -o /boot/grub/grub.cfg

all: $(ETC_FILES) $(MISC_FILES)
	@touch all
	@echo "Installation complete."
