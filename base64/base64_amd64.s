#include "textflag.h"

// X5, PSHUFB 4xLE -> pad + 3xBE
DATA b64_shuf_lebe<>+0x00(SB)/4, $0xff000102
DATA b64_shuf_lebe<>+0x04(SB)/4, $0xff030405
DATA b64_shuf_lebe<>+0x08(SB)/4, $0xff060708
DATA b64_shuf_lebe<>+0x0c(SB)/4, $0xff090a0b
GLOBL b64_shuf_lebe<>(SB), RODATA, $16

// X8, PSHUFB long byte swap
DATA b64_shuf_swap<>+0x00(SB)/4, $0x00010203
DATA b64_shuf_swap<>+0x04(SB)/4, $0x04050607
DATA b64_shuf_swap<>+0x08(SB)/4, $0x08090a0b
DATA b64_shuf_swap<>+0x0c(SB)/4, $0x0c0d0e0f
GLOBL b64_shuf_swap<>(SB), RODATA, $16

// X6, 12 bit mask, long
DATA b64_mask_12<>+0x00(SB)/4, $0x00000fff
DATA b64_mask_12<>+0x04(SB)/4, $0x00000fff
GLOBL b64_mask_12<>(SB), RODATA, $8

// X7, 6 bit mask, short
DATA b64_mask_6<>+0x00(SB)/4, $0x003f003f
DATA b64_mask_6<>+0x04(SB)/4, $0x003f003f
GLOBL b64_mask_6<>(SB), RODATA, $8

// X9 (byte 16), X10, X11 (constructed from X9)
DATA b64_byte_16<>+0x00(SB)/4, $0x10101010
DATA b64_byte_16<>+0x04(SB)/4, $0x10101010
GLOBL b64_byte_16<>(SB), RODATA, $8

// PSHUFB: SSSE3
// rest: SSE2

//func base64_enc(dst, src, alphabet []byte) (read, written uint64)
TEXT ·base64_enc(SB),NOSPLIT,$0
    MOVQ dst_base+0(FP),       R10 // dest base ptr
    MOVQ dst_len+8(FP),        R11 // dest length
    MOVQ src_base+24(FP),      R8  // source base ptr
    MOVQ alphabet_base+48(FP), R13 // alphabet base ptr

    // check alphabet length
    MOVQ $(64), R14
    CMPQ R14, alphabet_len+56(FP) // code length
    JLT end                       // skip the whole thing if too short

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

    // XMM register allocation:
    // X0-X4: work
    // X5: const PSHUFB map, 4xLE -> pad + 3xBE
    // X6: const 12 bit mask, long x4
    // X7: const 6 bit mask, word x8
    // X8: const PSHUFB map, long byte swap
    // X9: const 16, byte x16
    // X10: const 48, byte x16
    // X11: const 128, byte x16
    // X12-X15: const alphabet

    // Load / construct constants

    MOVO b64_shuf_lebe<>(SB), X5

    MOVQ b64_mask_12<>(SB), X6
    MOVLHPS X6, X6

    MOVQ b64_mask_6<>(SB), X7
    MOVLHPS X7, X7

    MOVO b64_shuf_swap<>(SB), X8

    MOVQ b64_byte_16<>(SB), X9
    MOVLHPS X9, X9

    MOVO X9, X10
    PSLLL $(1), X10
    POR X9, X10

    MOVO X9, X11
    PSLLL $(3), X11

    // Load alphabet

    MOVOU  0(R13), X12
    MOVOU 16(R13), X13
    MOVOU 32(R13), X14
    MOVOU 48(R13), X15

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

    PSHUFB X5, X0   // LE -> BE + pad

    MOVO X6, X1    // 12 bit mask, long
    MOVO X7, X2    // 6 bit mask, word

    PANDN X0, X1   // select high 12 bits
    PSLLL $(4), X1 // align
    PAND X6, X0    // select low 12 bits
    POR X1, X0     // combine

    PANDN X0, X2   // select high 6 bits
    PSLLW $(2), X2 // align
    PAND X7, X0    // select low 6 bits
    POR X2, X0     // combine

    // X0 now contains 6-bit values in       [ X12   X13   X14   X15]
    // byte-swapped order, ready to be       [0:16 16:32 32:48 48:64]
    // mapped to the alphabet

    //
    // Map 6-bit bytes to alphabet
    //

    PSUBB X10, X0   // subtract 48           [-48:-32 -32:-16 -16:0 0:16]

    MOVO  X15,  X1  // code[48:64]
    PSHUFB X0,  X1  // map
    PMAXUB X11, X0  // mask out mapped bytes [-48:-32 -32:-16 -16:0 128:128]
    PADDB  X9,  X0  // add 16                [-32:-16 -16:0    0:16 144:144]

    MOVO  X14,  X2  // code[32:48]
    PSHUFB X0,  X2  // map
    PMAXUB X11, X0  // mask out mapped bytes [-32:-16 -16:0 128:128 144:144]
    PADDB  X9,  X0  // add 16                [-16:0    0:16 144:144 160:160]

    MOVO  X13,  X3  // code[16:32]
    PSHUFB X0,  X3  // map
    PMAXUB X11, X0  // mask out mapped bytes [-16:0 128:128 144:144 160:160]
    PADDB  X9,  X0  // add 16                [ 0:16 144:144 160:160 176:176]

    MOVO  X12,  X4  // code[0:16]
    PSHUFB X0,  X4  // map

    POR X2, X1      // combine
    POR X3, X1      // combine
    POR X4, X1      // combine

    PSHUFB X8, X1   // byte swap to output order

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
