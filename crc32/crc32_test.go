package crc32

import "hash/crc32" // <- using this as reference
import "math/rand"
import "testing"

func TestUpdate(t *testing.T) {
	var in []byte
	//var out, correct uint32
	in = make([]byte, 256)
	for i := 0; i < 256; i++ {
		in[i] = uint8(i)
	}
	for _, length := range []int{4, 7, 16, 24, 32, 40, 63, 64, 256} {
		out := ChecksumIEEE(in[:length])
		correct := crc32.ChecksumIEEE(in[:length])
		if out != correct {
			t.Fatalf("fail %d %08x %08x\n", length, out, correct)
		}
	}
}

func fillRand(seed uint64, slice []byte) {
	rand.Seed(0)
	for i, _ := range slice {
		slice[i] = uint8(rand.Uint32())
	}
}

const bench_bytes = 16384 + 31

func BenchmarkStdlib(b *testing.B) {
	var in []byte
	in = make([]byte, bench_bytes)
	fillRand(0, in)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		crc32.ChecksumIEEE(in)
	}
}

func BenchmarkKandJ(b *testing.B) {
	var in []byte
	in = make([]byte, bench_bytes)
	fillRand(0, in)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		ChecksumIEEE(in)
	}
}
