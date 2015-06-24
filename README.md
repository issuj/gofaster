# gofaster
Faster alternatives for some Go stdlib packages

I needed these for another project. Since they're general purpose, I decided to publish them as a separate repo.

Contents, so far:
* Base64 encoder, interface similar to "encoding/base64"
* Crc32 with Kadatch & Jenkins (aka crcutil) algorithm, interface similar to "hash/crc32"

Base64 benchmark result (vs stdlib), 3*16k block size:
```
BenchmarkStdlib    10000            166960 ns/op         294.39 MB/s
BenchmarkSimd     100000             16365 ns/op        3003.47 MB/s
```

Crc32 benchmark result (vs stdlib), 16k block size:
```
BenchmarkStdlib    30000             46752 ns/op         351.10 MB/s
BenchmarkKandJ    200000              7798 ns/op        2104.94 MB/s
```

Benchmarks were run on an Intel Core i7-5600U.
