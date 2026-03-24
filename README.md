# Bag-maker - Bagit with a Makefile

MD5 and SHA256 manifest generation and verification via Make — without the heavy Java or Python dependency.

Drop a single `Makefile` into any directory and get proper [BagIt-style](https://datatracker.ietf.org/doc/html/rfc8493) integrity checking with nothing more than coreutils.

## Usage

```bash
make bagit      # generate bag (manifests, bagit.txt, bag-info.txt)
make verify     # check all files against the manifests
make rebagit    # regenerate bag from scratch
make shake-out  # remove non-manifest files, prepare for transfer
make clean      # remove all bag files
```

## What it does

**`make bagit`** recursively finds all files in the directory, computes their MD5 and SHA256 checksums, and writes them to manifests. It also creates:
- `bagit.txt` — BagIt version declaration (1.0, UTF-8)
- `bag-info.txt` — metadata extracted from README.md YAML frontmatter, plus Bagging-Date and Payload-Oxum
- `manifest-md5.txt` — MD5 checksums for all payload files
- `manifest-sha256.txt` — SHA256 checksums for all payload files

Refuses to overwrite an existing bag — use `rebagit` for that.

**`make verify`** performs comprehensive integrity checking:
- Displays contents of `bagit.txt` and `bag-info.txt`
- Verifies Payload-Oxum (byte count and file count match)
- Checks every file in both manifests and reports:
  - **PASSED** — checksum matches (green)
  - **FAILED** — file exists but checksum doesn't match (red)
  - **MISSING** — file in manifest no longer exists (purple)
  - **NEW** — file on disk not tracked in manifest (yellow)
- Returns a non-zero exit code on any failure, so it's safe to use in scripts

**`make shake-out`** prepares a bag for transfer or archival upload by finding files that exist on disk but aren't in the manifest — `.DS_Store`, `Thumbs.db`, editor temp files, stray downloads, etc. Lists them with sizes, then asks for confirmation before deleting. Afterwards, offers to remove the `.git` directory so the bag is a clean, standalone package.

**`make rebagit`** runs `clean` then `bagit` — a deliberate "start fresh" when you know files have changed.

**`make clean`** removes all bag files (`bagit.txt`, `bag-info.txt`, both manifests).

## Requirements

- `md5sum`, `sha256sum`, `find`, `sort` (GNU coreutils)
- Any POSIX `make`

### macOS note

macOS doesn't ship `md5sum` or `sha256sum`. Either install coreutils (`brew install coreutils`) or swap the commands in the Makefile with macOS equivalents (`md5 -r` / `shasum -a 256`).

## Customisation

Excluded files and directories are defined near the top of the Makefile:

```makefile
EXCLUDE = ! -name 'manifest-md5.txt' \
          ! -name 'manifest-sha256.txt' \
          ! -name 'bagit.txt' \
          ! -name 'bag-info.txt' \
          ! -name 'Makefile' \
          ! -name '.DS_Store' \
          ! -path './.git/*' \
          ! -path './build/*' \
          ! -path './stage/*'
```

Add more `! -name` or `! -path` lines as needed.

### bag-info.txt from README frontmatter

If your README.md has YAML frontmatter (delimited by `---`), it will be extracted into `bag-info.txt`:

```markdown
---
Bag-Software: bagit.mk
Source-Organization: Example Archive
Contact-Email: curator@example.org
---

# Your README content...
```

The tool automatically adds:
- `Bagging-Date` — current UTC date
- `Payload-Oxum` — total bytes and file count

## Features

- **Dual hash algorithms** — Both MD5 and SHA256 for maximum compatibility
- **[BagIt 1.0 compliant](https://datatracker.ietf.org/doc/html/rfc8493)** — Generates standard `bagit.txt` and `bag-info.txt`
- **Payload-Oxum verification** — Quick completeness check before checksum validation
- **Color-coded output** — Easy to spot failures at a glance
- **Safe by default** — Won't overwrite existing bags without explicit `rebagit`
- **Script-friendly** — Non-zero exit codes on failure

## Limitations

- MD5 is fine for accidental corruption detection but not for security/tamper-proofing. SHA256 is included for stronger guarantees.
- Not a *full* BagIt implementation — no tag manifests or fetch files. It covers the essentials: payload manifests, bagit.txt, and bag-info.txt.
- README frontmatter must use standard YAML delimiters (`---`) for bag-info.txt extraction to work.

## License

CC0 This work has been marked as dedicated to the public domain — do what you like with it.

## Origin

Human + Claude, iteratively developed, Feb 2026.
