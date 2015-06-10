# gofaster
Faster alternatives for some Go stdlib packages

I needed these for another project. Since they're general purpose, I decided to publish them as a separate repo.

Contents, so far:
* Base64 encoder, interface similar to "encoding/base64"
* Crc32 with Kadatch & Jenkins (aka crcutil) algorithm, interface similar to "hash/crc32"

Base64 benchmark result (vs stdlib), 16*3k block size:
```
BenchmarkStdlib    10000            169287 ns/op
BenchmarkSimd     100000             16686 ns/op
```

Crc32 benchmark result (vs stdlib), 16k block size:
```
BenchmarkStdlib    30000             47490 ns/op
BenchmarkKandJ    200000              8002 ns/op
```
