# Kconfig dependencies — Kbase r54p0

All dependencies below were read directly from r54p0 source. Nothing is inferred.

## The `Kconfig` vs `Mconfig` split — VERIFIED, and it matters

r54p0 ships **two parallel symbol sets** for the same driver:

| File | Role |
|---|---|
| `drivers/gpu/arm/midgard/Kconfig` | **upstream in-tree kernel build** |
| `drivers/gpu/arm/midgard/Mconfig` | **Android / SoC (SCons) build** |

The in-tree wiring is VERIFIED — `drivers/gpu/arm/Kconfig` sources only the
`Kconfig`, never the `Mconfig`:

```text
menu "ARM GPU Configuration"
source "$(MALI_KCONFIG_EXT_PREFIX)drivers/gpu/arm/midgard/Kconfig"
endmenu
```

and `midgard/Kconfig:340` sources `midgard/tests/Kconfig`.

`Mconfig` is not reachable from the in-tree path. This distinction invalidates
copying dependency statements from the wrong file. Concretely:

| Symbol | In `Kconfig` | In `Mconfig` |
|---|---|---|
| `MALI_MIDGARD` | yes (`tristate`) | yes (`bool`, `default y`) |
| `MALI_DEVFREQ` | yes (`depends on MALI_MIDGARD && PM_DEVFREQ`) | yes (`depends on MALI_MIDGARD` only) |
| `MALI_CSF_SUPPORT` | yes (`default n`) | yes (`default y if GPU_HAS_CSF`) |
| `MALI_NO_MALI_DEFAULT_GPU` | **yes** | **no** |
| `MALI_KCOV` | **NO** | **yes** |

> `MALI_DEVFREQ`'s `PM_DEVFREQ` dependency is present in the **`Kconfig`**, which
> is the file that governs the in-tree build. The `Mconfig` variant omits it.

## Verified dependencies (in-tree / `Kconfig`)

### `MALI_MIDGARD` — the gate symbol

```text
drivers/gpu/arm/midgard/Kconfig:21
menuconfig MALI_MIDGARD
	tristate "Mali Midgard series support"
	select DMA_SHARED_BUFFER
	select PM_DEVFREQ
	select DEVFREQ_THERMAL
	select FW_LOADER
	default n
```

VERIFIED:

- It is **`tristate`**, so `=m` is valid — this matches Arm's documented
  `CONFIG_MALI_MIDGARD=m`.
- It `select`s four kernel symbols, three of which are **hard build gates** (below).

### Hard build gates — VERIFIED

`drivers/gpu/arm/midgard/Kbuild:29-39` turns these into unconditional build
errors (note: **not** wrapped in `ifeq ($(CONFIG_MALI_MIDGARD),...)`):

```make
ifeq ($(CONFIG_DMA_SHARED_BUFFER),n)
    $(error CONFIG_DMA_SHARED_BUFFER must be set in Kernel configuration)
endif

ifeq ($(CONFIG_PM_DEVFREQ),n)
    $(error CONFIG_PM_DEVFREQ must be set in Kernel configuration)
endif

ifeq ($(CONFIG_DEVFREQ_THERMAL),n)
    $(error CONFIG_DEVFREQ_THERMAL must be set in Kernel configuration)
endif
```

Implication, INFERRED (not yet demonstrated by a build): because these are
evaluated when the `Kbuild` is parsed, they fire whenever Kbase is built at all,
and because the test is `=n` rather than unset, an unset symbol (empty string)
will **not** trigger the error — which makes silent misconfiguration possible.

### `MALI_NO_MALI`

```text
drivers/gpu/arm/midgard/Kconfig:56   (and Mconfig:56)
config MALI_NO_MALI
	bool "Enable build of Mali kernel driver for No Mali"
	depends on MALI_MIDGARD && MALI_EXPERT
```

VERIFIED dependency: **`MALI_NO_MALI` requires `MALI_EXPERT`.**
### `MALI_EXPERT`

```text
drivers/gpu/arm/midgard/Kconfig:153-156
menuconfig MALI_EXPERT
	depends on MALI_MIDGARD
	bool "Enable Expert Settings"
	default n
```

VERIFIED (re-read from r54p0 `Kconfig`): it defaults to **`n`**, *not* `y`. (An
earlier revision of this document wrongly recorded `default y`; that value is from
the Android/SCons `Mconfig:149`, which the in-tree build does not read.)

Because `MALI_NO_MALI`, `MALI_DEBUG`, and `LARGE_PAGE_SUPPORT` all live inside
`if MALI_EXPERT`, an in-tree build must set **`MALI_EXPERT=y` explicitly** before
any of them can be selected.

### `MALI_DEBUG`

```text
drivers/gpu/arm/midgard/Kconfig:194-197
config MALI_DEBUG
	bool "Enable debug build"
	depends on MALI_MIDGARD && MALI_EXPERT
	default n
```

VERIFIED (re-read from r54p0 `Kconfig`): default is **`n`**. (An earlier revision
recorded `default y if DEBUG`; that is not present in the in-tree `Kconfig`.)

Program policy requires `CONFIG_MALI_DEBUG=n` explicitly (§8.3 of
`../research/program-scope.md`) and does **not** list `MALI_DEBUG` among the
changeable options, so any `MALI_DEBUG=y` profile is non-conforming for validation.

### `MALI_NO_MALI_DEFAULT_GPU`

```text
drivers/gpu/arm/midgard/Kconfig:69
config MALI_NO_MALI_DEFAULT_GPU
	string "Default GPU for No Mali"
	depends on MALI_NO_MALI
	default "tMIx"
```

VERIFIED: exists **only in `Kconfig`** (not `Mconfig`), requires `MALI_NO_MALI`,
and defaults to `"tMIx"`.

> **RESOLVED — see DECISION-2 / F-4 below.** The default is `"tMIx"`, the
> **oldest** GPU; Arm's virtual platform guide prescribes `"tKRx"`, the
> **second-newest**. Neither is the latest. r54p0 defines 18 targets and the newest
> is `"tDRx"` (arch 14.8.5). "Target the latest GPU when compiling" therefore means
> `CONFIG_MALI_NO_MALI_DEFAULT_GPU="tDRx"`. Whether Arm used `tKRx` because the
> guide predates tDRx support is **UNKNOWN**.
>
> The value is read at `mali_kbase_model_dummy.c:527-529`
> (`static char *no_mali_gpu = CONFIG_MALI_NO_MALI_DEFAULT_GPU;`) and is exposed as
> the `no_mali_gpu` module parameter, but the program's dynamic-config policy does
> **not** permit overriding it at `insmod` time
> (`../research/program-scope.md` §8.4), so it is set at compile time.

### `MALI_CSF_SUPPORT`

```text
drivers/gpu/arm/midgard/Kconfig:80
config MALI_CSF_SUPPORT
	bool "Enable Mali CSF based GPU support"
	depends on MALI_MIDGARD
	default n
```

VERIFIED: **defaults to `n` in r54p0.** Arm's x86 config sets it `y` explicitly, so
this default does not override the intent — but it means the CSF code is **not**
built unless requested.

### `MALI_PLATFORM_NAME`

```text
drivers/gpu/arm/midgard/Kconfig:36
config MALI_PLATFORM_NAME
	depends on MALI_MIDGARD
	string "Platform name"
	default "devicetree"
```

VERIFIED: `string`, default `"devicetree"`. For the x86 Simulated Platform Device
Arm prescribes `"vexpress"`, and `platform/vexpress/Kbuild` exists (VERIFIED).

## Kbase build-configuration allowlist (program policy) — VERIFIED

This is the program's Kbase-module allowlist (distinct from the *kernel* allowlist
in `research/program-scope.md` §5). Captured in full in `../research/program-scope.md`
§8.3; repeated here only as a source-reconciliation table.

```text
Mali Kbase Default KConfig Build Options are used.
Must be set:              CONFIG_MALI_DEBUG=n
May be changed:           CONFIG_MALI_CSF_SUPPORT        y or n
                          CONFIG_MALI_EXPERT             y or n
                          CONFIG_LARGE_PAGE_SUPPORT      y or n
                          CONFIG_MALI_TRACE_POWER_GPU_WORK_PERIOD  y or n
                          CONFIG_MALI_NO_MALI            n (default) or y
Everything else:          default
```

| Program symbol | r54p0 symbol | r54p0 default | Location |
|---|---|---|---|
| `CONFIG_MALI_DEBUG` | `MALI_DEBUG` | `n` | `Kconfig:197` |
| `CONFIG_MALI_CSF_SUPPORT` | `MALI_CSF_SUPPORT` | `n` | `Kconfig:83` |
| `CONFIG_MALI_EXPERT` | `MALI_EXPERT` | `n` | `Kconfig:156` |
| `CONFIG_LARGE_PAGE_SUPPORT` | `LARGE_PAGE_SUPPORT` | `y` | `Kconfig:166` (inside `if MALI_EXPERT`) |
| `CONFIG_MALI_TRACE_POWER_GPU_WORK_PERIOD` | `MALI_TRACE_POWER_GPU_WORK_PERIOD` | `y` | `Kconfig:333` |
| `CONFIG_MALI_NO_MALI` | `MALI_NO_MALI` | choice alternative to `MALI_REAL_HW` | `Kconfig:56` |

Note: the program writes `CONFIG_LARGE_PAGE_SUPPORT`; the source symbol has **no**
`MALI_` prefix.

## GPU targets defined by r54p0 — VERIFIED (DECISION-2)

The accepted values for `CONFIG_MALI_NO_MALI_DEFAULT_GPU` (and the `no_mali_gpu`
module parameter) are the `.name` strings of `all_control_reg_values[]` in
`drivers/gpu/arm/midgard/backend/gpu/mali_kbase_model_dummy.c`. The array is
ordered oldest→newest and there is exactly one such table in the release (18
entries; it is the only file containing `GPU_ID2_MAKE`).

`GPU_ID2_MAKE(arch_major, arch_minor, arch_rev, product_major, version_major,
version_minor, version_status)` (`include/uapi/gpu/arm/midgard/gpu/mali_kbase_gpu_id.h:89`).

| # | Name | `GPU_ID2_MAKE(...)` | arch |
|---|---|---|---|
| 1 (fallback) | `tMIx` | 6, 0, 10, 0, 0, 1, 0 | 6.0 |
| 2 | `tHEx` | 6, 2, 0, 1, 0, 3, 0 | 6.2 |
| 3 | `tSIx` | 7, 0, 0, 0, 1, 1, 0 | 7.0 |
| 4 | `tDVx` | 7, 0, 0, 3, 0, 0, 0 | 7.0 |
| 5 | `tNOx` | 7, 2, 1, 1, 0, 0, 0 | 7.2 |
| 6 | `tGOx_r0p0` | 7, 2, 2, 2, 0, 0, 0 | 7.2 |
| 7 | `tGOx_r1p0` | 7, 4, 0, 2, 1, 0, 0 | 7.4 |
| 8 | `tTRx` | 9, 0, 8, 0, 0, 0, 0 | 9.0 |
| 9 | `tNAx` | 9, 0, 8, 1, 0, 0, 0 | 9.0 |
| 10 | `tBEx` | 9, 2, 0, 2, 0, 0, 0 | 9.2 |
| 11 | `tBAx` | 9, 14, 4, 5, 0, 0, 0 | 9.14 |
| 12 | `tODx` | 10, 8, 0, 2, 0, 0, 0 | 10.8 |
| 13 | `tGRx` | 10, 10, 0, 3, 0, 0, 0 | 10.10 |
| 14 | `tVAx` | 10, 12, 0, 4, 0, 0, 0 | 10.12 |
| 15 | `tTUx` | 11, 8, 5, 2, 0, 0, 0 | 11.8 |
| 16 | `tTIx` | 12, 8, 1, 0, 0, 0, 0 | 12.8 |
| 17 | `tKRx` | 13, 8, 1, 0, 0, 0, 0 | 13.8 |
| 18 | **`tDRx`** | **14, 8, 5, 0, 0, 0, 0** | **14.8** |

### DECISION-2 — the latest target in r54p0 is `tDRx`

```text
DECISION-2 (2026-09-30):
    Latest GPU target defined by r54p0-01eac0 = "tDRx".
    Used for the virtual discovery build because it is source-supported.
```

| Field | Value |
|---|---|
| Source location | `backend/gpu/mali_kbase_model_dummy.c:428` (last entry of `all_control_reg_values[]`) |
| Symbol / value | `.name = "tDRx"`; `.gpu_id = GPU_ID2_MAKE(14, 8, 5, 0, 0, 0, 0)` |
| Why latest | array is ordered by arch; `tDRx` is last and highest (arch_major 14) |
| vs Arm's `tKRx` | `tKRx` = 13.8.1 (entry 17, second-newest); `tDRx` is one generation newer |
| Why Arm wrote `tKRx` | **UNKNOWN** (guide may predate tDRx support, or be conservative) |
| Status | **VERIFIED** (source-defined and referenced) / **NOT_TESTED** (runtime) |

Corroborating support for `tDRx` in r54p0 (VERIFIED, separate files):

| Evidence | Location |
|---|---|
| HW feature tables `base_hw_features_tDRx_r0p0` / `_r0p1` | `mali_kbase_hwconfig_features.h:159,174` |
| HW issue tables `base_hw_issues_tDRx_r0p0` / `_r0p1` / `_model_tDRx` | `mali_kbase_hwconfig_issues.h:625-637` |
| Product id `GPU_ID_PRODUCT_TDRX` (v1) | `include/uapi/…/gpu/mali_kbase_gpu_id.h:180` |
| Product name `"Mali-TDRX"` (+ `IDRX`, `LDRX`) | `mali_kbase_core_linux.c:2516-2518` |
| IPA power model `kbase_tdrx_ipa_model_ops` | `ipa/backend/mali_kbase_ipa_counter_csf.c:342,385` |
| `DUMMY_IMPLEMENTATION_SHADER_PRESENT_TDRX` | `include/uapi/…/backend/gpu/mali_kbase_model_dummy.h:67` |
| CSF `_no_mali` arch gate `>= GPU_ID_ARCH_MAKE(14,0,0)` | `csf/mali_kbase_csf_firmware_no_mali.c:186` |

Encoding-family nuance (VERIFIED): `mali_kbase_gpu_id.h` has two product-id
families. The v2 `GPU_ID2_PRODUCT_*` defines stop at `TKRX`/`LKRX` (arch 13), while
the v1 `GPU_ID_PRODUCT_*` set extends to `IDRX`/`TDRX`/`LDRX` (arch 14), and the
dummy table encodes `tDRx` with a raw v2 `GPU_ID2_MAKE` value. `tDRx` is therefore
present in three independent places, not a stale or orphaned string.

## `MALI_KCOV` — the critical finding

### What it controls

VERIFIED from `drivers/gpu/arm/midgard/Mconfig:202`:

```text
config MALI_KCOV
	bool "Enable kcov coverage to support fuzzers"
	depends on MALI_MIDGARD && MALI_DEBUG
	default n
```

### Where it is defined

| Location | Present? |
|---|---|
| `midgard/Kconfig` | **NO** |
| `midgard/Mconfig` | **yes** |
| `midgard/Kbuild` | **NO — 0 occurrences** |
| `drivers/base/arm/Makefile:103` | yes (SCons/Android) |
| `midgard/Makefile:283` | yes (SCons/Android) |

### What code it activates

VERIFIED — both `Makefile` files add identical flags:

```make
ifeq ($(CONFIG_MALI_KCOV),y)
    CFLAGS_MODULE += $(call cc-option, -fsanitize-coverage=trace-cmp)
    EXTRA_CFLAGS += -DKCOV=1
    EXTRA_CFLAGS += -DKCOV_ENABLE_COMPARISONS=1
endif
```

So `MALI_KCOV` is a **compiler-instrumentation switch**: it compiles Kbase objects
with `-fsanitize-coverage=trace-cmp` and defines `KCOV=1` /
`KCOV_ENABLE_COMPARISONS=1`.

### Dependency answer — VERIFIED

```text
Does MALI_KCOV require MALI_DEBUG=y?     YES — VERIFIED
    depends on MALI_MIDGARD && MALI_DEBUG   (midgard/Mconfig:204)
```

Also transitively `MALI_DEBUG` → `MALI_EXPERT` → `MALI_MIDGARD`.

> **New policy conflict (VERIFIED).** `MALI_KCOV` requires `MALI_DEBUG=y`, but the
> program **mandates `CONFIG_MALI_DEBUG=n`** (`../research/program-scope.md` §8.3).
> So *any* Kbase-side coverage instrumentation is by construction
> non-conforming — it forces `MALI_DEBUG=y`. This is independent of, and adds to,
> the `Kconfig` gap below: closing F-2 makes the KCOV profile doubly
> non-conforming (kernel-side `CONFIG_KCOV` *and* Kbase-side `MALI_DEBUG=y`), so it
> is discovery-only by policy, not merely by practice.

### Consequence for an in-tree x86_64 build — VERIFIED, HIGH RISK

Because the symbol is absent from `Kconfig` **and** from `Kbuild`, and its flags
live only in the SCons/Android `Makefile` (which an in-tree build does not read):

> An in-tree upstream x86_64 build of r54p0 Kbase will **not** receive
> `-fsanitize-coverage=trace-cmp` on Kbase objects, and cannot be told to via
> `CONFIG_MALI_KCOV`, because that symbol does not exist in the `Kconfig` the
> kernel parses.

This is a **build-system gap**, not a driver defect. Linux's own `CONFIG_KCOV`
instruments kernel code, but Kbase module objects would remain uninstrumented
without an explicit fix.

**Required follow-up (PLANNED):** either

- (a) add a research-authored patch in `kernel/patches/` adding a `Kbuild`
  condition to append `-fsanitize-coverage=trace-cmp` when the coverage profile is
  selected (most direct, honours the build-once/reuse design), or
- (b) obtain/port an upstream `Kconfig` that includes the `MALI_KCOV` symbol.

Option (a) is preferred: it keeps the change in the research-patch category and
leaves vendor source untouched.

`MALI_KCOV` does **not** itself enable Linux KCOV. The two are independent:
`CONFIG_KCOV` (Linux) provides the subsystem; `MALI_KCOV` (Kbase) makes the module's
own code emit trace-cmp coverage that subsystem consumes.

## Arm's documented x86 configuration — VERIFIED from the supplied PDF

From `research/documents/arm_gpu_virtual_platform_how_to_guide.pdf`, section
*"Configuring the Linux Kernel for Mali"* for the **x86 / "Simulated Platform
Device"** path:

```text
CONFIG_MALI_MIDGARD=m
CONFIG_MALI_CSF_SUPPORT=y
CONFIG_MALI_EXPERT=y
#   -> "Enable build of Mali kernel driver for No Mali"
CONFIG_MALI_NO_MALI=y
# CONFIG_MALI_REAL_HW is not set
CONFIG_MALI_NO_MALI_DEFAULT_GPU="tKRx"
CONFIG_MALI_PLATFORM_NAME="vexpress"
```

These are recorded **exactly as Arm writes them**. They are not silently renamed
into upstream Linux symbols.

Consistency check against verified source dependencies (VERIFIED):

| Arm option | Consistent with source? |
|---|---|
| `MALI_MIDGARD=m` | yes — `MALI_MIDGARD` is `tristate` |
| `MALI_EXPERT=y` | yes — required by `MALI_NO_MALI`; note r54p0 `Kconfig:156` default is **`n`**, so Arm's explicit `=y` is load-bearing |
| `MALI_NO_MALI=y` | yes — legal because `MALI_EXPERT=y` |
| `MALI_CSF_SUPPORT=y` | legal; must be set since r54p0 default is `n` |
| `MALI_PLATFORM_NAME="vexpress"` | yes — `platform/vexpress/Kbuild` exists; **not** on the program allowlist (§8.3) |
| `NO_MALI_DEFAULT_GPU="tKRx"` | valid but not the latest; this project uses **`"tDRx"`** (DECISION-2) |

Project deviation from Arm's list (deliberate, recorded):

```text
CONFIG_MALI_NO_MALI_DEFAULT_GPU="tDRx"   # instead of Arm's "tKRx"
```

Rationale: the program says "targeting the latest GPU when compiling", and the
latest GPU defined by r54p0 is `tDRx`. Arm's `tKRx` is one generation older.

Neither Arm's option is on the program's Kbase build allowlist (§8.3), which is
why the whole x86 NO_MALI harness is INVESTIGATION/DISCOVERY-ONLY (DECISION-1).

Note Arm's x86 list does **not** mention `MALI_KCOV`, and the Arm list is not
claimed to be sufficient to build — it presumes a working kernel tree with
devfreq/dma-buf available.

From `research/documents/arm_gpu_bug_bounty_faq.pdf` (in-scope requirements):

```text
CONFIG_MALI_CSF_SUPPORT=y   for CSF GPUs
CONFIG_MALI_CSF_SUPPORT=n   for "Job Manager" GPUs
```

Generation mapping (GUIDANCE, per program text): early Valhall = Job Manager, later
Valhall = CSF; Bifrost = Job Manager. Package contents vary, so the FAQ points at
two different download pages depending on which driver is in hand:
`https://developer.arm.com/downloads/-/mali-drivers/` for the current drivers and
`https://developer.arm.com/downloads/-/Mali 5th Gen GPU Architecture` for 5th Gen
(CSF). This project tracks the r49p1+ / latest-driver branch (r54p0 satisfies it).

## Mandatory additional dependencies — VERIFIED

| Requirement | Source | Notes |
|---|---|---|
| `DMA_SHARED_BUFFER` | `Kbuild:30` `$(error)` + `MALI_MIDGARD select` | dma-buf imports |
| `PM_DEVFREQ` | `Kbuild:34` `$(error)` + `select` | `MALI_DEVFREQ` default `y` |
| `DEVFREQ_THERMAL` | `Kbuild:38` `$(error)` + `select` | also gates `ipa/Kbuild` inclusion |
| `FW_LOADER` | `MALI_MIDGARD select` | firmware loading infra |

Note `CONFIG_DEVFREQ_THERMAL=y` additionally pulls in
`drivers/gpu/arm/midgard/ipa/` via `Kbuild` (VERIFIED) — a non-obvious
configuration coupling.

## Not yet verified

- That any of this is sufficient to produce a compiling module (NOT_TESTED).
- Whether other kernel symbols are required in practice (only revealed by a build).
- Why Arm's virtual-platform guide specifies `tKRx` rather than the then-latest
  target (UNKNOWN; moot for this project — DECISION-2 uses `tDRx`).
- Whether `tDRx` initialises in the `MALI_NO_MALI` path (NOT_TESTED).
