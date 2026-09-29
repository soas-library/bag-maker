# ┌──────────────────────────────────────────────────────┐
# │  Bag Maker:                                          │
# │  MD5 + SHA256 manifest generation and verification   │
# │  with bag-info.txt from README.md frontmatter        │
# │  ...without the heavy java or python dependency.     │
# │                                                      │
# │  Aids Best Current Practice (BCP) for:               │
# │  ...RFC 8493 BagIt File Packaging Format (V1.0).     │
# │                                                      │
# │  Usage:  make bagit     — generate bag               │
# │          make verify    — check file integrity       │
# │          make rebagit   — regenerate from scratch    │
# │          make shake-out — remove non-manifest files  │
# │          make clean     — remove bag files           │
# │                                                      │
# │  Drop this Makefile into any directory and go.       │
# │  Requires: md5sum, sha256sum, find, sort (coreutils) │
# │                                                      │
# │  Created: Feb 2026                                   │
# │  Origin:  Human + Claude, iteratively developed      │
# │  License: CC0                                        │
# └──────────────────────────────────────────────────────┘

MANIFEST_MD5    = manifest-md5.txt
MANIFEST_SHA256 = manifest-sha256.txt
MANIFESTS       = $(MANIFEST_MD5) $(MANIFEST_SHA256)
BAGIT_TXT       = bagit.txt
BAG_INFO        = bag-info.txt
BAG_FILES       = $(MANIFESTS) $(BAGIT_TXT) $(BAG_INFO)

# Patterns to exclude (add more as needed)
EXCLUDE = ! -name 'manifest-md5.txt' \
          ! -name 'manifest-sha256.txt' \
          ! -name 'bagit.txt' \
          ! -name 'bag-info.txt' \
          ! -name 'Makefile' \
          ! -name '.DS_Store' \
          ! -path './.git/*' \
		  ! -path './build/*' \
		  ! -path './stage/*'

.PHONY: bagit rebagit verify clean shake-out

bagit:
	@if [ -f $(MANIFEST_MD5) ] || [ -f $(MANIFEST_SHA256) ]; then \
		echo "Warning: Bag already exists."; \
		echo "  Run 'make verify' to check the current bag."; \
		echo "  Run 'make rebagit' to regenerate."; \
		exit 1; \
	fi
	@# --- bagit.txt ---
	@printf "BagIt-Version: 1.0\nTag-File-Character-Encoding: UTF-8\n" > $(BAGIT_TXT)
	@echo "Created $(BAGIT_TXT)"
	@# --- bag-info.txt from README.md frontmatter ---
	@if [ -f README.md ]; then \
		FRONT=$$(sed -n '/^---$$/,/^---$$/{//d;p;}' README.md); \
		if [ -n "$$FRONT" ]; then \
			echo "$$FRONT" > $(BAG_INFO); \
			echo "Bagging-Date: $$(date -u +%Y-%m-%d)" >> $(BAG_INFO); \
			BYTES=$$(find . -type f $(EXCLUDE) ! -name '$(BAGIT_TXT)' ! -name '$(BAG_INFO)' -exec cat {} + 2>/dev/null | wc -c | tr -d ' '); \
			COUNT=$$(find . -type f $(EXCLUDE) ! -name '$(BAGIT_TXT)' ! -name '$(BAG_INFO)' | wc -l | tr -d ' '); \
			echo "Payload-Oxum: $$BYTES.$$COUNT" >> $(BAG_INFO); \
			echo "Created $(BAG_INFO) from README.md frontmatter"; \
		else \
			echo "Note: README.md has no YAML frontmatter — skipping $(BAG_INFO)"; \
		fi; \
	else \
		echo "Note: No README.md found — skipping $(BAG_INFO)"; \
	fi
	@# --- manifests ---
	@echo "Generating MD5 manifest..."
	@find . -type f $(EXCLUDE) ! -name '$(BAGIT_TXT)' ! -name '$(BAG_INFO)' -exec md5sum {} + | sed 's/ \*/ /' | sort > $(MANIFEST_MD5)
	@echo "  Created $(MANIFEST_MD5) with $$(wc -l < $(MANIFEST_MD5)) entries."
	@echo "Generating SHA256 manifest..."
	@find . -type f $(EXCLUDE) ! -name '$(BAGIT_TXT)' ! -name '$(BAG_INFO)' ! -name '$(MANIFEST_MD5)' -exec sha256sum {} + | sed 's/ \*/ /' | sort > $(MANIFEST_SHA256)
	@echo "  Created $(MANIFEST_SHA256) with $$(wc -l < $(MANIFEST_SHA256)) entries."

rebagit: clean bagit

verify:
	@if [ ! -f $(MANIFEST_MD5) ] && [ ! -f $(MANIFEST_SHA256) ]; then \
		echo "Error: No manifests found. Run 'make bagit' first."; \
		exit 1; \
	fi; \
	echo ""; \
	TOTAL_FAIL=0; \
	if [ -f $(BAGIT_TXT) ]; then \
		echo "-- $(BAGIT_TXT) --"; \
		cat $(BAGIT_TXT); \
		echo ""; \
	fi; \
	if [ -f $(BAG_INFO) ]; then \
		echo "-- $(BAG_INFO) --"; \
		cat $(BAG_INFO); \
		echo ""; \
		OXUM=$$(grep '^Payload-Oxum:' $(BAG_INFO) | cut -d' ' -f2); \
		if [ -n "$$OXUM" ]; then \
			EXPECTED_BYTES=$$(echo "$$OXUM" | cut -d. -f1); \
			EXPECTED_COUNT=$$(echo "$$OXUM" | cut -d. -f2); \
			ACTUAL_BYTES=$$(find . -type f $(EXCLUDE) ! -name '$(BAGIT_TXT)' ! -name '$(BAG_INFO)' -exec cat {} + 2>/dev/null | wc -c | tr -d ' '); \
			ACTUAL_COUNT=$$(find . -type f $(EXCLUDE) ! -name '$(BAGIT_TXT)' ! -name '$(BAG_INFO)' | wc -l | tr -d ' '); \
			if [ "$$ACTUAL_BYTES" = "$$EXPECTED_BYTES" ] && [ "$$ACTUAL_COUNT" = "$$EXPECTED_COUNT" ]; then \
				echo "  Payload-Oxum OK ✓  ($$ACTUAL_BYTES bytes, $$ACTUAL_COUNT files)"; \
			else \
				echo "  Payload-Oxum MISMATCH"; \
				if [ "$$ACTUAL_BYTES" != "$$EXPECTED_BYTES" ]; then \
					echo "    bytes:  expected $$EXPECTED_BYTES, got $$ACTUAL_BYTES"; \
				fi; \
				if [ "$$ACTUAL_COUNT" != "$$EXPECTED_COUNT" ]; then \
					echo "    files:  expected $$EXPECTED_COUNT, got $$ACTUAL_COUNT"; \
				fi; \
				TOTAL_FAIL=1; \
			fi; \
			echo ""; \
		fi; \
	fi; \
	for MANIFEST in $(MANIFESTS); do \
		if [ ! -f "$$MANIFEST" ]; then continue; fi; \
		ALGO=$$(echo "$$MANIFEST" | sed 's/manifest-\(.*\)\.txt/\1/'); \
		SUMCMD=$$(echo "$$ALGO" | sed 's/-//g')sum; \
		echo "=== Verifying $$ALGO ($$(wc -l < "$$MANIFEST") files) ===\n"; \
		PASS=0; FAIL=0; MISSING=0; \
		while read -r hash file; do \
			file=$${file#\*}; \
			file=$$(printf '%s' "$$file" | tr -d '\r'); \
			if [ ! -f "$$file" ]; then \
				echo "  MISSING   $$file"; \
				MISSING=$$((MISSING + 1)); \
			else \
				actual=$$($$SUMCMD "$$file" | cut -d' ' -f1); \
				if [ "$$actual" = "$$hash" ]; then \
					PASS=$$((PASS + 1)); \
				else \
					echo "  FAILED    $$file"; \
					echo "           expected: $$hash"; \
					echo "           got:      $$actual"; \
					FAIL=$$((FAIL + 1)); \
				fi; \
			fi; \
		done < "$$MANIFEST"; \
		echo ""; \
		echo "--------------------------------"; \
		echo "  Passed:  $$PASS"; \
		if [ $$FAIL -gt 0 ]; then \
			echo "  Failed:  $$FAIL"; \
		fi; \
		if [ $$MISSING -gt 0 ]; then \
			echo "  Missing: $$MISSING"; \
		fi; \
		echo "--------------------------------"; \
		if [ $$FAIL -gt 0 ] || [ $$MISSING -gt 0 ]; then \
			TOTAL_FAIL=1; \
		fi; \
		echo ""; \
	done; \
	NEW=$$(find . -type f $(EXCLUDE) \
		! -name '$(MANIFEST_MD5)' \
		! -name '$(MANIFEST_SHA256)' \
		! -name '$(BAGIT_TXT)' \
		! -name '$(BAG_INFO)' \
		| while read -r f; do \
			grep -Fq "$$f" $(MANIFEST_MD5) || echo "$$f"; \
	done); \
	if [ -n "$$NEW" ]; then \
		echo "  New untracked files:"; \
		echo "$$NEW" | while read -r f; do \
			echo "  NEW       $$f"; \
		done; \
		echo "--------------------------------"; \
		echo ""; \
	fi; \
	if [ "$$TOTAL_FAIL" = "1" ]; then \
		echo "  VERIFICATION FAILED"; \
		exit 1; \
	else \
		echo "  ALL OK ✓"; \
	fi

shake-out:
	@if [ ! -f $(MANIFEST_MD5) ]; then \
		echo "Error: No manifest found. Run 'make bagit' first."; \
		exit 1; \
	fi; \
	ORPHANS=$$(find . -type f \
		! -path './.git/*' \
		! -name 'Makefile' \
		! -name '$(MANIFEST_MD5)' \
		! -name '$(MANIFEST_SHA256)' \
		! -name '$(BAGIT_TXT)' \
		! -name '$(BAG_INFO)' \
		| while read -r f; do \
			grep -Fq "$$f" $(MANIFEST_MD5) || echo "$$f"; \
		done); \
	if [ -z "$$ORPHANS" ]; then \
		echo "Bag is clean — nothing to shake out."; \
		exit 0; \
	fi; \
	echo ""; \
	echo "Orphan files (not in manifest):"; \
	echo ""; \
	echo "$$ORPHANS" | while read -r f; do \
		SIZE=$$(wc -c < "$$f" | tr -d ' '); \
		printf "  %-40s  %s bytes\n" "$$f" "$$SIZE"; \
	done; \
	COUNT=$$(echo "$$ORPHANS" | wc -l | tr -d ' '); \
	echo ""; \
	echo "--------------------------------"; \
	echo "  $$COUNT file(s) not in manifest."; \
	echo "--------------------------------"; \
	echo ""; \
	printf "Remove these files? [y/N] "; \
	read -r CONFIRM; \
	case "$$CONFIRM" in \
		[yY]) \
			echo ""; \
			echo "$$ORPHANS" | while read -r f; do \
				rm -f "$$f"; \
				echo "  Removed $$f"; \
			done; \
			echo ""; \
			echo "Orphan files removed."; \
			;; \
		*) \
			echo "Skipped."; \
			;; \
	esac; \
	echo ""; \
	if [ -d .git ]; then \
		printf "Remove .git directory? This bag will no longer be a repo. [y/N] "; \
		read -r GITCONFIRM; \
		case "$$GITCONFIRM" in \
			[yY]) \
				rm -rf .git; \
				echo "  Removed .git — bag is ready for transfer."; \
				;; \
			*) \
				echo "  Kept .git."; \
				;; \
		esac; \
	fi

clean:
	@rm -f $(BAG_FILES)