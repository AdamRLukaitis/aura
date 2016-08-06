# Makefile for Aura

CSOURCES=kernel/gdt kernel/idt kernel/kernel kernel/liballoc kernel/log kernel/ports kernel/acpi \
implementation/implementation \
modules/clock/clock modules/clock/pit modules/clock/rtc \
modules/keyboard/keyboard modules/keyboard/ps2 \
modules/screen/screen modules/screen/vga \
utils/utils
ASOURCES=kernel/gdtasm kernel/idtasm boot/boot
MSOURCES=mish/main

LIBS=feta mish

-include ../make-base/make-base.mk

MOBJECTS=$(patsubst %, build/%.o, $(MSOURCES))
OBJECTS:=$(OBJECTS) $(MOBJECTS) build/boot/uefi.o

all: $(OBJECTS)

build/%.o: src/%.mish | $$(dir $$@)/.dirstamp
	objcopy -I binary -O elf32-i386 -B i386 --rename-section .data=.mish $^ $@

build/boot/uefi.o: src/boot/uefi.c | build/boot/.dirstamp
	gcc src/boot/uefi.c           \
		-c                        \
		-fno-stack-protector      \
		-fpic                     \
		-fshort-wchar             \
		-mno-red-zone             \
		-I gnu-efi/headers        \
		-I gnu-efi/headers/x86_64 \
		-DEFI_FUNCTION_WRAPPER    \
		-o build/boot/uefi.o

build/uefi.so: build/boot/uefi.o | build/.dirstamp
	ld build/boot/uefi.o              \
		gnu-efi/crt0-efi-x86_64.o     \
		-nostdlib                     \
		-znocombreloc                 \
		-T gnu-efi/elf_x86_64_efi.lds \
		-shared                       \
		-Bsymbolic                    \
		-L gnu-efi/libs               \
		-l:libgnuefi.a                \
		-l:libefi.a                   \
		-o build/uefi.so

build/aura.efi: build/uefi.so | build/.dirstamp
	objcopy -j .text            \
		-j .sdata               \
		-j .data                \
		-j .dynamic             \
		-j .dynsym              \
		-j .rel                 \
		-j .rela                \
		-j .reloc               \
		--target=efi-app-x86_64 \
		build/uefi.so           \
		build/aura.efi
		
# ---- output files ----

.PHONY:
img: build/aura.img
build/aura.img: build/aura.efi | build/.dirstamp
	dd if=/dev/zero of=build/aura.img bs=512 count=93750 # allocate disk
	parted build/aura.img -s -a minimal mklabel gpt # make gpt table
	parted build/aura.img -s -a minimal mkpart EFI FAT16 2048s 93716s # make EFI partition
	parted build/aura.img -s -a minimal toggle 1 boot # make it bootable
	dd if=/dev/zero of=/tmp/part.img bs=512 count=91669 # allocate partition
	mformat -i /tmp/part.img -h 32 -t 32 -n 64 -c 1 # format partition
	
	if [ -d "build/img_root" ]; then rm -r build/img_root; fi
	
	# build FS structure
	mkdir build/img_root
	mkdir build/img_root/EFI
	mkdir build/img_root/EFI/BOOT
	cp build/aura.efi build/img_root/EFI/BOOT/BOOTX64.efi # hard coded file name and path
	
	mcopy -s -i /tmp/part.img build/img_root/* :: # copy FS to partition
	dd if=/tmp/part.img of=build/aura.img bs=512 count=91669 seek=2048 conv=notrunc # copy parition to disk
	rm /tmp/part.img # remove tmp partition file

.PHONY:
vdi: build/aura.vdi
build/aura.vdi: build/aura.img
	vboxmanage convertfromraw --format VDI build/aura.img build/aura.vdi

#.PHONY:
#iso: build/aura.iso
#build/aura.iso: build/aura.elf
#	cp build/aura.elf iso/boot/aura.elf
#	genisoimage -R                        \
#		-b boot/grub/stage2_eltorito      \
#		-no-emul-boot                     \
#		-boot-load-size 4                 \
#		-A os                             \
#		-input-charset utf8               \
#		-quiet                            \
#		-boot-info-table                  \
#		-o build/aura.iso                 \
#		iso
	
# ---- running ----

.PHONY:
run: private DFLAGS = $(if $(DEBUGGING),-s -S)
run: img
	qemu-system-x86_64 -serial stdio $(DFLAGS) -cpu qemu64 -bios OVMF.fd -drive file=build/aura.img,if=ide