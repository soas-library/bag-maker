# bagit Makefile

MD5 manifest generation and verification via Make — without the heavy Java or Python (or LoC!) dependency.

Drop a single `Makefile` into any directory and get basic [BagIt-style](https://datatracker.ietf.org/doc/html/rfc8493) integrity checking with nothing more than coreutils.

## Usage

```bash
make bagit      # generate manifest-md5.txt
make verify     # check all files against the manifest
make rebagit    # regenerate manifest from scratch
make clean      # remove the manifest
```

## What it does

**`make bagit`** recursively finds all files in the directory, computes their MD5 checksums, and writes them to `manifest-md5.txt`. Refuses to overwrite an existing manifest — use `rebagit` for that.

**`make verify`** checks every file in the manifest and reports:
- **FAILED** — file exists but checksum doesn't match (red)
- **MISSING** — file in the manifest no longer exists (purple)
- **NEW** — file on disk not tracked in the manifest (yellow)
- Returns a non-zero exit code on any failure, so it's safe to use in scripts.

**`make rebagit`** runs `clean` then `bagit` — a deliberate "start fresh" when you know files have changed.

## Requirements

- `md5sum`, `find`, `sort` (GNU coreutils)
- Any POSIX `make`

### macOS note

macOS doesn't ship `md5sum`. Either install coreutils (`brew install coreutils`) or swap `md5sum` references in the Makefile with `md5 -r` / `md5 -q` equivalents.

## Customisation

Excluded files are defined near the top of the Makefile:

```makefile
EXCLUDE = ! -name 'manifest-md5.txt' \
          ! -name 'Makefile' \
          ! -name '.DS_Store' \
          ! -path './.git/*'
```

Add more `! -name` or `! -path` lines as needed.

## Limitations

- Uses MD5, which is fine for accidental corruption detection but not for security/tamper-proofing. Swap `md5sum` for `sha256sum` if you need stronger guarantees.
- Not a full BagIt implementation — no `bagit.txt`, `bag-info.txt`, tag manifests, or fetch files. It's just the checksum manifest, which is the part you actually want 90% of the time.

## License

Public domain — do what you like with it.

## Origin

Human + Claude, iteratively developed, Feb 2026.