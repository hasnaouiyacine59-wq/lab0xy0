# Virtual-device analysis — Arm Kbase patch series

Scope: the six supplied patches in `patches/virtual-device/`, and what they mean
for running Kbase's virtual GPU on a **non-Arm (x86_64)** host.

## Architecture determination

```text
Host architecture:          x86_64                        VERIFIED
Target guest architecture:  x86_64                        VERIFIED (project goal)
Kbase architecture:         ARM GPU driver, running on a
                            non-Arm CPU as a simulated
                            device                         VERIFIED
Non-Arm compatibility:      partially built into the source
                            (explicit CONFIG_X86_64 /
                            CONFIG_X86_32 handling); the
                            supplied patches complete it so
                            it can BUILD and RUN on x86_64   VERIFIED
Virtual-device mechanism:   "Simulated Platform Device",
                            CONFIG_MALI_PLATFORM_NAME="vexpress"   VERIFIED
CSF support:                present; gated by
                            CONFIG_MALI_CSF_SUPPORT; r54p0
                            Kconfig default is n          VERIFIED
CONFIG_MALI_NO_MALI:        required (no real GPU present);
                            depends on MALI_EXPERT         VERIFIED
CONFIG_OF:                  expected n on the x86 path     VERIFIED
Platform:                   platform/vexpress present     VERIFIED
```

### Evidence that x86 is anticipated by the source — VERIFIED

`drivers/gpu/arm/midgard/mali_kbase_reg_track.c:74-89`:

```c
#if defined(CONFIG_ARM64)
	/* VA_BITS can be as high as 48 bits ... */
	size_t cpu_va_bits = VA_BITS;
#elif defined(CONFIG_X86_64)
	/* x86_64 can access 48 bits of VA, but the 48th is used to denote
	 * kernel (1) vs userspace (0), so the max here is 47.
	 */
	size_t cpu_va_bits = 47;
#elif defined(CONFIG_ARM) || defined(CONFIG_X86_32)
	size_t cpu_va_bits = sizeof(void *) * BITS_PER_BYTE;
#else
#error "Unknown CPU VA width for this architecture"
#endif
```

x86_64 and x86_32 are named explicitly, with a correct comment about the
48-bit VA / 47-bit usable split. This is upstream-designed non-Arm support, not a
retrofit.

### Evidence for the Simulated Platform Device — VERIFIED

`drivers/gpu/arm/midgard/mali_kbase_platform_fake.c:82-95`:

```c
config = kbase_get_platform_config();   /* provided by platform/vexpress */
...
mali_device = platform_device_alloc("mali", 0);
kbasep_config_parse_io_resources(config->io_resources, resources);
err = platform_device_add_resources(mali_device, resources, PLATFORM_CONFIG_RESOURCE_COUNT);
```

The driver synthesises its platform device from a static resource table supplied
by `platform/vexpress/mali_kbase_config_vexpress.c`. No Device Tree is involved —
which is precisely why `CONFIG_OF=n` must work, and why patches 0001/0005 exist.

Resulting userspace surface (VERIFIED): `/dev/mali0` via
`misc_register` with `mode = 0666` (`mali_kbase_core_linux.c:4352-4356`), and
debugfs at `/sys/kernel/debug/mali0` (`mali_kbase_core_linux.c:3535`).

## Applicability matrix — VERIFIED by reproduction

Both columns reproduced on **fresh extractions**, same method
(`git apply --check -p1` from the `driver/` directory), plus blob-hash
pre-image comparison.

| Patch | r54p0 (primary) | r56p0 (comparison) | Evidence |
|---|---|---|---|
| 0001 | **VERIFIED applies** | VERIFIED FAILS | `git apply --check`; pre-image `d2bbc53` == r54p0, r56p0 is `cbc76a0` |
| 0002 | **VERIFIED applies** | VERIFIED FAILS | `git apply --check`; 6/6 pre-image blobs == r54p0 |
| 0003 | **VERIFIED applies** | VERIFIED FAILS | `git apply --check`; pre-image `106393f` == r54p0 |
| 0004 | **VERIFIED applies** | **VERIFIED applies** | `git apply --check` both |
| 0005 | **VERIFIED applies** | VERIFIED FAILS | `git apply --check`; 2/2 pre-image blobs == r54p0 |
| 0006 | **VERIFIED applies** | VERIFIED FAILS | hunk context matches r54p0; `MALI_HAS_VIRTUALIZATION` absent from r56p0 |

Applying 0001→0006 in order to a pristine r54p0 tree succeeded, and the resulting
source was re-inspected to confirm the expected changes are present (guards in
`mali_hw_access.h`, `dmb()` at `version_compat_defs.h:765`, `ifneq` wrapper at
`Kbuild:134-135`).

This verifies **application**, not compilation. No kernel has been built
(NOT TESTED).

---

## Patch 0001 — `CONFIG_OF=n` compatibility for 4.1+ kernels

```text
Patch:        0001-mali-fix-build-error-for-CONFIG_OF-n-for-4.1-kernels.patch
Subject:      mali: fix build error for CONFIG_OF=n for 4.1+ kernels
Author:       Arm PSIRT <psirt@arm.com>, 2025-02-23
Affected:     include/linux/version_compat_defs.h  (1 insertion, 1 deletion)
Problem:      VERIFIED — with CONFIG_OF=n the `of_property_*_flag` shims must not
              be defined at all on kernels >= 4.1, where the real functions exist.
              Original guard `#if KERNEL_VERSION(4,15,0) <= LINUX_VERSION_CODE`
              still compiles them on 4.1–4.14 when CONFIG_OF=n, colliding with
              kernel-provided (or missing) symbols.
Actual change: guard flipped from
                  #if KERNEL_VERSION(4, 15, 0) <= LINUX_VERSION_CODE
              to
                  #if KERNEL_VERSION(4, 1, 0) > LINUX_VERSION_CODE
Architecture impact:  none directly; enables the Device-Tree-free (x86) path.
Kernel-version impact: HIGH — inverts a version gate. After the patch the shims
              are active only below 4.1, implying a >= 4.1 target.
Kconfig impact:       depends on CONFIG_OF being off; paired with patch 0005.
r54p0 applicability:  VERIFIED APPLIES
r56p0 applicability:  VERIFIED FAILS — r56p0 already reads
              `#if !defined(CONFIG_SPARC) && defined(CONFIG_OF)` (line 567),
              a different guard that achieves the same result more precisely.
Status:        VERIFIED (applies to r54p0); NOT TESTED (compilation)
```

## Patch 0002 — missing `asm/arch_timer.h` on x86

```text
Patch:        0002-Fix-x86-build-error-for-missing-asm-arch_timer.h.patch
Subject:      Fix x86 build error for missing asm/arch_timer.h
Affected:     6 files, +12 lines (all guard-only):
              backend/gpu/mali_kbase_model_dummy.c
              backend/gpu/mali_kbase_time.c
              csf/mali_kbase_csf_firmware.c
              csf/mali_kbase_csf_firmware_no_mali.c
              platform/devicetree/mali_kbase_clk_rate_trace.c
              include/linux/mali_hw_access.h
Problem:      VERIFIED — `asm/arch_timer.h` does not exist on x86, so the
              unconditional `#include <asm/arch_timer.h>` in all six files fails
              to compile on a non-Arm target.
Actual change: wraps each include, e.g.
                  #if IS_ENABLED(CONFIG_ARM) || IS_ENABLED(CONFIG_ARM64)
                  #include <asm/arch_timer.h>
                  #endif /* IS_ENABLED(CONFIG_ARM) || IS_ENABLED(CONFIG_ARM64) */
Architecture impact:  HIGH — this is the core non-Arm include fix.
Kernel-version impact: none (pure Kconfig conditional).
Kconfig impact:       references CONFIG_ARM / CONFIG_ARM64 only; notably does
              NOT test x86, i.e. the include is simply omitted elsewhere.
r54p0 applicability:  VERIFIED APPLIES (all 6 pre-image blobs match r54p0)
r56p0 applicability:  VERIFIED FAILS — r56p0 already has
              `#ifdef CONFIG_ARM64` in mali_kbase_model_dummy.c:37.
Status:        VERIFIED (applies to r54p0); NOT TESTED (compilation)
```

## Patch 0003 — `arch_timer` functions undefined under NO_MALI

```text
Patch:        0003-Workaround-arch_timer-funcs-undefined-for-NO_MALI.patch
Subject:      Workaround arch_timer funcs undefined for NO_MALI
Affected:     platform/devicetree/mali_kbase_clk_rate_trace.c (+2)
              include/linux/mali_hw_access.h (+6)
Problem:      VERIFIED — after patch 0002 removes the header on non-Arm, the
              `arch_timer_get_cntfrq()` macro would be undefined. r56p0's own
              comment says a non-zero dummy "is required for kbase_backend_time_init".
Actual change: guards the `arm,juno` special case, and provides a fallback:
                  #if IS_ENABLED(CONFIG_ARM) || IS_ENABLED(CONFIG_ARM64)
                  #define mali_arch_timer_get_cntfrq() arch_timer_get_cntfrq()
                  #else
                  /* Dummy value for non-Arm CPUs. Non-zero required for
                     kbase_backend_time_init */
                  #define mali_arch_timer_get_cntfrq() USEC_PER_SEC
                  #endif
Architecture impact:  HIGH — substitutes a constant frequency (1 000 000 Hz)
              for non-Arm. Timer-derived GPU timestamps will be approximate on
              x86_64. INFERRED (not measured).
Kernel-version impact: none.
Kconfig impact:       depends on MALI_NO_MALI being effective.
r54p0 applicability:  VERIFIED APPLIES
r56p0 applicability:  VERIFIED FAILS — r56p0 replaced the macro with the
              device-argument function `kbase_arch_timer_get_cntfrq(kbdev)`
              (declared in mali_kbase_hwaccess_time.h:190) and its clk-rate-trace
              code now matches both `arm,juno` and `xlnx,versal`.
Status:        VERIFIED (applies to r54p0); NOT TESTED (compilation, and the
              runtime accuracy of USEC_PER_SEC timing on x86_64)
```

## Patch 0004 — missing `dmb()` on non-Arm

```text
Patch:        0004-Workaround-no-definition-of-dmb-in-non-Arm-platforms.patch
Subject:      Workaround no definition of dmb() in non-Arm platforms
Affected:     include/linux/version_compat_defs.h  (+4)
Problem:      VERIFIED — `dmb()` is Arm-specific. r54p0 calls `dmb(osh)` three
              times unguarded in csf/mali_kbase_csf.c (lines 875, 917, 3641) in
              CSF firmware I/O ordering code, and no `dmb` definition exists in
              the compat header. On x86_64 this is a compile error.
Actual change: adds at end of version_compat_defs.h:
                  #ifndef dmb
                  #define dmb(opt) mb()
                  #endif
Architecture impact:  HIGH — defines an Arm barrier in terms of the generic
              full memory barrier `mb()`, which is stronger than `dmb(osh)`.
              Semantically conservative (over-synchronising), which is safe but
              not free.
Kernel-version impact: none.
Kconfig impact:       none; purely a preprocessor fallback.
r54p0 applicability:  VERIFIED APPLIES
r56p0 applicability:  VERIFIED APPLIES — the only patch that still applies to
              r56p0, because the unguarded `dmb(osh)` calls and the missing
              definition persist there too.
Status:        VERIFIED (applies to both releases); NOT TESTED (compilation)
```

## Patch 0005 — unused-function warnings

```text
Patch:        0005-Fix-unused-function-warnings.patch
Subject:      Fix unused function warnings
Affected:     backend/gpu/mali_kbase_devfreq.c (+2)
              device/mali_kbase_device.c (+2)
Problem:      VERIFIED — `kbasep_devfreq_read_suspend_clock()` and
              `pcm_prioritized_process_cb()` are defined unconditionally but are
              only reachable when CONFIG_OF=y. With CONFIG_OF=n they are dead code,
              triggering -Wunused-function.
Actual change: wraps each in a CONFIG_OF guard:
                  #ifdef CONFIG_OF                              (devfreq.c)
                  #if IS_ENABLED(CONFIG_OF)                      (device.c)
              i.e. different guard styles in the two files.
Architecture impact:  none directly; required for CONFIG_OF=n (x86) builds.
Kernel-version impact: none, though Arm ties it to newer kernels that enable
              -Werror/-Wunused-function by default.
Kconfig impact:       both CONFIG_OF and MALI_DEVFREQ / priority-control paths.
r54p0 applicability:  VERIFIED APPLIES (2/2 pre-image blobs match r54p0)
r56p0 applicability:  VERIFIED FAILS — r56p0 already contains both guards.
Status:        VERIFIED (applies to r54p0); NOT TESTED (compilation)
```

## Patch 0006 — `make clean` with no arbitration code present

```text
Patch:        0006-Fix-make-clean-when-no-arbitration-code-present.patch
Subject:      Fix 'make clean' when no arbitration code present
Affected:     drivers/gpu/arm/midgard/Kbuild (+4)
Problem:      VERIFIED — Kbuild:133 reads
                  obj-$(CONFIG_MALI_HAS_VIRTUALIZATION) += ../arbitration/
              but no drivers/gpu/arm/arbitration/ directory exists in r54p0, and
              CONFIG_MALI_HAS_VIRTUALIZATION is defined nowhere in the source.
              The dangling path breaks `make clean`.
Actual change: conditionalises the reference:
                  ifneq ($(CONFIG_MALI_HAS_VIRTUALIZATION),)
                  obj-$(CONFIG_MALI_HAS_VIRTUALIZATION) += ../arbitration/
                  endif
Architecture impact:  none.
Kernel-version impact: none.
Kconfig impact:       guards on CONFIG_MALI_HAS_VIRTUALIZATION, a symbol absent
              from r54p0's own Kconfig/Mconfig — hence it can never be enabled.
r54p0 applicability:  VERIFIED APPLIES (hunk context matches; see findings.md for
              the pre-image hash nuance)
r56p0 applicability:  VERIFIED FAILS — r56p0's Kbuild has no such line at all,
              and no arbiter/ directory either.
Status:        VERIFIED (applies to r54p0); NOT TESTED (compilation / make clean)
```

## Non-Arm compatibility summary

For the four patches that carry real portability weight:

| Concern | Resolved by | Mechanism |
|---|---|---|
| `asm/arch_timer.h` missing | 0002 | omit include on non-Arm |
| `arch_timer_get_cntfrq()` undefined | 0003 | `USEC_PER_SEC` constant |
| `dmb()` undefined | 0004 | map to generic `mb()` |
| `CONFIG_OF=n` dead code / guard conflicts | 0001, 0005 | version + `CONFIG_OF` guards |

What the patches **do not** address: the driver's CPU VA width for x86 (already
handled natively), the Simulated Platform Device probe (native), the model/dummy
GPU (native), or the KCOV build-system gap (see `findings.md`).

Residual risk, UNKNOWN: after 0003, Kbase's GPU timestamp base on x86_64 is a
fixed 1 MHz constant rather than a real hardware counter. Anything comparing
timestamps for correctness or deadlines should be treated as approximate. Not
yet measured.

## Scope class of this environment — INVESTIGATION/DISCOVERY-ONLY (DECISION-1)

This whole harness — the x86_64 kernel plus `CONFIG_MALI_NO_MALI=y` plus
`MALI_PLATFORM_NAME="vexpress"` — is a **discovery** environment, not a validation
environment.

| Requirement | On program Kbase allowlist (§8.3)? |
|---|---|
| `CONFIG_MALI_MIDGARD=m` | yes (default path) |
| `CONFIG_MALI_CSF_SUPPORT=y` | yes |
| `CONFIG_MALI_EXPERT=y` | yes |
| `CONFIG_MALI_NO_MALI=y` | yes |
| `CONFIG_MALI_DEBUG=n` | yes (mandatory) |
| `MALI_PLATFORM_NAME="vexpress"` | **NO** |
| `MALI_NO_MALI_DEFAULT_GPU="tDRx"` | **NO** (only `MALI_NO_MALI` itself is listed) |

Two unavoidable options fall outside the allowlist, so no configuration built here
can be called conforming. Consequences:

- Any crash found here is a **lead**, not a finding; it must be re-confirmed on
  real hardware with a default KConfig (`../research/program-scope.md` §6).
- The x86 harness also cannot use `insmod` overrides at all, because the dynamic
  policy requires default module parameters (§8.4) — including for the GPU target.
- Only **unprivileged (EL0) syscall** exposure is in scope (§8.2); that criterion is
  applied to findings regardless of environment.

GPU target selection (DECISION-2): `tDRx`, the newest of the 18 targets defined by
r54p0. Arm's own x86 guide says `tKRx`, one generation older. Both are outside the
allowlist; the newer one is chosen because the program says to target the latest GPU.
See `kconfig-dependencies.md` and `findings.md` F-4.

## Not yet verified

- Compilation of r54p0 + all six patches on any kernel (NOT TESTED).
- `make clean` behaviour before/after patch 0006 (NOT TESTED).
- Runtime behaviour, `insmod` success, `/dev/mali0` creation (NOT TESTED).
- Timestamp accuracy of the `USEC_PER_SEC` substitution (NOT TESTED).
- Whether the `tDRx` dummy model initialises here (NOT TESTED; fall back to `tKRx`
  and record the deviation if not).
