disk.img:
	qemu-img create -f raw disk.img 1440K

stage1.img: stage1.asm
	nasm -o stage1.img stage1.asm

img: stage1.img disk.img
	dd if=stage1.img of=disk.img bs=512 count=1 conv=notrunc

run:
	make img
	qemu-system-x86_64 -fda disk.img
