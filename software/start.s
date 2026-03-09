.section .text.init
.global _start
_start:
    li sp, 0x1000   # Initialize stack pointer to top of DMEM
    jal main        # Jump to your C code