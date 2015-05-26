
//func base64_enc(src, dst []byte, alphabet []byte)
TEXT ·base64_enc(SB),NOSPLIT,$0
    MOVQ src+0(FP), R8 // source base ptr
    MOVQ src+8(FP), R9 // source length
    MOVQ dst+24(FP), R10 // dest base ptr
    MOVQ dst+32(FP), R11 // dest length
    MOVQ dst+48(FP), R13 // alphabet base ptr

    // Build shuffle map (LE4 -> BE3)
    MOVL $(0x00010202), R12
    PINSRD $(0), R12, X7
    MOVL $(0x03040505), R12
    PINSRD $(1), R12, X7
    MOVL $(0x06070808), R12
    PINSRD $(2), R12, X7
    MOVL $(0x090a0b0b), R12
    PINSRD $(3), R12, X7

    // Build 6-bit mask
    MOVL $(0x3f000000), R12
    PINSRD $(0), R12, X8
    PINSRD $(1), R12, X8
    MOVLHPS X8, X8

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
    MOVL $(0x0f0e0d0c), R12
    PINSRD $(3), R12, X10

    // Load alphabet to registers
    CMPQ $(64), alphabet+56(FP) // alphabet base length
    JGE end
    MOVOU 0(R13), X11
    MOVOU 16(R13), X12
    MOVOU 32(R13), X13
    MOVOU 48(R13), X14

    SHRQ $(2), R11  // dstlen /= 4
    XORQ DX, DX
    MOVQ R9, AX  
    MOVQ $(3), BX
    DIVQ BX        // srclen /= 3
    CMPQ AX, R11
    CMOVQLT AX, R11 // nPx = min(nPx_dst, nPx_src)
    SHLQ $(2), R11  // srclen *= 4

    loop:
    CMPQ R11, $(16)
    JLT end
    SUBQ $(16), R11

    MOVOU 0(R8), X0  // read
    ADDQ $(12), R8  // inc source ptr
    PSHUFB X7, X0   // shuffle

    PXOR X1, X1

    // Unpack 3x8-bit -> 4x6-bit
    MOVO X0, X2
    PSRLD $(2), X2
    PAND X8, X2
    PSRLD $(8), X8
    MOVO X2, X1

    MOVO X0, X3
    PSRLD $(4), X3
    PAND X8, X3
    PSRLD $(8), X8
    POR X3, X1

    MOVO X0, X4
    PSRLD $(6), X4
    PAND X8, X4
    PSRLD $(8), X8
    POR X4, X1

    MOVO X0, X5
    PAND X8, X5
    POR X5, X0  // 6-bit values
    PSLLD $(24), X8 // reset 6-bit mask

    PSHUFB X10, X0

    // less than 16
    MOVO X9, X4
    PCMPGTB X0, X4 // (a < b => b)
    MOVO X4, X1

    // less than 32
    MOVO X9, X5
    PSLLD $(1), X5
    PCMPGTB X0, X5 // (a < b => b)
    MOVO X1, X3
    PANDN X5, X3
    POR X3, X1

    // less than 48
    MOVO X9, X5
    PSLLD $(1), X5
    POR X9, X5
    PCMPGTB X0, X5 // (a < b => b)
    MOVO X1, X2
    PANDN X5, X2
    POR X2, X1 // <- greater or equal to 48

    MOVO X9, X5
    MOVO X9, X6
    PSLLD $(4), X5
    PSUBB X5, X6 // 0x0f == 15
    PAND X6, X0

    PAND X0, X4
    PAND X0, X3
    PAND X0, X2
    PAND X0, X1

    MOVO X11, X0
    PSHUFB X4, X0

    MOVO X12, X4
    PSHUFB X3, X4
    POR X4, X0

    MOV X13, X3
    PSHUFB X2, X3
    POR X3, X0

    MOVO X14, X2
    PSHUFB X1, X2
    POR X2, X0

    MOVOU X1, 0(R10)
    ADDQ $(16), R10 // inc dest ptr

    JMP loop

    end:
    RET
