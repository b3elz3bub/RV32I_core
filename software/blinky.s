.section .text
.global main
main:
    li a5, 0x00001000      # Load your MMIO LED address
loop:
    li a4, 4               # Target LED 2
    sw a4, 0(a5)           # Store word to MMIO

    li t0, 2500000         # Delay loop counter
delay1:
    addi t0, t0, -1
    bnez t0, delay1

    sw zero, 0(a5)         # Turn off all LEDs

    li t0, 2500000         # Delay loop counter
delay2:
    addi t0, t0, -1
    bnez t0, delay2

    j loop                 # Repeat