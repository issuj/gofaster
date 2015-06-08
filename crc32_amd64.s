#include "textflag.h"

//func crc32_8_4(crc Crc, data []Word, table []Crc) (n int, crc0, crc1, crc2, crc3 Crc)
TEXT ·crc32_8_4(SB),NOSPLIT,$0
    MOVQ data_base+8(FP),   SI // src base ptr
    MOVQ data_len+16(FP),   BX // src length
    MOVQ table_base+32(FP), DI // table base ptr

    MOVLQZX crc+0(FP), R8 // crc0
    XORQ R9, R9 // crc1
    XORQ R10, R10 // crc2
    XORQ R11, R11 // crc3

loop:
    CMPQ BX, $(0)
    JLE end
    SUBQ $(4), BX

    MOVQ 0(SI),  R12
    XORQ R8, R12
    XORQ R8, R8
    MOVQ 8(SI),  R13
    XORQ R9, R13
    XORQ R9, R9
    MOVQ 16(SI), R14
    XORQ R10, R14
    XORQ R10, R10
    MOVQ 24(SI), R15
    XORQ R11, R15
    XORQ R11, R11

    ADDQ $(32), SI

    XORQ DX, DX

inner:
    CMPQ DX, $(8*256)
    JGE loop

    LEAQ (DI)(DX*4), AX

    MOVBQZX R12B, CX
    LEAQ (AX)(CX*4), CX
    XORL 0(CX), R8
    SHRQ $(8), R12

    MOVBQZX R13B, CX
    LEAQ (AX)(CX*4), CX
    XORL 0(CX), R9
    SHRQ $(8), R13

    MOVBQZX R14B, CX
    LEAQ (AX)(CX*4), CX
    XORL 0(CX), R10
    SHRQ $(8), R14

    MOVBQZX R15B, CX
    LEAQ (AX)(CX*4), CX
    XORL 0(CX), R11
    SHRQ $(8), R15
    
    ADDQ $(256), DX
    JMP inner

end:

    MOVL R8, crc0+64(FP)
    MOVL R9, crc1+68(FP)
    MOVL R10, crc2+72(FP)
    MOVL R11, crc3+76(FP)
    SUBQ data_base+8(FP), SI
    SHRQ $(3), SI
    MOVQ SI, n+56(FP)

    RET
