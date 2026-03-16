	.file	"blinky.c"
	.option nopic
	.attribute arch, "rv32i2p1"
	.attribute unaligned_access, 0
	.attribute stack_align, 16
	.text
	.align	2
	.globl	Order
	.type	Order, @function
Order:
	addi	sp,sp,-48
	sw	s0,44(sp)
	addi	s0,sp,48
	sw	a0,-36(s0)
	li	a5,4096
	lw	a3,0(a5)
	lw	a4,-36(s0)
	li	a5,4096
	add	a4,a3,a4
	sw	a4,0(a5)
	sw	zero,-20(s0)
	j	.L2
.L3:
	lw	a5,-20(s0)
	addi	a5,a5,1
	sw	a5,-20(s0)
.L2:
	lw	a4,-20(s0)
	li	a5,2498560
	addi	a5,a5,1439
	ble	a4,a5,.L3
	li	a5,4096
	lw	a3,0(a5)
	lw	a4,-36(s0)
	li	a5,4096
	sub	a4,a3,a4
	sw	a4,0(a5)
	nop
	lw	s0,44(sp)
	addi	sp,sp,48
	jr	ra
	.size	Order, .-Order
	.align	2
	.globl	main
	.type	main, @function
main:
	addi	sp,sp,-16
	sw	ra,12(sp)
	sw	s0,8(sp)
	addi	s0,sp,16
	li	a5,4096
	sw	zero,0(a5)
.L5:
	li	a0,2
	call	Order
	li	a0,4
	call	Order
	li	a0,8
	call	Order
	li	a0,16
	call	Order
	li	a0,32
	call	Order
	li	a0,64
	call	Order
	j	.L5
	.size	main, .-main
	.ident	"GCC: (13.2.0-11ubuntu1+12) 13.2.0"
