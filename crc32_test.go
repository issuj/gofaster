package crc32

import "hash/crc32" // <- using this as reference
//import "math/rand"  // <- random bytes
import "testing"

import "fmt"

func TestUpdate(t *testing.T) {
	var in []byte
	//var out, correct uint32
	in = make([]byte, 256)
	for i := 0; i < 256; i++ {
		in[i] = uint8(i)
	}
	fmt.Printf("%08x\n", ChecksumIEEE(in))
	fmt.Printf("%08x\n", crc32.ChecksumIEEE(in))
	fmt.Printf("%08x\n", ChecksumIEEE(in[:4]))
	fmt.Printf("%08x\n", crc32.ChecksumIEEE(in[:4]))

}

func BenchmarkStdlib(b *testing.B) {
	var in []byte
	in = make([]byte, 16384)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		crc32.ChecksumIEEE(in)
	}
}

func BenchmarkKandJ(b *testing.B) {
	var in []byte
	in = make([]byte, 16384)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		ChecksumIEEE(in)
	}
}
