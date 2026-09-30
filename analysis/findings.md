# Findings

Findings recorded during repository organisation and source analysis. Every entry
is labelled by evidence strength. No finding here has been tested by a build.

Severity convention used in this repository: a **build-system defect is not a
security vulnerability**, and a **virtual-device behaviour is not a
production-device vulnerability**. Those require independent evidence.

## Scope policy reference

```text
Scope reference:        research/program-scope.md  (authoritative; do not
                        duplicate policy here)
Scope assessment date:  2026-09-30
Scope status:           see authoritative policy
```

Each finding below may carry an `Assessment:` line (`IN SCOPE` /
`DISCOVERY-ONLY` / `EXCLUDED` / `UNKNOWN`). Such a line is a **point-in-time
assessment**, not a second policy source, and never overrides
`research/program-scope.md`. This file does **not** restate the program scope,
allowlist, or exclusions — read those from the policy document.

---

## F-1 — VERIFIED BUILD-SYSTEM FINDING: dangling `../arbitration/` reference

**Classification:** build-system defect. Security classification: **NOT
ESTABLISHED**. Not a vulnerability on the evidence available.

**Assessment:** EXCLUDED as a security finding. This is a build-system defect
only; per `research/program-scope.md` it has no attacker-reachable surface, and
the supplied patches that touch this path are themselves listed as out of scope.

### The problem

`drivers/gpu/arm/midgard/Kbuild:133` (r54p0, pristine):

```make
obj-$(CONFIG_MALI_MIDGARD) += mali_kbase.o
obj-$(CONFIG_MALI_HAS_VIRTUALIZATION) += ../arbitration/
obj-$(CONFIG_MALI_KUTF)    += tests/
```

Referenced path: `drivers/gpu/arm/arbitration/`

Actual path that exists: `drivers/gpu/arm/midgard/arbiter/`

### Evidence — VERIFIED

```bash
$ ls drivers/gpu/arm/arbitration
ls: cannot access 'drivers/gpu/arm/arbitration': No such file or directory

$ ls drivers/gpu/arm/
BUILD.bazel  Kbuild  Kconfig  Makefile  midgard
```

The `arbiter/` directory does exist and contains a real implementation:

```text
drivers/gpu/arm/midgard/arbiter/
├── Kbuild
├── mali_kbase_arbif.c / .h
├── mali_kbase_arbiter_defs.h
└── mali_kbase_arbiter_pm.c / .h
```

and it is wired into the build unconditionally through a *different* mechanism
(`midgard/Kbuild:183-184`):

```make
INCLUDE_SUBDIR = \
    $(src)/arbiter/Kbuild \
    ...
```

`midgard/arbiter/Kbuild` then adds the objects:

```make
mali_kbase-y += \
    arbiter/mali_kbase_arbif.o \
    arbiter/mali_kbase_arbiter_pm.o
```

So the arbiter code is built from `arbiter/`, while a **second, stale reference**
to `../arbitration/` remains on line 133.

### Second reference — VERIFIED

`drivers/gpu/arm/midgard/Makefile:190`:

```make
-include $(THIS_DIR)/../arbitration/Makefile
```

Note the leading `-` on `-include`: a missing file is silently tolerated. This
Makefile is the SCons/Android path, so it is not expected to break an in-tree
build, but it points at the same non-existent directory.

### The enabling symbol — VERIFIED

`CONFIG_MALI_HAS_VIRTUALIZATION` is **defined nowhere** in r54p0:

```bash
$ grep -RIn "MALI_HAS_VIRTUALIZATION" <r54p0 payload>
midgard/Kbuild:133:obj-$(CONFIG_MALI_HAS_VIRTUALIZATION) += ../arbitration/
```

The only occurrence is this use site — it is never `config`'d in any `Kconfig` or
`Mconfig`. It therefore cannot be enabled through normal configuration, and
expands to the empty string.

### Effect

`obj-` with an empty variable expands to nothing, so the line contributes no
object normally. The breakage arises in Kbuild's directory traversal /
cleaning logic, which is exactly what patch 0006 addresses:

```make
ifneq ($(CONFIG_MALI_HAS_VIRTUALIZATION),)
obj-$(CONFIG_MALI_HAS_VIRTUALIZATION) += ../arbitration/
endif
```

- Affects: **`make clean`** (per patch title and Arm's troubleshooting section).
- Compilation: not demonstrated to be affected; Arm's guide reports the driver
  *builds* successfully and only `make clean` fails.
- Scope: build-system behaviour only.

### Is the `arbiter/` absence intentional? — UNKNOWN

It is not established whether:
- the reference is a vendor bug (directory renamed `arbitration` → `arbiter`
  without updating `Kbuild:133`), or
- an internal vendor-only component was stripped from this public archive.

Both are consistent with the evidence. Not resolved in this phase.

### Relationship to r56p0 — VERIFIED

r56p0 contains **neither** `midgard/arbiter/` nor any
`CONFIG_MALI_HAS_VIRTUALIZATION` reference. Consistent with the same upstream
cleanup having been completed there, but that is an INFERENCE, not a documented
statement.

### Patch that addresses it

`patches/virtual-device/0006-Fix-make-clean-when-no-arbitration-code-present.patch`
— VERIFIED to apply to pristine r54p0.

### Why this is not a security finding

The consequence is a failing `make clean` in the vendor build system. It does not
affect the code compiled into the module, does not create a memory-safety issue,
and has no privilege or input-reachability dimension. Reporting it as a
vulnerability would be wrong.

---

## F-2 — HIGH RISK: `MALI_KCOV` is unreachable in an in-tree build

**Status: VERIFIED source fact; consequences INFERRED; not yet built.**

### Evidence — VERIFIED

| Check | Result |
|---|---|
| `MALI_KCOV` in `midgard/Kconfig` | **absent** |
| `MALI_KCOV` in `midgard/Mconfig` | present (line 202) |
| `MALI_KCOV` in `midgard/Kbuild` | **absent — 0 occurrences** |
| Its flags in `midgard/Makefile:283` (SCons/Android) | present |
| Its flags in `drivers/base/arm/Makefile:103` (SCons/Android) | present |
| `drivers/gpu/arm/Kconfig` sources `Mconfig`? | **no** — sources only `midgard/Kconfig` |

The flags in question:

```make
ifeq ($(CONFIG_MALI_KCOV),y)
    CFLAGS_MODULE += $(call cc-option, -fsanitize-coverage=trace-cmp)
    EXTRA_CFLAGS += -DKCOV=1
    EXTRA_CFLAGS += -DKCOV_ENABLE_COMPARISONS=1
endif
```

`MALI_KCOV` is a **compile-time instrumentation switch for Kbase objects**. It is
distinct from Linux's `CONFIG_KCOV`, which is the runtime coverage subsystem.
`MALI_KCOV` makes Kbase emit trace-cmp coverage; `CONFIG_KCOV` collects it.

Dependency (VERIFIED, `midgard/Mconfig:204`):

```text
MALI_KCOV  depends on  MALI_MIDGARD && MALI_DEBUG
```

### Consequence — INFERRED, not built

Because the in-tree Kbuild path never reads the `Makefile` that carries those
flags, and the symbol is absent from the `Kconfig` the kernel parses, an in-tree
x86_64 build of r54p0 will very likely produce **a module with no Kbase-side
coverage instrumentation**, regardless of `CONFIG_MALI_KCOV`.

This directly threatens the `kcov` profile, which is the primary coverage-guided
fuzzing kernel.

### Mitigation — PLANNED

A research-authored patch in `kernel/patches/` adding a `Kbuild` condition that
appends `-fsanitize-coverage=trace-cmp` for the coverage profile. Preferred over
editing vendor source, which is forbidden. Must be validated by build in the
build phase — until then this remains an INFERENCE.

### Same situation in r56p0 — VERIFIED

r56p0 has the identical `Kconfig`/`Kbuild` gap. Switching to r56p0 does **not**
solve it.

---

## F-3 — Hard build gates can be silently satisfied

**Status: VERIFIED source fact.**

`midgard/Kbuild:29-39` uses `ifeq ($(CONFIG_X),n)` rather than testing for
emptiness:

```make
ifeq ($(CONFIG_PM_DEVFREQ),n)
    $(error CONFIG_PM_DEVFREQ must be set in Kernel configuration)
endif
```

Consequence (INFERRED): an **unset** symbol expands to the empty string, which is
not equal to `n`, so the guard would not fire. The intended safety net may
therefore not engage for a symbol that is absent rather than explicitly disabled.

Mitigation for our own configs (PLANNED): set these symbols explicitly, and assert
their presence in the build script rather than relying on Kbuild to complain.

---

## F-4 — RESOLVED: `NO_MALI_DEFAULT_GPU` target

**Status: VERIFIED (source) / NOT_TESTED (runtime).** Superseded the earlier
"UNKNOWN / NEEDS RECONCILIATION" entry after the program's "target the latest GPU"
guidance and a full read of r54p0's GPU table (DECISION-2).

| Source | Value | Note |
|---|---|---|
| `midgard/Kconfig:72` default (r54p0) | `"tMIx"` | the **oldest** GPU; the table's fallback |
| Arm virtual-platform guide, x86 config | `"tKRx"` | valid, but the **second-newest** |
| r54p0 `all_control_reg_values[]` latest | **`"tDRx"`** | arch 14.8.5; the true latest |

Resolution: the release defines 18 GPU targets, ordered oldest→newest in
`backend/gpu/mali_kbase_model_dummy.c:161-442`. The last/highest is `tDRx`
(`GPU_ID2_MAKE(14, 8, 5, …)`). "Target the latest GPU when compiling" therefore
means `CONFIG_MALI_NO_MALI_DEFAULT_GPU="tDRx"`, not the guide's older `tKRx`. Full
evidence table and DECISION-2 record in `kconfig-dependencies.md`.

`tDRx` is supported in the virtual path (hardware feature/issue tables, product id,
product name, IPA model, and the CSF `_no_mali` arch gate all reference arch 14),
but this is a **source-level** result — no build or boot has confirmed it
(NOT_TESTED).

The value remains a module parameter (`mali_kbase_model_dummy.c:527-529`), but the
program's dynamic-config policy says default module parameters must be used and
does **not** list `no_mali_gpu` among the permitted overrides, so the GPU target is
set at compile time, not by `insmod` (DECISION-1/2; `research/program-scope.md`
§8.4).

Related minor discrepancy (still open): Arm's how-to guide shows sample DDK output
`r54p0-00eac0`, while the source identifier is `r54p0-01eac0`.

---

## F-5 — VERIFIED: patch series targets r54p0, not r56p0

**Status: VERIFIED by reproduction.** See `virtual-device.md` for the matrix.

Method: fresh extraction of each archive; `git apply --check -p1` from the `driver/`
directory; corroborated by blob-hash pre-image comparison (9/10 hashes match r54p0).

This is the reason r54p0 is the primary target and the reason the project brief's
`454 files` and `3.17.0 → 6.18.0` figures — both r56p0 values — were corrected.

---

## F-6 — CURRENT RESOURCE CONSTRAINT (build-phase blocker)

**Status: VERIFIED on this host.**

| Resource | This host | Arm's documented tested baseline |
|---|---|---|
| Architecture | x86_64 | — |
| vCPU | 4 | 4+ |
| RAM | 7.4 GB (≈3.4 GB available at measurement) | **16 GB** |
| Free disk | 3.8 GB (96% used on `/`) | **256 GB** |

Missing host tooling at time of writing (VERIFIED):
`qemu-system-x86_64`, `bison`, `libelf`. Present: `gcc` 15.3.0, `make` 4.4.1,
`flex`, `bc`, `openssl`, `cpio`, `zstd`, `socat`, `git`, `curl`, `wget`.
`/dev/kvm` **is** present, so KVM acceleration is available.

Consequences, stated without pessimism:

- Disk, not CPU, is the binding constraint. Four full kernel build trees plus four
  rootfs images would not fit.
- This is a direct argument for the repository's **one-source / many-`O=`-dirs /
  portable-artifact** design, and for deleting build trees after packaging.
- It is not evidence that the project cannot work.

---

## F-7 — Scope note: an unexpected third variant

`VX504X08X-SW-99002-r56p0-19eac0/` (release `r56p0-19eac0`, 489 files) appeared in
the working directory during this phase. **NOT ANALYSED, NOT VENDORED, NOT
TESTED.** Recorded so a later session does not mistake it for r56p0-18eac0 or
assume it was considered.

---

## F-8 — Harness contains excluded code by construction (scope hazard)

**Status: VERIFIED source fact.** Scope: see `research/program-scope.md` (§9
excludes "dummy model" code; §9 excludes bugs only reachable via debugfs or TEST
config options). This finding exists so future researchers do not confuse the
virtual harness's own scaffolding with the reportable Kbase attack surface.

The `MALI_NO_MALI` virtual harness necessarily includes code that the program
excludes. But `NO_MALI` swaps **only two objects**, so the majority of Kbase —
including the in-scope ioctl / MMU / memory paths — remains present and reachable.

### VERIFIED: the NO_MALI swap surface is minimal

`drivers/gpu/arm/midgard/csf/Kbuild:49-56`:

```make
ifeq ($(CONFIG_MALI_NO_MALI),y)
mali_kbase-y += csf/mali_kbase_csf_firmware_no_mali.o
mali_kbase-y += csf/mali_kbase_csf_fw_io_no_mali.o
else
mali_kbase-y += csf/mali_kbase_csf_firmware.o
mali_kbase-y += csf/mali_kbase_csf_fw_io.o
endif
```

Exactly **two** firmware-interface objects are replaced. Everything else is
compiled as usual, including:

| Kbase area | Under `MALI_NO_MALI=y` | Evidence |
|---|---|---|
| ioctl dispatch (`mali_kbase_io.c`) | compiled; debugfs-only ioctls `#if`'d out | `mali_kbase_io.c:102` `#if defined(CONFIG_DEBUG_FS) && !IS_ENABLED(CONFIG_MALI_NO_MALI)` |
| memory management (`mali_kbase_mem_linux.c`) | compiled; uses dummy page when no GPU | `mali_kbase_mem_linux.c:3306,3674` |
| MMU direct (`mmu/mali_kbase_mmu_hw_direct.c`) | compiled; small regions `#if`'d | `mali_kbase_mmu_hw_direct.c:229,525` |
| model layer (`mali_kbase_model_dummy.c`) | compiled **in** | `backend/gpu/Kbuild:43` `mali_kbase-$(CONFIG_MALI_NO_MALI) += …mali_kbase_model_dummy.o` |

### Operational consequence

- The reportable surface is **large**: production ioctl handling, MMU mapping, and
  memory-allocation code all run in the virtual environment.
- A finding is only out of scope if it is **specific to** the dummy-model object or
  the two `_no_mali` firmware objects. A generic ioctl/MMU/memory bug reached
  *through* the harness is still a Kbase bug, subject to the discovery-vs-
  validation rule (`research/program-scope.md` §6).
- Do **not** report the harness scaffolding itself (the dummy model) or the
  supplied virtual-device patches — both are listed exclusions.

**Assessment:** mixed. Individual findings are classified per
`research/program-scope.md`; this entry records the surface, it does not grant or
deny scope.

---

## F-9 — KCOV / debug configurations are non-conforming for validation

**Status: VERIFIED, and broadened.** Scope: `DISCOVERY-ONLY` per
`research/program-scope.md` §5–§6, and additionally per the Kbase build allowlist in
§8.3.

Two allowlists now apply, and BOTH must hold for a validation environment:

1. the **kernel** allowlist (`research/program-scope.md` §5): only `CONFIG_COMPAT`,
   the ARM64 page-size pair, `CONFIG_KASAN*` (except `*_TEST`), `CONFIG_UBSAN*`
   (except `CONFIG_TEST_UBSAN`);
2. the **Kbase** allowlist (`research/program-scope.md` §8.3): default KConfig plus
   `CONFIG_MALI_DEBUG=n` (mandatory) and at most `MALI_CSF_SUPPORT`, `MALI_EXPERT`,
   `LARGE_PAGE_SUPPORT`, `MALI_TRACE_POWER_GPU_WORK_PERIOD`, `MALI_NO_MALI`.

Measured against both:

| Profile | Non-allowlisted kernel options | Non-default/other Kbase options | Use | Validation-eligible? |
|---|---|---|---|---|
| `baseline` | none intended | `MALI_NO_MALI=y` (allowed); `MALI_PLATFORM_NAME="vexpress"` + `MALI_NO_MALI_DEFAULT_GPU` (**not** on §8.3 list) | control / reproduction | **no** in the x86 harness — it is the x86 virtual env, hence investigation-only (DECISION-1). It defines the intended conforming config shape for real HW. |
| `kasan` | none — all changes are `CONFIG_KASAN*` | previously `MALI_DEBUG=y` (**now removed**) | discovery **and** validation | **potentially yes** once `MALI_DEBUG=y` is dropped and the savedefconfig diff is clean |
| `kcov` | `CONFIG_KCOV`, `CONFIG_KCOV_INSTRUMENT_ALL` | `MALI_NO_MALI` path; `vexpress`; GPU target | discovery / coverage triage | **no** |
| `debug` | `CONFIG_DEBUG_KERNEL`, `CONFIG_DEBUG_INFO` | `MALI_DEBUG=y` (mandatory-`n` violation) | crash / root-cause | **no** |

Key correction: the program **mandates `CONFIG_MALI_DEBUG=n`** and does not list
`MALI_DEBUG` among the changeable options. Any `MALI_DEBUG=y` profile is therefore
non-conforming. The earlier `kasan.config` claim that `MALI_DEBUG=y` is needed "for
ASAN interaction" was **INFERRED and is now withdrawn**; `kasan.config` sets
`MALI_DEBUG=n`.

DECISION-1 consequence: because the x86_64 NO_MALI harness needs
`MALI_PLATFORM_NAME="vexpress"` (and a GPU target), which are outside the §8.3
allowlist, **the entire x86 virtual environment is INVESTIGATION/DISCOVERY-ONLY**.
No profile built in it is a validation environment, including `baseline`.

Consequences, recorded explicitly:

```text
Discovery use:   intentional and expected for the whole x86 virtual environment
Validation use:  requires BOTH allowlists (kernel §5 + Kbase §8.3) on real HW;
                 findings from the virtual harness are re-confirmed before counting
Eligibility:     a crash under an instrumented kernel or a non-conforming Kbase
                 config does NOT by itself make a finding eligible
```

This compounds F-2: the Kbase-side coverage gap is a *build* problem, and even once
a research patch closes it, the resulting KCOV kernel remains a discovery-only,
non-conforming environment.

**Assessment:** DISCOVERY-ONLY for the x86 virtual harness as a whole (DECISION-1);
`kasan` is the only profile that can *theoretically* approach a conforming config,
and only on real hardware and only after `MALI_DEBUG=n` + a clean savedefconfig diff.

---

## F-10 — `build.sh` could not have built Kbase (found by static review)

**Status: FIXED. Not reproduced at runtime** — no kernel has been compiled on any
host, so this is a defect found by reading the script and by testing its control
flow against a stubbed tree, not an observed build failure. Category:
`build-system issue`.

The first `build.sh` (committed as `a7e0d72`) had four independent defects. Any one
of them would have produced a wrong or missing build, and three of them would have
failed *silently*:

| # | Defect | Consequence |
|---|---|---|
| 1 | Staging used `cp -a "$KBASE_TREE/." "$KERNEL_SRC/drivers/gpu/arm/"` | The payload root contains `drivers/`, `include/`, `Documentation/`, so this created `drivers/gpu/arm/drivers/gpu/arm/midgard/…`. Kbase would not have been built at all. |
| 2 | `.config` was seeded at step 1, but Kbase's `Kconfig` was only staged at step 3 | The `MALI_*` symbols did not exist when `scripts/config` set them. |
| 3 | Those failures were swallowed by `2>/dev/null \|\| true` | The build continued with a `.config` containing **no MALI options** and still exited 0. Worst case: a "successful" kernel with no Kbase. |
| 4 | `scripts/config --set-str` was used for every `CONFIG_*` line | `--set-str` quotes the value, so booleans became `CONFIG_KASAN="y"` — invalid `.config` syntax. `--set-val` is correct for bool/tristate. |

Plus two lesser ones: the staged copy was never removed from the pinned source
tree, and there was no verification that the config merge worked.

Fixes applied:

- stage the **payload root into the kernel tree root** (defect 1);
- stage *before* seeding the config (defect 2);
- replace the `scripts/config` loop with `append fragment` + `make olddefconfig`,
  then **verify every fragment symbol took effect**, and exit non-zero listing the
  ones that did not (defect 3, and the new safety net);
- verification covers three outcomes — all set / symbol absent / value clobbered —
  and all three were exercised against a stubbed tree.

Verification of the fix is a control-flow test only: `build.sh` was run against a
fake kernel tree whose `make` is a shell stub. It confirms the staging, wiring,
merge and refusal logic; it proves nothing about whether Kbase compiles.

## F-11 — In-tree integration requirements, and one hard gate my analysis missed

**Status: VERIFIED by source inspection. NOT_TESTED at build time.** Category:
`build-system issue` + correction to F-3.

Reading `drivers/gpu/arm/{Makefile,Kbuild}` and `midgard/{Makefile,Kbuild}` in the
pristine r54p0 extract turned up two things the analysis had wrong or absent.

**(a) A hard gate was missing.** F-3 listed three unconditional `$(error)` gates.
There are **five**:

| Symbol | midgard/Kbuild | Was it in the fragments? |
|---|---|---|
| `CONFIG_DMA_SHARED_BUFFER` | 29-30 | yes |
| `CONFIG_PM_DEVFREQ` | 33-34 | yes |
| `CONFIG_DEVFREQ_THERMAL` | 37-38 | yes |
| **`CONFIG_DEVFREQ_GOV_SIMPLE_ONDEMAND`** | **41-42** | **NO — added to all four fragments** |
| `CONFIG_FW_LOADER` | 45-46 | no (satisfied — `MALI_MIDGARD` selects it) |

Two further gates are conditional and only fire if `MALI_PRFCNT_SET_SELECT_VIA_DEBUG_FS`
(Kbuild:49-51, needs `CONFIG_DEBUG_FS`) or `MALI_FENCE_DEBUG` (55-57, needs
`CONFIG_SYNC_FILE`) are enabled. No profile enables either.

**(b) `Makefile` shadows `Kbuild`.** Kbase ships *both* files in every directory it
owns, and kbuild prefers `Makefile`. The `Makefile`s are the Android/out-of-tree
ones — `midgard/Makefile` starts with `KERNEL_SRC ?= /lib/modules/$(uname -r)/build`
and `KDIR ?= $(KERNEL_SRC)`. So a plain copy never reaches
`obj-$(CONFIG_MALI_MIDGARD) += midgard/` at all. `build.sh` now sets the Android
`Makefile` aside and installs `Kbuild` in its place, inside the disposable fetched
tree only.

Minimal integration therefore requires: payload root merged into the kernel tree
root; `drivers/gpu/arm` + `drivers/gpu/arm/midgard` kbuild-ified;
`source "drivers/gpu/arm/Kconfig"` added to `drivers/gpu/Kconfig`; and
`obj-$(CONFIG_MALI_MIDGARD) += arm/` added to `drivers/gpu/Makefile`.

Deliberately **not** wired: `drivers/base/arm/` and
`drivers/hwtracing/coresight/mali/`. They are gated on
`CONFIG_MALI_MEMORY_GROUP_MANAGER`, `CONFIG_MALI_PROTECTED_MEMORY_ALLOCATOR`,
`CONFIG_DMA_SHARED_BUFFER_TEST_EXPORTER` and Arm64 coresight — none of which are on
the program allowlist (§8.3) or enabled by any profile. Wiring them would add
nothing and widen the config delta.

**A latent vendor bug, recorded but not worked around:**
`drivers/gpu/arm/Kbuild:21` and `drivers/base/arm/Kbuild:21` contain

```make
ifeq ($(MALI_CSF_SUPPORT),n)
    $(error [GPUBUILD-2005] Only CSF builds are supported on this branch)
endif
```

`MALI_CSF_SUPPORT` (without the `CONFIG_` prefix) is **never assigned** anywhere in
the tree — only `CONFIG_MALI_CSF_SUPPORT` is. The variable expands to empty, so
`ifeq (,n)` is false and the gate never fires. The build will not spuriously fail,
but this "only CSF builds" guard is currently dead code. It does not change our
profile choice: `CONFIG_MALI_CSF_SUPPORT=y` is set anyway, per the FAQ and Arm's
own x86 config. Recorded so nobody later "fixes" it by passing `MALI_CSF_SUPPORT=n`.

## F-12 — `.devcontainer/` blocked Codespace creation; removed

**Status: FIXED by removal.** Category: `build-host / CI configuration`.

A `.devcontainer/devcontainer.json` (Ubuntu 24.04 image, with
`hostRequirements` of 4 cpu / 16 gb / 64 gb) was committed in `b348b58`. Attempting
to create a Codespace from this repository failed:

```text
A codespace cannot be created because no machine types are available.
You may need to select a different branch, modify your container
configuration, or adjust your organization's policy settings.
```

This is a **Codespace provisioning failure**, not a defect in any kernel script.
The declared `hostRequirements` combination is not offered by this account, and
GitHub fails closed: rather than falling back to a smaller machine, it refuses to
create the codespace at all. A devcontainer cannot fix a machine-availability or
org-policy problem — declaring the requirements only converted "too small machine"
into "no codespace at all".

Resolved by **deleting `.devcontainer/`** (commit after `b348b58`). Codespaces
works without one: create the codespace from the default Codespaces image and pick
**4 cores / 16 GB / 64 GB** manually in the UI.

Consequences, and why this is not a regression:

- Nothing in the repository needed the devcontainer. It was convenience only.
- The toolchain install it performed in `onCreateCommand` is now done by
  `kernel/scripts/codespace-setup.sh`, which is the documented first command on a
  fresh host and covers strictly more (toolchain **plus** machine-spec check, git
  identity, GitHub access, `gh`, preflight verdict).
- The machine-spec check that `hostRequirements` used to automate is now performed
  by `codespace-setup.sh`, which fails loudly *before* a build instead of
  preventing the codespace from existing.
- Do not re-add `hostRequirements`. If automatic machine selection is wanted
  again, it must be validated against the account's actual available machine types
  first — an unmatchable requirement blocks the entire build host.

## Consolidated unknowns

1. Whether r54p0 + all six patches compiles on any x86_64 Linux kernel.
2. Which exact kernel version to select. ARM GUIDANCE narrows the choice
   (latest ACK or latest Linux stable/LTS — see `research/program-scope.md` §4),
   but the specific version is still a build-phase verification item.
3. The exact minimal upstream kernel configuration.
4. ~~Why `NO_MALI_DEFAULT_GPU` differs between Arm's guide (`tKRx`) and the source
   default (`tMIx`).~~ **Resolved by F-4 / DECISION-2**: neither is the latest;
   r54p0's latest target is `tDRx`. Why Arm documented `tKRx` is still UNKNOWN.
5. Whether the `MALI_KCOV` gap (F-2) can be closed without touching vendor source.
6. Whether the virtual configuration reaches the CSF code paths a fuzzer needs.
7. Whether any virtual-only behaviour is relevant to a real production Kbase
   target — and, separately, which findings survive the discovery-vs-validation
   rule on conforming hardware (F-9).
8. Whether `make clean` actually fails pre-patch 0006 (the patch title asserts it;
   not reproduced here).
9. Whether targeting `tDRx` (vs `tKRx`) changes the NO_MALI dummy model's
   behaviour enough to matter for F-8's reportable surface (NOT_TESTED).
10. Whether a `kasan` build can be made fully conforming (all deltas within both
    the §5 kernel and §8.3 Kbase allowlists) so it can serve as the validation
    environment for discoveries. Note the x86 harness itself is investigation-only
    (DECISION-1), so this can only be settled on real hardware.
11. The complete list of permitted `insmod` module parameters — the supplied text
    is truncated (UNKNOWN; `research/program-scope.md` §8.4).
12. Whether `tDRx` actually initialises in the `MALI_NO_MALI` path on x86_64
    (source-supported per F-4, but NOT_TESTED).
13. Whether the minimal in-tree integration in F-11 is *sufficient*. It is derived
    from the vendor's own `Kbuild`/`Makefile`/`Kconfig` files by inspection, but no
    build has confirmed it. Expect the first real build to surface further
    integration work — `build.sh` step 5/8 is designed to fail loudly and
    specifically rather than produce a kernel without Kbase.
14. Whether the newest LTS kernel pairs cleanly with the compiler on the build
    host (gcc 15.x against a recent kernel is a plausible `-Werror` / API-churn
    risk; per BUILD-PLAN.md, record the first error rather than silently
    downgrading).
15. Which Codespace machine types this account actually offers. F-12 shows the
    consequence of assuming: an unmatchable `hostRequirements` made the codespace
    uncreatable. Machine size must be chosen in the UI and confirmed by
    `codespace-setup.sh` before any build.
