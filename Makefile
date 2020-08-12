DISKNAME = disk3
MNTPOINT = ./mnt/

disk.img:
	qemu-img create -f raw disk.img 1440K
	make attach
	make format
	make detach

attach:
	hdiutil attach -nomount disk.img
	diskutil list

format:
	newfs_msdos -F 12 -I 0x19941226 -O "ZULINX  " -S 512 -a 9 -b 512 -c 1 -f 1440 -h 2 -n 2 -v "ZURIFD     " ${DISKNAME}

detach:
	hdiutil detach ${DISKNAME}
	diskutil list

stage1.img: stage1.asm
	nasm -o stage1.img stage1.asm

stage2.img: stage2.asm
	nasm -o stage2.img stage2.asm

img: stage1.img disk.img
	dd if=stage1.img of=disk.img bs=512 count=1 conv=notrunc

run:
	make img
	qemu-system-x86_64 -fda disk.img
