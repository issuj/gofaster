#include "textflag.h"

// for PSHUFB
DATA b64_bswap3<>+0x00(SB)/4, $0xff000102
DATA b64_bswap3<>+0x04(SB)/4, $0xff030405
DATA b64_bswap3<>+0x08(SB)/4, $0xff060708
DATA b64_bswap3<>+0x0c(SB)/4, $0xff090a0b
GLOBL b64_bswap3<>(SB), RODATA, $16

DATA b64_byte_16<>+0x00(SB)/4, $0x10101010
DATA b64_byte_16<>+0x04(SB)/4, $0x10101010
GLOBL b64_byte_16<>(SB), RODATA, $8

// PSHUFB: SSE3

//func base64_enc(dst, src, code []byte) (read, written uint64)
TEXT ·base64_enc(SB),NOSPLIT,$0
    MOVQ dst_base+0(FP),   R10 // dest base ptr
    MOVQ dst_len+8(FP),    R11 // dest length
    MOVQ src_base+24(FP),  R8  // source base ptr
    MOVQ code_base+48(FP), R13 // alphabet base ptr

    // Limit run length to shorter of (src, dst)
    SHRQ $(2), R11  // nWords_dst = dstlen / 4
    XORQ DX, DX
    MOVQ src_len+32(FP), AX
    MOVQ $(3), BX
    DIVQ BX         // nWords_src = srclen / 3
    CMPQ R11, AX
    CMOVQLT R11, AX // nWords = min(nWords_dst, nWords_src)
    MULQ BX         // nWords *= 3
    MOVQ AX, R11

    // JMP loop3 // <- uncomment to skip SSE part and test/benchmark just the tail loop

    // Load shuffle map (LE3 -> BE4)
    MOVO b64_bswap3<>(SB), X7

    // Build 6-bit mask (4x 0x0000003f)
    PCMPEQB X8,  X8  // set to all ones
    PSRLL $(26), X8

    // A register full of byte 0x10 == 16
    MOVQ b64_byte_16<>(SB), X5
    MOVLHPS X5, X5

    // A register full of byte 0x30 == 48
    MOVO X5, X6
    PSLLL $(1), X6
    POR X5, X6

    // A register full of byte 0x80 == 128
    MOVO X5, X9
    PSLLL $(3), X9

    // Load alphabet to registers
    MOVQ $(64), R14
    CMPQ R14, code_len+56(FP) // code length
    JLT end                   // skip the whole thing if too short
    MOVOU  0(R13), X11
    MOVOU 16(R13), X12
    MOVOU 32(R13), X13
    MOVOU 48(R13), X14

loop12:
    //
    // 12 byte loop
    //
    CMPQ R11, $(16) // CMP to 16 instead of 12, because we do 16 byte reads
    JLT loop3
    SUBQ $(12), R11 // But we decrement remaining count by 12

    MOVOU 0(R8), X0 // read
    ADDQ $(12), R8  // inc source ptr

    //
    // Unpack 3x8bit -> 4x6bit
    //

    PSHUFB X7, X0   // LE -> BE + pad

    // unpack byte 4
    MOVO X8, X1     // 6-bit mask
    PAND X0, X1     // select lowmost 6 bits
    PSRLL $(6), X0  // shift input
    PSLLO $(3), X1  // shift temp by 24 bits

    // unpack byte 3
    MOVO X8, X2     // 6-bit mask
    PAND X0, X2     // select lowmost 6 bits
    PSRLL $(6), X0  // shift input
    PSLLO $(2), X2  // shift temp by 16 bits

    // unpack byte 2
    MOVO X8, X3     // 6-bit mask
    PAND X0, X3     // select lowmost 6 bits
    PSRLL $(6), X0  // shift input
    PSLLO $(1), X3  // shift temp by 8 bits

    // byte 1 is now left alone in X0 at correct position

    POR  X1, X0     // combine
    POR  X2, X0     // combine
    POR  X3, X0     // combine

    // X0 now contains 6-bit values in       [ X11   X12   X13   X14]
    // output order, ready to be mapped      [0:16 16:32 32:48 48:64]
    // to the alphabet

    //
    // Map 6-bit bytes to alphabet
    //
    PSUBB X6, X0    // subtract 48           [-48:-32 -32:-16 -16:0 0:16]

    MOVO  X14, X1   // code[48:64]
    PSHUFB X0, X1   // map
    PMAXUB X9, X0   // mask out mapped bytes [-48:-32 -32:-16 -16:0 128:128]
    PADDB  X5, X0   // add 16                [-32:-16 -16:0    0:16 144:144]

    MOVO  X13, X2   // code[32:48]
    PSHUFB X0, X2   // map
    PMAXUB X9, X0   // mask out mapped bytes [-32:-16 -16:0 128:128 144:144]
    PADDB  X5, X0   // add 16                [-16:0    0:16 144:144 160:160]

    MOVO  X12, X3   // code[16:32]
    PSHUFB X0, X3   // map
    PMAXUB X9, X0   // mask out mapped bytes [-16:0 128:128 144:144 160:160]
    PADDB  X5, X0   // add 16                [ 0:16 144:144 160:160 176:176]

    MOVO  X11, X4   // code[0:16]
    PSHUFB X0, X4   // map

    POR X2, X1      // combine
    POR X3, X1      // combine
    POR X4, X1      // combine

    MOVOU X1, 0(R10) // write
    ADDQ $(16), R10  // inc dest ptr

    JMP loop12

loop3:
    //
    // 3 byte tail loop
    //
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
    SHLQ $(8), DX         // shift output
    MOVQ $(0x3f), CX      // create mask
    ANDQ AX, CX           // select 6 bits of input with mask
    MOVB 0(R13)(CX*1), DL // map
    SHRQ $(6), AX         // shift input

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
