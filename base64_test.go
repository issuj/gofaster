package base64

import "encoding/base64"
import "testing"

import "fmt"

const base64Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

func TestBase64Raw(t *testing.T) {
	var in, out, alphabet []byte
	// The raw implementation accesses input as 12 byte blocks,
	// and output as 16 byte blocks. Buffers must be padded upwards
	// to nearest multiple, to get all data processed.
	in = make([]byte, 256+(256%12))
	out = make([]byte, 342+(342%16))
	alphabet = []byte(base64Alphabet)
	for i := 0; i < 256; i++ {
		in[i] = uint8(i)
	}
	base64_enc(out, in, alphabet)
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

	fmt.Println(string(out))
	base64.StdEncoding.Encode(out, in)
	fmt.Println(string(out))
}
