# Source inventory — Kbase r54p0

Evidence for every value here was produced by inspecting the extracted
`AX504X08X-SW-99002-r54p0-01eac0.tar.gz`. All paths are relative to the payload
root `driver/product/kernel/`.

## Archive identity — VERIFIED

| Field | Value |
|---|---|
| Archive | `AX504X08X-SW-99002-r54p0-01eac0.tar.gz` |
| Size | 1098708 bytes |
| SHA-256 | `3b2049aa9b41b540850e23e5a86613f796c6f2f6878ee8233e2c03e5c2acc121` |
| Release identifier | `r54p0-01eac0` |
| License | GPL-2.0 |

Release identifier source, `drivers/gpu/arm/midgard/Kbuild:66`:

```make
MALI_RELEASE_NAME ?= '"r54p0-01eac0"'
```

This string is what the driver reports to userspace through
`KBASE_IOCTL_VERSION` / `KERNEL_SIDE_DDK_VERSION_STRING`
(`mali_kbase_core_linux.c:113`: `"K:" MALI_RELEASE_NAME "(GPL)"`).

> Note: Arm's how-to guide shows sample output `mali mali.0: Kernel DDK version
> r54p0-00eac0`. That differs from the source's `r54p0-01eac0` (`00` vs `01`).
> Recorded as an unresolved documentation discrepancy, not reconciled.

## File count — VERIFIED, and a correction

| Source | File count |
|---|---|
| **r54p0 (primary)** | **441** |
| r56p0 (comparison) | 454 |

> The figure `454 files` appearing in the project brief for r54p0 is
> **incorrect for r54p0** — 454 is the r56p0 count. r54p0 contains **441** files.
> Verified two ways: the tar listing contains 441 non-directory entries, and a
> clean extraction (excluding a scratch `.git`) yields 441 files, with the file
> lists identical.

The r54p0 archive stores no explicit directory entries, so `tar -tzf` shows 441
lines, all files.

## Build-metadata file census — VERIFIED

| Kind | Count | Role |
|---|---|---|
| `Kbuild` | 31 | **upstream in-tree kernel build** system |
| `Kconfig` | 7 | **upstream in-tree** Kconfig symbols |
| `Mconfig` | 6 | **Android / SoC (SCons)** build system |
| `BUILD.bazel` | 5 | Android Bazel build |
| `build.bp` | 11 | Android Soong build |
| `Makefile` | 5 | SCons / Android build |
| `*.c` | 157 | C sources |
| `*.h` | 208 | headers |
| `*.rst` | 2 | documentation |
| `*.yaml` | 1 | devicetree binding |
| SPDX-tagged files | 439 of 441 | licensing headers |

The `Kconfig` vs `Mconfig` split is **not** cosmetic — it materially affects which
options exist. See `kconfig-dependencies.md`.

## Top-level layout

```text
driver/product/kernel/
├── Kconfig              (not at root; see below)
├── Documentation/
├── drivers/
├── include/
├── license.txt
├── build.bp
├── config/               (present in r56p0; NOT in r54p0)
└── Mconfig
```

Three payload roots exist: `Documentation/`, `drivers/`, `include/`, plus
`license.txt`, `build.bp`, `Mconfig`, `Kconfig` entry stubs.

`Documentation/` contents (VERIFIED):

```text
Documentation/ABI/testing/sysfs-device-mali
Documentation/ABI/testing/sysfs-device-mali-coresight-source
Documentation/csf_sync_state_dump.rst
Documentation/devicetree/bindings/arm/arm,coresight-mali-source.yaml   (r56p0 only)
Documentation/devicetree/bindings/arm/mali-midgard.txt
Documentation/devicetree/bindings/arm/memory_group_manager.txt
Documentation/devicetree/bindings/arm/priority_control_manager.txt
Documentation/devicetree/bindings/arm/protected_memory_allocator.txt
Documentation/devicetree/bindings/power/mali-opp.txt
Documentation/dma-buf-test-exporter.rst
```

## Driver directories — VERIFIED

```text
drivers/gpu/arm/midgard/
├── arbiter/      <-- the ACTUAL arbitration implementation (6 files)
├── backend/
├── context/
├── csf/          <-- Command Stream Frontend
├── debug/
├── device/
├── gpu/
├── hw_access/
├── hwcnt/
├── ipa/
├── mmu/
├── platform/     <-- devicetree, meson, vexpress, vexpress_1xv7_a57,
│                     vexpress_6xvirtex7_10mhz
├── tests/        <-- KUTF kernel unit test framework
├── thirdparty/
└── tl/
```

`drivers/base/arm/` holds the memory-group-manager and
protected-memory-allocator subsystems.

## CSF-related locations — VERIFIED

- Driver: `drivers/gpu/arm/midgard/csf/` (58 files, incl. `mali_kbase_csf.c`)
- Conditionally included by `midgard/Kbuild`:

  ```make
  ifeq ($(CONFIG_MALI_CSF_SUPPORT),y)
      INCLUDE_SUBDIR += $(src)/csf/Kbuild
  endif
  ```

- No-MALI firmware stub: `csf/mali_kbase_csf_firmware_no_mali.c`
- UAPI: `include/uapi/gpu/arm/midgard/csf/mali_kbase_csf_ioctl.h`,
  `mali_base_csf_kernel.h`, `mali_kbase_csf_errors_dumpfault.h`,
  `mali_kbase_csf_mem_flags.h`

## Virtual-device-related locations — VERIFIED

| Path | Relevance |
|---|---|
| `drivers/gpu/arm/midgard/platform/vexpress/` | Arm's "Simulated Platform Device" platform file — the x86 path |
| `drivers/gpu/arm/midgard/platform/vexpress/mali_kbase_config_vexpress.c` | supplies fake I/O resource table |
| `drivers/gpu/arm/midgard/mali_kbase_platform_fake.c` | creates `platform_device_alloc("mali", 0)` from that table |
| `drivers/gpu/arm/midgard/backend/gpu/mali_kbase_model_dummy.c` | the "dummy model" / No-Mali GPU |
| `drivers/gpu/arm/midgard/arbiter/` | arbiter power-management code |
| `drivers/gpu/arm/midgard/csf/mali_kbase_csf_firmware_no_mali.c` | substitutes for real CSF firmware |

The Simulated Platform Device mechanism is VERIFIED as
`platform_device_alloc("mali", 0)` (`mali_kbase_platform_fake.c:91`) fed by
`kbase_get_platform_config()->io_resources`. This is precisely the
Device-Tree-free mechanism Arm describes for x86 guests.

`platform/vexpress/` exists in both r54p0 and r56p0 (VERIFIED).

## Architecture-specific code — VERIFIED

Direct `CONFIG_*` architecture conditionals in r54p0:

| File | Line | Guard |
|---|---|---|
| `mali_kbase_reg_track.c` | 75 | `#if defined(CONFIG_ARM64)` → `VA_BITS` |
| `mali_kbase_reg_track.c` | 80 | `#elif defined(CONFIG_X86_64)` → `47` |
| `mali_kbase_reg_track.c` | 85 | `#elif defined(CONFIG_ARM) \|\| defined(CONFIG_X86_32)` → `sizeof(void*)*8` |
| `mali_kbase_reg_track.c` | 88 | `#else` → `#error "Unknown CPU VA width for this architecture"` |
| `device/mali_kbase_device.c` | 271, 277 | `#if IS_ENABLED(CONFIG_ARM64)` |
| `backend/gpu/mali_kbase_model_dummy.c` | 37 | `#ifdef CONFIG_ARM64` |
| `mali_kbase_smc.c` / `.h` | 22 / 25 | `#if IS_ENABLED(CONFIG_ARM64)` |
| `mali_kbase_reg_track.c` | 75–88 | ARM64, **X86_64**, ARM, **X86_32** |

Two facts follow directly and are important for this project:

1. Kbase already contains **explicit x86 CPU-VA-width handling** in both r54p0 and
   r56p0. Non-Arm is anticipated by the source, not merely patched in afterwards.
2. Everywhere else, ARM-specific headers (`asm/arch_timer.h`) are included
   unguarded — which is what patches 0002/0003 address.

After patch 0002 the guard becomes `IS_ENABLED(CONFIG_ARM) || IS_ENABLED(CONFIG_ARM64)`
(notably **not** x86), i.e. the include is dropped on non-Arm and a dummy
frequency substituted instead (patch 0003).

## Architecture summary

```text
Host architecture:        x86_64                    VERIFIED
Target guest architecture: x86_64                  VERIFIED (project goal)
Kbase architecture:        ARM GPU driver, portable
                           to a non-Arm HOST CPU       VERIFIED (x86 VA handling in source)
Non-Arm compatibility:     partially built-in; the
                           supplied patches complete
                           it for building/running
                           on x86_64               VERIFIED (see virtual-device.md)
Virtual-device mechanism:  "Simulated Platform Device",
                           CONFIG_MALI_PLATFORM_NAME="vexpress"   VERIFIED
CSF support:               present, build-gated by
                           CONFIG_MALI_CSF_SUPPORT;
                           Kconfig default is n in r54p0   VERIFIED
CONFIG_MALI_NO_MALI:       required for hardware-free
                           simulation; depends on MALI_EXPERT   VERIFIED
CONFIG_OF:                 expected **n** on the x86
                           Simulated Platform path               VERIFIED (Arm guide + patch 0001)
Platform:                  platform/vexpress present            VERIFIED
```

## Not yet verified

- That the source **compiles** on any particular kernel (NOT TESTED — no build).
- That `insmod` succeeds, or that `/dev/mali0` appears (NOT TESTED).
- Which of the 441 files are actually reached by the chosen configuration.
