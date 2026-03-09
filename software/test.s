	.file	"test.c"
	.option nopic
	.attribute arch, "rv32i2p1"
	.attribute unaligned_access, 0
	.attribute stack_align, 16
	.text
	.section	.text.startup,"ax",@progbits
	.align	2
	.globl	main
	.type	main, @function
main:
	li	a4,2498560
	addi	sp,sp,-16
	li	a3,4096
	li	a2,4
	addi	a4,a4,1439
.L6:
	sw	a2,0(a3)
	sw	zero,8(sp)
	lw	a5,8(sp)
	bgt	a5,a4,.L2
.L3:
	lw	a5,8(sp)
	addi	a5,a5,1
	sw	a5,8(sp)
	lw	a5,8(sp)
	ble	a5,a4,.L3
.L2:
	sw	zero,0(a3)
	sw	zero,12(sp)
	lw	a5,12(sp)
	bgt	a5,a4,.L6
.L5:
	lw	a5,12(sp)
	addi	a5,a5,1
	sw	a5,12(sp)
	lw	a5,12(sp)
	ble	a5,a4,.L5
	j	.L6
	.size	main, .-main
	.ident	"GCC: (13.2.0-11ubuntu1+12) 13.2.0"
