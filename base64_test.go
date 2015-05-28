package base64

import "encoding/base64"
import "testing"

const base64Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

func TestBase64Raw(t *testing.T) {
	var in, out, expected, alphabet []byte
	in = make([]byte, 258)
	out = make([]byte, 344)
	expected = make([]byte, 344)
	alphabet = []byte(base64Alphabet)
	for i := 0; i < 256; i++ {
		in[i] = uint8(i)
	}
	base64_enc(out, in, alphabet)
	base64.StdEncoding.Encode(expected, in)
	// Verify the input buffer is unchanged
	for i, v := range in {
		if i < 256 {
			if v != uint8(i) {
				t.Fatal("Input changed at offset", i)
			}
		} else {
			if v != 0 {
				t.Fatal("Input changed at offset", i)
			}
		}
	}

	for i, v := range out {
		if v != expected[i] {
			t.Fatal("Wrong output at byte", i)
		}
	}
}

const bench_b64_words = 16384

func BenchmarkStock(b *testing.B) {
	var in, out []byte
	in = make([]byte, bench_b64_words*3)
	out = make([]byte, bench_b64_words*4)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		base64.StdEncoding.Encode(out, in)
	}
}

func BenchmarkSimd(b *testing.B) {
	var in, out, alphabet []byte
	in = make([]byte, bench_b64_words*3)
	out = make([]byte, bench_b64_words*4)
	alphabet = []byte(base64Alphabet)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		base64_enc(out, in, alphabet)
	}
}
