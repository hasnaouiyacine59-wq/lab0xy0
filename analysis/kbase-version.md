# Kbase version identification

Purpose: reproducibility and target selection. This document does **not** rank the
releases or argue that one is "better".

## Releases in scope

### Primary

```text
r54p0-01eac0        <- PRIMARY build target (DECISION-3)
```

| Field | Value | Status |
|---|---|---|
| Archive | `AX504X08X-SW-99002-r54p0-01eac0.tar.gz` | VERIFIED |
| SHA-256 | `3b2049aa9b41b540850e23e5a86613f796c6f2f6878ee8233e2c03e5c2acc121` | VERIFIED |
| `MALI_RELEASE_NAME` | `r54p0-01eac0` | VERIFIED (`Kbuild:66`) |
| Files | 441 | VERIFIED |
| License | GPL-2.0 | VERIFIED |
| Vendored at | `vendor/arm/` | VERIFIED |
| GPU targets defined | 18, newest `tDRx` (arch 14.8.5) | VERIFIED (`mali_kbase_model_dummy.c:428`) |
| Kernel gates | 44, `3.17.0`–`6.13.0` | VERIFIED |

### Comparison

```text
r56p0-18eac0        <- COMPARISON / SUPERSEDED, reference only (DECISION-3)
```

| Field | Value | Status |
|---|---|---|
| Archive | `AX504X08X-SW-99002-r56p0-18eac0.tar.gz` | VERIFIED |
| SHA-256 | `1f7ad4d058bb993a95714d7823f279df9097ae45efe622970a53373217fa92f4` | VERIFIED |
| `MALI_RELEASE_NAME` | `r56p0-18eac0` | VERIFIED (`Kbuild:75`) |
| Files | 454 | VERIFIED |
| License | GPL-2.0 | VERIFIED |
| Location | stays in `~/Downloads`; extracted tree git-ignored | VERIFIED |

### Observed, out of scope

```text
r56p0-19eac0
```

Present as an extracted tree `VX504X08X-SW-99002-r56p0-19eac0/` (489 files,
`MALI_RELEASE_NAME ?= '"r56p0-19eac0"'` at `Kbuild:81`). No archive checksum is
recorded. **NOT TESTED / NOT ANALYSED.** Recorded only so a future session knows
this variant exists and was deliberately excluded.

## Source layout — VERIFIED

Both releases share the same payload root:

```text
driver/product/kernel/
├── Documentation/
├── drivers/{base,gpu,hwtracing}/...
├── include/{linux,uapi}/...
├── Kbuild / Kconfig / Mconfig / Makefile / build.bp / BUILD.bazel
└── license.txt
```

r54p0 additionally has **no** `config/` directory; r56p0 does
(`config/fragment/*.fragment`, `config/cflags.bzl`), which is an Android
config-fragment mechanism r54p0 lacks.

## Differences material to the virtual-device path — VERIFIED

### 1. Patch applicability (decisive for target selection)

| Patch | r54p0 | r56p0 |
|---|---|---|
| 0001 | VERIFIED applies | VERIFIED fails |
| 0002 | VERIFIED applies | VERIFIED fails |
| 0003 | VERIFIED applies | VERIFIED fails |
| 0004 | VERIFIED applies | VERIFIED applies |
| 0005 | VERIFIED applies | VERIFIED fails |
| 0006 | VERIFIED applies | VERIFIED fails |

Corroborating evidence: **9 of 10** patch pre-image blob hashes match r54p0
exactly; none match r56p0. Arm's guide independently states the series targets
r54p0.

**Conclusion (VERIFIED): the supplied series is an r54p0 series.** r56p0 has
moved past what five of the six patches fix.

### 2. Why the patches no longer apply to r56p0 — VERIFIED

r56p0 has natively absorbed the intent of patches 0001, 0002, 0003 and 0005:

| Patch intent | r56p0 state |
|---|---|
| 0001 `CONFIG_OF=n` guard | already `#if !defined(CONFIG_SPARC) && defined(CONFIG_OF)` (`version_compat_defs.h:567`) |
| 0002 guard `asm/arch_timer.h` | already `#ifdef CONFIG_ARM64` (`mali_kbase_model_dummy.c:37`) |
| 0003 NO_MALI timer workaround | refactored to `kbase_arch_timer_get_cntfrq(kbdev)`; clk trace also matches `xlnx,versal` |
| 0005 unused-function guards | `#ifdef CONFIG_OF` / `#if IS_ENABLED(CONFIG_OF)` already present in `mali_kbase_devfreq.c` and `mali_kbase_device.c` |
| 0006 arbitration guard | `CONFIG_MALI_HAS_VIRTUALIZATION` **does not exist anywhere in r56p0** |

Patch 0004 (`dmb()`) still applies to r56p0 because `dmb(osh)` is still called
unguarded in `mali_kbase_csf.c` (lines 875, 917, 3641) and `dmb` is still
undefined in the compat header.

### 3. `MALI_CSF_SUPPORT` default — VERIFIED

| Release | `Kconfig` default |
|---|---|
| r54p0 | `default n` |
| r56p0 | `default y` |

Both must be set explicitly for the intended CSF configuration; on r54p0 it is
**not** the default.

### 4. CSF support — VERIFIED (both)

Present in both, build-gated by `CONFIG_MALI_CSF_SUPPORT` and pulled in by
`midgard/Kbuild`:

```make
ifeq ($(CONFIG_MALI_CSF_SUPPORT),y)
    INCLUDE_SUBDIR += $(src)/csf/Kbuild
endif
```

### 5. `MALI_KCOV` — VERIFIED (both)

| Release | In `Kconfig`? | In `Mconfig`? | In `Kbuild`? |
|---|---|---|---|
| r54p0 | **no** | yes (`depends on MALI_MIDGARD && MALI_DEBUG`) | **no (0 occurrences)** |
| r56p0 | **no** | yes (`depends on MALI_MIDGARD && MALI_DEBUG`) | **no (0 occurrences)** |

Identical situation in both releases: the symbol exists only in the Android/SoC
`Mconfig`, and its coverage compiler flags live only in the SCons/Android
`Makefile`. See `kconfig-dependencies.md` and `findings.md` — this is the single
largest risk to the coverage-guided fuzzing plan.

### 6. x86 handling — VERIFIED (both)

Both releases contain explicit `CONFIG_X86_64` / `CONFIG_X86_32` branches in
`mali_kbase_reg_track.c` for CPU VA width. Neither release's `Kbuild`/`Mconfig`
adds anything else x86-specific.

### 7. Kernel-version gates — VERIFIED

| Release | Distinct `KERNEL_VERSION` gates | Lowest | Highest |
|---|---|---|---|
| r54p0 | 44 | 3.17.0 | **6.13.0** |
| r56p0 | 48 | 3.17.0 | **6.18.0** |

> Correction: the `3.17.0 → 6.18.0` range in the project brief belongs to **r56p0**.
> For the r54p0 primary target the observed gate span is **3.17.0 → 6.13.0**.

These are **observed source conditionals**, not a support statement. See
`kernel-compatibility.md`.

### 8. File-layout differences material to patching — VERIFIED

| Item | r54p0 | r56p0 |
|---|---|---|
| `drivers/gpu/arm/midgard/arbiter/` | present (6 files) | **absent** |
| `config/` fragment dir | absent | present |
| `Documentation/devicetree/bindings/arm/arm,coresight-mali-source.yaml` | absent | present |

r54p0 contains `arbiter/` while its `Kbuild:133` still references `../arbitration/`
— see `findings.md`. r56p0 has neither the dangling reference nor `arbiter/`.

## Target selection rationale

r54p0 is primary because the **supplied** patch series is an r54p0 series
(VERIFIED). Being newer is not a reason to prefer r56p0: for this project's
specific goal — reuse the supplied virtual-device patches to get a Kbase virtual
GPU running under QEMU — r56p0 would require porting five of six patches, or
independently re-deriving each fix.

Both are retained and kept clearly separated. Neither is declared superior in any
general sense.

**DECISION-3 (locked 2026-09-30)** formalises the above and adds the program-scope
argument:

```text
DECISION-3:  r54p0-01eac0 = PRIMARY     (build target, all configs and patches)
             r56p0-18eac0 = COMPARISON  (reference for upstream fixes only)
             r56p0-19eac0 = OUT OF SCOPE
             Porting patches to r56p0  = NOT DONE this phase
```

The program's in-scope branch is "latest drivers, **or** r49p1+ on a supported
OEM device"; r54p0 qualifies on the r49p1+ branch, so archive recency is not a
requirement (`../research/program-scope.md` §8.1). Deciding against porting keeps
this phase a verification phase rather than an engineering phase, and the only
thing r56p0 can still answer is "has upstream already fixed this?" — a question
about upstream behaviour, not about local patch porting.

## Not yet verified

- Compilation of either release on any kernel (NOT TESTED).
- Whether r56p0 needs *any* ported patches in practice (NOT TESTED; deliberately
  unanswered while porting is out of scope).
- Whether r54p0's `arbiter/` absence is intentional upstream or an artefact
  (UNKNOWN).
- Whether r54p0's newest GPU target `tDRx` initialises in the `MALI_NO_MALI` path
  (NOT TESTED; DECISION-2).
