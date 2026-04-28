.section .text
    .global _start

_start:
    # 1. Initialize the Stack Pointer (x2 / sp)
    # The stack grows downwards. Set to top of Data Memory.
    # RAM is now 8KB: 0x0000 – 0x1FFF, so SP = 0x2000.
    li sp, 0x00002000

    # 2. Call the C main function
    jal ra, main

    # 3. Catch the CPU if main() ever accidentally returns
hang:
    j hang