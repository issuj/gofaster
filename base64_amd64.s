#include "textflag.h"

//func base64_enc(dst, src, code []byte) (read, written uint64)
TEXT ·base64_enc(SB),NOSPLIT,$0
    MOVQ dst_base+0(FP),   R10 // dest base ptr
    MOVQ dst_len+8(FP),    R11 // dest length
    MOVQ src_base+24(FP),  R8 // source base ptr
    MOVQ code_base+48(FP), R13 // alphabet base ptr

    // Build shuffle map (LE4 -> BE3)
    MOVL $(0x00010202), R12
    PINSRD $(0), R12, X7
    MOVL $(0x03040505), R12
    PINSRD $(1), R12, X7
    MOVL $(0x06070808), R12
    PINSRD $(2), R12, X7
    MOVL $(0x090a0b0b), R12
    PINSRD $(3), R12, X7

    // Build 6-bit mask (4x 0x3f000000)
    PCMPEQB X8, X8  // set to all ones
    PSRLL $(26), X8
    PSLLL $(24), X8

    // Build a register full of 0x10 == 16
    MOVL $(0x10101010), R12
    PINSRD $(0), R12, X9
    PINSRD $(1), R12, X9
    MOVLHPS X9, X9

    // Build byte swap map
    MOVL $(0x00010203), R12
    PINSRD $(0), R12, X10
    MOVL $(0x04050607), R12
    PINSRD $(1), R12, X10
    MOVL $(0x08090a0b), R12
    PINSRD $(2), R12, X10
    MOVL $(0x0c0d0e0f), R12
    PINSRD $(3), R12, X10

    // Load alphabet to registers
    MOVQ $(64), R14
    CMPQ R14, code_len+56(FP) // code length
    JLT end                   // skip the whole thing if too short
    MOVOU 0(R13), X11
    MOVOU 16(R13), X12
    MOVOU 32(R13), X13
    MOVOU 48(R13), X14

    // Limit run length by either src or dst
    SHRQ $(2), R11  // dstlen /= 4
    XORQ DX, DX
    MOVQ src_len+32(FP), AX
    MOVQ $(3), BX
    DIVQ BX         // srclen /= 3
    CMPQ R11, AX
    CMOVQLT R11, AX // nWords = min(nWords_dst, nWords_src)
    MULQ BX         // nWords *= 3
    MOVQ AX, R11

    // JMP loop3 // <- uncomment to skip SSE part and test/benchmark just the tail loop

loop12:
    CMPQ R11, $(16) // CMP to 16 instead of 12, because we do 16 byte reads
    JLT loop3
    SUBQ $(12), R11 // But we decrement remaining count by 12

    MOVOU 0(R8), X0 // read
    ADDQ $(12), R8  // inc source ptr

    // Unpack 3x8bit -> 4x6bit
    PSHUFB X7, X0   // shuffle

    // output byte 1
    MOVO X0, X1
    PSRLL $(2), X1
    PAND X8, X1
    PSRLL $(8), X8

    // output byte 2
    MOVO X0, X2
    PSRLL $(4), X2
    PAND X8, X2
    PSRLL $(8), X8
    POR X2, X1

    // output byte 3
    MOVO X0, X3
    PSRLL $(6), X3
    PAND X8, X3
    PSRLL $(8), X8
    POR X3, X1

    // output byte 4
    PAND X8, X0
    POR X1, X0      // 6-bit values 0 <= v <= 63

    PSLLL $(24), X8 // reset 6-bit mask for the next round

    PSHUFB X10, X0  // restore order, BE -> LE

    PXOR X5, X5

    MOVO X11, X1    // code[0:16]
    PSHUFB X0, X1   // map
    PSUBB X9, X0    // subtract 16
    PCMPGTB X0, X5  // (a < b => b) X5[i] is zero
    PAND X5, X1     // mask result

    MOVO X12, X2    // code[16:32]
    PSHUFB X0, X2   // map
    PSUBB X9, X0    // subtract 16
    PCMPGTB X0, X5  // (a < b => b) X5[i] is either zero, or -1 if it matched previously
    POR X2, X1      // combine
    PAND X5, X1     // mask result

    MOVO X13, X3    // code[32:48]
    PSHUFB X0, X3   // map
    PSUBB X9, X0    // subtract 16
    PCMPGTB X0, X5  // (a < b => b) X5[i] is either zero, or -1 if it matched previously
    POR X3, X1      // combine
    PAND X5, X1     // mask result

    MOVO X14, X4    // code[48:64]
    PSHUFB X0, X4   // map
    POR X4, X1      // combine

    MOVOU X1, 0(R10) // write
    ADDQ $(16), R10  // inc dest ptr

    JMP loop12

loop3:
    CMPQ R11, $(3)
    JLT end
    SUBQ $(3), R11

    MOVWQZX 0(R8), AX // read
    SHLL $(8), AX
    BSWAPL AX
    MOVB 2(R8), AX    // read
    ADDQ $(3), R8     // inc source ptr

    XORQ DX, DX       // init output
    MOVQ $(4), R12    // init loop counter

loop3_byte:
    SHLL $(8), DX     // shift output
    MOVQ $(0x3f), CX  // create mask
    ANDB AX, CX       // select 6 bits of input with mask
    ADDQ R13, CX      // add code base address to get code symbol address
    MOVBLZX 0(CX), CX // map
    ORL CX, DX        // combine
    SHRL $(6), AX     // shift input

    DECB R12
    JNZ loop3_byte

    MOVL DX, 0(R10)   // write
    ADDQ $(4), R10    // inc dest ptr
    JMP loop3

end:
    SUBQ src_base+24(FP), R8
    SUBQ dst_base+0(FP), R10
    MOVQ R8, read+72(FP)
    MOVQ R10, written+80(FP)
    RET
