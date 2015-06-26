# gofaster
Faster alternatives for some Go stdlib packages

I needed these for another project. Since they're general purpose, I decided to publish them as a separate repo.

Contents, so far:
* Base64 encoder, interface similar to "encoding/base64"
* Crc32 with Kadatch & Jenkins (aka crcutil) algorithm, interface similar to "hash/crc32"

Base64 benchmark result (vs stdlib), 3*16k block size:
```
BenchmarkStdlib    10000            162650 ns/op         302.19 MB/s
BenchmarkSimd     100000             15352 ns/op        3201.58 MB/s
```

Crc32 benchmark result (vs stdlib), 16k block size:
```
BenchmarkStdlib    30000             46786 ns/op         350.85 MB/s
BenchmarkKandJ    300000              5858 ns/op        2801.91 MB/s
```

Benchmarks were run on an Intel Core i7-5600U.
