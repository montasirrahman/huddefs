# Conversion progress — EASY packages

Mechanical v1 -> v2 conversion, built against the **minimal** rootfs and install
tested. Appended one batch at a time.

The last column is the point of the exercise: what the build needed that v1's
`Depends:` never mentioned. An empty cell means v1's dependency data was
sufficient for the build.

**Caveat on that column.** Nine packages are always present in the minimal rootfs
because the hud client cannot fetch anything without them — curl, openssl, zlib,
zstd, brotli, nghttp2, libidn2, libpsl and libunistring. A dependency on any of
those cannot be detected as missing here, so this column undercounts by exactly
that set.


## Batch 1

0/3 built, average build 0s, cumulative elapsed 0.1h

| Package | Build | Test | Build s | Provides | Requires | Undeclared Build-Depends |
|---|---|---|---|---|---|---|
| `acl` | FAIL — [✗] Package not found: auto | — | 125 | — | — | — |
| `aom` | FAIL — [✗] Package not found: auto | — | 136 | — | — | — |
| `attr` | FAIL — [✗] Package not found: auto | — | 141 | — | — | — |

## Batch 1

1/4 built, average build 570s, cumulative elapsed 9.3h

| Package | Build | Test | Build s | Provides | Requires | Undeclared Build-Depends |
|---|---|---|---|---|---|---|
| `cracklib` | OK | OK | 570 | `_cracklib.so`, `libcrack.so.2` | `exec(sh)`, `libc.so.6`, `libz.so.1` | — |
| `cups` | FAIL — [✗] build dependency install failed | — | 176 | — | — | — |
| `curl` | FAIL — [✗] build dependency install failed | — | 194 | — | — | — |
| `dav1d` | FAIL — [✗] build dependency install failed | — | 209 | — | — | — |
