boot.img: boot.asm
	nasm -o boot.img boot.asm

img: boot.img disk.img
	dd if=boot.img of=disk.img bs=512 count=1 conv=notrunc

run:
	make img
	qemu-system-x86_64 -fda disk.img
