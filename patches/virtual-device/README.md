# Arm virtual-device patch series (vendor, supplied)

These are the **supplied Arm patches**, extracted byte-for-byte from
`patches_for_virtual_device.zip` (which came from `archive-1790605485/`).
They are preserved exactly as received.

## Integrity

Verify at any time:

```bash
cd patches/virtual-device && sha256sum -c SHA256SUMS
```

All six currently verify `OK`. Every file was compared byte-for-byte against the
copy inside the zip after extraction (VERIFIED).

**Do not** edit, reformat, normalise line endings, rewrap or reorder these files.
Their content is evidence.

## Original filenames and order

Apply in **numeric order**; they are not independent.

| # | Filename | SHA-256 (first 12) |
|---|---|---|
| 0001 | `0001-mali-fix-build-error-for-CONFIG_OF-n-for-4.1-kernels.patch` | `3dd4aa225f6f` |
| 0002 | `0002-Fix-x86-build-error-for-missing-asm-arch_timer.h.patch` | `db7301a6da6e` |
| 0003 | `0003-Workaround-arch_timer-funcs-undefined-for-NO_MALI.patch` | `9db93cdb67f2` |
| 0004 | `0004-Workaround-no-definition-of-dmb-in-non-Arm-platforms.patch` | `7db506f2d651` |
| 0005 | `0005-Fix-unused-function-warnings.patch` | `530a10017e36` |
| 0006 | `0006-Fix-make-clean-when-no-arbitration-code-present.patch` | `1969eade0171` |

Note the internal `Subject:` headers read `[PATCH 1/4]` … `[PATCH 6/6]`. The series
was shipped as two upstream mail threads (1–4, then 5–6). The `NNNN-` filename
prefixes define the order that matters.

## Intended Kbase target

**r54p0** — i.e. `AX504X08X-SW-99002-r54p0-01eac0`.

Arm's own virtual-platform guide states verbatim:

> "The patches apply cleanly to the Mali 5th Gen GPU Kernel Driver source,
> version r54p0. They may need to be ported to work on other driver versions."

VERIFIED: 9 of 10 patch pre-image blob hashes match the r54p0 archive exactly.

## How to apply

Arm's guide shows `patch -p3 -i "$patch_file"`. In practice the form verified
here is:

```bash
patch -p1 -d <driver-tree>
```

where `<driver-tree>` is the directory containing `product/`, i.e. the `driver/`
directory of the extracted Kbase source. The patch paths are
`product/kernel/...`, and the Kbase payload is unpacked at
`<archive-root>/driver/product/kernel/`.

Equivalent verified form using git:

```bash
cd <driver-tree>
git apply -p1 ../../patches/virtual-device/0001-*.patch   # and so on, in order
```

`git apply --check -p1` is the non-mutating pre-flight test.

## Applicability — VERIFIED by reproduction

Both columns were reproduced in this repository on **fresh extractions** of each
archive, using the same method (`git apply --check -p1` from the `driver/`
directory). See `../../analysis/virtual-device.md` for per-patch detail.

| Patch | r54p0 | r56p0 |
|---|---|---|
| 0001 | VERIFIED applies cleanly | VERIFIED fails |
| 0002 | VERIFIED applies cleanly | VERIFIED fails |
| 0003 | VERIFIED applies cleanly | VERIFIED fails |
| 0004 | VERIFIED applies cleanly | VERIFIED applies cleanly |
| 0005 | VERIFIED applies cleanly | VERIFIED fails |
| 0006 | VERIFIED applies cleanly | VERIFIED fails |

Against r54p0, applying all six in order to a pristine tree produced the expected
guards in the resulting source (`mali_hw_access.h` ARM/ARM64 guard,
`dmb()` definition, `Kbuild` `ifneq` wrapper). That confirms **application**, not
**compilation** — no kernel has been built yet (NOT TESTED).

## What these patches are, and are not

These patches exist to make the Kbase driver **build and run on a non-Arm
(x86_64) virtual platform**. They fix build-system and API-portability problems.

They are **not** security findings, and fixing a build error is **not** a
vulnerability. In particular:

- Patch 0006 repairs a **dangling build-system reference** in `Kbuild`. That is a
  build-system defect, not a security vulnerability. Security classification:
  **NOT ESTABLISHED**. See `../../analysis/findings.md`.

Do not cite these patches as vulnerabilities, and do not describe the resulting
virtual-device behaviour as a production-device vulnerability without
independent evidence.

## Separation of categories

| Directory | Contents |
|---|---|
| `patches/virtual-device/` | these supplied Arm vendor patches (never edited) |
| `kernel/patches/` | future **research-authored** Linux-kernel patches |
| `vendor/arm/` | unmodified vendor archives |

These three categories must never be mixed.
