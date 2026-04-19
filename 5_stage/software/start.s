.section .text
    .global _start

_start:
    # 1. Initialize the Stack Pointer (x2 / sp)
    # The stack grows downwards. We need to set it to the top of your Data Memory.
    # Assuming your RAM goes up to 0x00000FFF (4KB), we set SP to 0x00001000.
    # Note: Adjust this if your actual memory size is different!
    li sp, 0x00001000

    # 2. Call the C main function
    jal ra, main

    # 3. Catch the CPU if main() ever accidentally returns
hang:
    j hang