# Compression

Medium article: ["LZFSE Is on Its Way Out: A Measured Tour of Apple's Compression Framework"](https://hari51215.medium.com/lzfse-is-on-its-way-out-a-measured-tour-of-apples-compression-framework-1ea59e47fde4)

No sample app for this topic — Compression has no interface of its own. It is a codec library:
bytes in, smaller bytes out, with three call styles (buffer, C stream, and the Swift
`InputFilter`/`OutputFilter` classes) wrapping the same seven algorithms. A SwiftUI demo would be
a file picker and a progress bar, and neither would show anything about the API that a dozen lines
of Swift in the article don't show better. There is also nothing here to test on device: the
framework behaves identically on a Mac and on an iPhone, so the measurements were easier to take
and easier to trust from a command-line harness.

Every number in the article came from running the framework directly on macOS 26.7 (SDK 26.1,
Swift 6.2.1, Apple silicon) rather than from Apple's documentation — ratios and encode/decode
throughput for all seven SDK algorithms across four corpora (130 KB of Markdown, 140 KB of Swift
source, a 73 KB JSON property list, 200 KB from `/dev/urandom`), plus the scratch-buffer
measurements, the `finalize()` truncation figures, and the undersized-destination behaviour. Four
findings worth recording because they contradict the obvious reading of the docs:

- `COMPRESSION_ZLIB` emits **raw DEFLATE** (RFC 1951), not a zlib stream (RFC 1950). Python's
  `zlib.decompress` rejects it with `incorrect header check` unless called with `wbits=-15`.
- `Algorithm.lzbitmap` compiles but throws `FilterError.invalidState` at runtime — LZBITMAP is
  buffer-API only, which the C header documents and the Swift enum does not.
- `compression_decode_buffer` with an undersized destination truncates silently and returns the
  buffer size, with no error on any channel.
- Supplying a scratch buffer to `compression_encode_buffer` was worth 0.7% on LZFSE, for a 684 KB
  allocation.

`COMPRESSION_LZMESH` and `COMPRESSION_LZRAVEN` are the iOS/macOS 27 additions and are absent from
the SDK installed here, so those two are documented from Apple's reference and flagged as
unmeasured in the article itself.
