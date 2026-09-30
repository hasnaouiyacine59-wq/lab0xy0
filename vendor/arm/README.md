# Vendor Arm material

This directory holds **unmodified vendor archives** supplied by Arm. Nothing here
may be edited, re-packed, re-compressed or "cleaned up".

## Primary source (this phase)

```text
AX504X08X-SW-99002-r54p0-01eac0.tar.gz
```

| Field | Value | Status |
|---|---|---|
| Archive name | `AX504X08X-SW-99002-r54p0-01eac0.tar.gz` | VERIFIED |
| Size | 1098708 bytes | VERIFIED |
| SHA-256 | `3b2049aa9b41b540850e23e5a86613f796c6f2f6878ee8233e2c03e5c2acc121` | VERIFIED |
| Release identifier | `r54p0-01eac0` | VERIFIED (`drivers/gpu/arm/midgard/Kbuild:66`, `MALI_RELEASE_NAME ?= '"r54p0-01eac0"'`) |
| File count in archive | 441 files | VERIFIED |
| License | GPL-2.0 | VERIFIED |

r54p0 is primary **because the supplied Arm virtual-device patch series targets
r54p0**. See `../../analysis/virtual-device.md` and `../../analysis/kbase-version.md`.

Original location before it was placed here:

```text
~/Downloads/AX504X08X-SW-99002-r54p0-01eac0.tar.gz
```

The copy was verified byte-identical (`cmp`) and the SHA-256 was recomputed after
the copy.

## COMPARISON / SUPERSEDED PROVENANCE

Comparison source. Provenance only, NOT vendored here, NOT the primary build target
for this phase.

```text
AX504X08X-SW-99002-r56p0-18eac0.tar.gz
```

| Field | Value | Status |
|---|---|---|
| SHA-256 | `1f7ad4d058bb993a95714d7823f279df9097ae45efe622970a53373217fa92f4` | VERIFIED |
| Release identifier | `r56p0-18eac0` | VERIFIED (`Kbuild:75`) |
| File count in archive | 454 files | VERIFIED |
| License | GPL-2.0 | VERIFIED |

This tarball is **intentionally not stored in this repository**. It remains at:

```text
~/Downloads/AX504X08X-SW-99002-r56p0-18eac0.tar.gz
```

Its extracted tree is also present in the working directory and is git-ignored:

```text
./AX504X08X-SW-99002-r56p0-18eac0/
```

A third variant, `VX504X08X-SW-99002-r56p0-19eac0/` (release id `r56p0-19eac0`,
489 files), also appeared in the working directory during this phase. It is
**NOT** analysed, vendored or in scope. Status: NOT TESTED.

### Why r56p0 is not primary

VERIFIED: the six supplied virtual-device patches were authored against r54p0.
Against r56p0 only patch `0004` applies. See `../../analysis/virtual-device.md`.

r56p0 is **not** newer-and-therefore-better for this project's purposes; it simply
does not match the supplied patch series.

### DECISION-3 — r54p0 stays primary, r56p0 is comparison only

Locked 2026-09-30:

```text
DECISION-3:  r54p0-01eac0  = PRIMARY (build target)
             r56p0-18eac0  = COMPARISON / SUPERSEDED (reference only)
             r56p0-19eac0  = NOT ANALYSED, out of scope
             Porting the six patches to r56p0 = OUT OF SCOPE this phase
```

Rationale, in order of weight:

1. The supplied patch series applies to r54p0 (6/6) and only partially to r56p0
   (1/6). Porting would be new engineering, not verification.
2. The program's in-scope branch is the latest drivers **or** r49p1+ on a supported
   OEM device; r54p0 satisfies the r49p1+ branch, so "newest available archive" is
   not a requirement (`../../research/program-scope.md` §8.1).
3. r54p0 is the only release whose x86 virtual path has been reproduced (patch
   applicability) in this repository.

Consequence for the build phase: every build, config fragment, and patch run targets
**r54p0 only**. r56p0 is kept solely to answer "does upstream Kbase already handle
x86 better?", which is a question about *upstream fixes*, not about porting.

## Licensing — VERIFIED, no longer uncertain

Earlier drafts of this plan flagged redistribution/licensing as "unclear". That
uncertainty is now **resolved by direct evidence**:

- `driver/product/kernel/license.txt` line 1: *"GPLV2 LICENCE AGREEMENT FOR MALI
  GPUS LINUX KERNEL DEVICE DRIVERS SOURCE CODE"*
- The same file embeds the full GNU General Public License Version 2 text.
- 439 of the 441 files carry `SPDX-License-Identifier` headers
  (VERIFIED count).

Therefore the Kbase source is **GPL-2.0**, and redistribution inside this Git
repository is permissible provided the GPL-2.0 terms are honoured and the archive
is preserved unmodified — which it is.

Note that this covers **Arm's source**. It is not the same as licensing this
repository's own documentation and scripts; see `../../LICENSE`.

## Rules

1. Never modify an archive in this directory.
2. Recompute and record checksums whenever a file here changes.
3. Extraction happens **outside** the repository (a scratch directory), never into
   Git. Extracted trees are ignored by `.gitignore`.
4. Do not download additional vendor archives without an explicit instruction.
