# Phase 2 build plan — DEFERRED, NOT YET RUN

```text
STATUS:  PLANNED — nothing in this document has been executed.
STATE:   NOT_STARTED   (research/state.md)
```

No kernel has been selected, downloaded, compiled, booted, or packaged. This file
records **how** the build will be performed on the build host, so the next session
starts from a clean, reproducible position rather than improvising.

**The machine that organised this repository is not the build host.** Its disk
(3.8 GB free), available RAM (1.6 GB), and missing `bison` make it unsuitable.
See `BUILD-HOST.md`.

## Order of operations (do not reorder)

```text
0. clone this repo on the build host
1. kernel/scripts/preflight.sh          # verify the host; exits 1 if not ready
2. fill kernel/sources/kernel.pin       # pin an exact version + checksum
3. kernel/scripts/fetch-kernel.sh       # download + verify + extract
4. kernel/scripts/apply-patches.sh      # pristine r54p0 + six patches
5. kernel/scripts/build.sh --profile baseline     # FIRST, always
6.   ... boot + validate + package baseline ...
7. kernel/scripts/build.sh --profile kasan
8. kernel/scripts/build.sh --profile kcov
9. kernel/scripts/build.sh --profile debug
10. rootfs + QEMU + artifact packaging + clean-location test
```

**Baseline first, alone.** It answers the one question everything else depends on:
does r54p0 + the six patches + the chosen kernel compile at all? Do not build four
profiles in parallel on a 4-vCPU / 8 GB host, and do not start the instrumented
variants until baseline works.

## Step 2 — choosing the kernel version (still unresolved)

Arm guidance (VERIFIED, `../research/program-scope.md` §4): for a new virtual test
environment, use the **latest Android Common Kernel or the latest Linux Kernel
stable/longterm release**.

So the policy is *newest suitable LTS*, not a guessed number. Concretely:

1. On the build host, query authoritative release metadata and checksums:
   ```bash
   curl -s https://www.kernel.org/releases.json
   curl -s https://cdn.kernel.org/pub/linux/kernel/v6.x/sha256sums.asc
   ```
2. Select the newest **longterm (LTS)** release.
3. Write `version=`, `url=`, `sha256=` into `kernel/sources/kernel.pin`.
4. Record the decision in `../analysis/kernel-compatibility.md` using the required
   fields:

   ```text
   Candidate:
   Source:            (authoritative URL consulted)
   Reason:
   r54p0 compatibility evidence:
   Status:
   ```

Constraints on the choice:

- Do **not** assume 4.19, 6.12, or 6.18 is correct merely because it is convenient.
- r54p0's highest observed `KERNEL_VERSION` gate is **6.13.0**, but a gate is
  **not** a proven ceiling (`../analysis/kernel-compatibility.md`). A kernel newer
  than 6.13.0 may be fine; only a successful build/boot/load proves it.
- Do not silently downgrade. If the newest LTS fails, record the exact first
  meaningful error (see *Failure handling*), diagnose the category, and only then
  try the next justified candidate.
- Do not call a kernel "supported" until build + boot + Kbase-load all pass.

## Step 5 — baseline configuration

**Do not hand-write a tiny `.config`.** The baseline is:

```text
kernel defconfig (x86_64)
        +
minimum required Kbase / virtual-device dependencies
```

The minimum set is derived from r54p0 source, not guessed. Already established
(`../analysis/kconfig-dependencies.md`):

| Requirement | Source of truth |
|---|---|
| `MALI_MIDGARD` (`=m`, tristate) | `midgard/Kconfig`; selects DMA_SHARED_BUFFER, PM_DEVFREQ, DEVFREQ_THERMAL, FW_LOADER |
| `MALI_CSF_SUPPORT=y` | r54p0 default is `n`, so it must be set explicitly |
| `MALI_EXPERT=y` | r54p0 default is **`n`** (`Kconfig:156`), so this must be set explicitly; it gates `MALI_NO_MALI`, `MALI_DEBUG`, `LARGE_PAGE_SUPPORT` |
| `MALI_DEBUG=n` | **mandatory** per program policy (`../research/program-scope.md` §8.3) and the r54p0 default (`Kconfig:197`) |
| `MALI_NO_MALI=y` | no real GPU; requires `MALI_EXPERT` |
| `MALI_NO_MALI_DEFAULT_GPU="tDRx"` | latest GPU target defined by r54p0 (DECISION-2); Arm's guide uses the older `tKRx` |
| `MALI_PLATFORM_NAME="vexpress"` | selects the Simulated Platform Device; **not** on the §8.3 allowlist |
| `DMA_SHARED_BUFFER`, `PM_DEVFREQ`, `DEVFREQ_THERMAL` | `Kbuild:29-39` raises `$(error …)`; set explicitly because the `=n` test misses unset symbols (F-3) |
| virtio / serial / initramfs | needed for boot + control channel |

Two of the rows above (`MALI_NO_MALI_DEFAULT_GPU`, `MALI_PLATFORM_NAME`) are outside
the program's Kbase build allowlist. That is precisely why the whole x86 virtual
environment is INVESTIGATION/DISCOVERY-ONLY (DECISION-1, §8.5): it is a
discovery harness, not a validation environment.

`kernel/configs/baseline.config` is the **starting fragment**, not a finished
config. `build.sh` seeds `build/<profile>/.config` from the kernel default and
merges the fragment.

## Step 5b — config-delta validation (mandatory before calling anything conforming)

For each profile:

1. Generate the effective config.
2. `make savedefconfig` to get a minimal representation.
3. Diff it against the approved baseline.
4. Classify **every** delta using exactly these classes:

   ```text
   NO-OP                    (already the default; setting it changed nothing)
   ALLOWLISTED              (per Arm allowlist: COMPAT / ARM64 page size /
                             KASAN* / UBSAN*)
   KCONFIG-AUTO-DEPENDENCY  (pulled in by a select; not a user policy change)
   REQUIRED                 (genuinely needed, e.g. a Kbase hard gate)
   NON-CONFORMING           (outside the allowlist)
   UNKNOWN                  (not yet understood — never silently accept)
   ```

A profile is **not** called Arm-conforming until every user-visible delta is
classified and no unexplained `NON-CONFORMING` remains.

Scope consequences already established (`../research/program-scope.md` §5–§6):

| Profile | Likely status |
|---|---|
| `baseline` | conforming if all deltas are `NO-OP` / `REQUIRED` |
| `kasan` | potentially conforming — `CONFIG_KASAN*` is allowlisted |
| `kcov` | `CONFIG_KCOV*` is **not** allowlisted → **DISCOVERY-ONLY** |
| `debug` | `DEBUG_KERNEL` / `DEBUG_INFO` not allowlisted → **DISCOVERY-ONLY** |

## Failure handling

When a build fails, record before changing anything:

```text
kernel version · Kbase release · patch state · config
exact command · compiler version
first meaningful error · dependency involved
```

Then classify the cause as one of: `Kbase/kernel API mismatch`,
`missing Kconfig dependency`, `architecture issue`, `compiler issue`,
`patch mismatch`, `vendor source issue`, `resource exhaustion`,
`build-system issue`, `configuration-policy issue`.

Failed experiments are recorded, never hidden (see `../research/methodology.md`).

## Known risks to expect

| Risk | Reference | Note |
|---|---|---|
| Kbase-side coverage instrumentation absent in an in-tree build | `MALI_KCOV` in `Mconfig` only (F-2) | needs a research patch in `kernel/patches/`; until then `kcov` yields an uninstrumented module |
| Any Kbase coverage instrumentation also forces `MALI_DEBUG=y` | `Mconfig:204` vs mandatory `MALI_DEBUG=n` (§8.3) | closing F-2 can only ever produce a non-conforming `kcov` profile — by policy, not just practice |
| New compiler vs old kernel | gcc 15.x is very new | if the pinned kernel predates it, expect `-Werror` / API churn; record it as a `compiler issue` |
| Dangling `../arbitration/` reference | F-1 | patch 0006 addresses it; confirm `make clean` behaviour |
| `tDRx` is NEWER than what Arm's guide documents (`tKRx`) | F-4 / DECISION-2 | may hit an incompletely-exercised dummy-model path; if `tDRx` fails to initialise, fall back to `tKRx` and record the deviation |
| The x86 harness is outside the §8.3 allowlist | DECISION-1 / §8.5 | `vexpress` + GPU target are unavoidable here, so **no** build in this environment can be a validation build; do not spend the build budget trying to make one |

## State discipline

Advance `../research/state.md` only after real verification:

```text
KERNEL_COMPATIBILITY_IDENTIFIED → BASELINE_BUILT → … → QEMU_BOOT_VERIFIED
→ KBASE_LOAD_VERIFIED → PORTABLE_ARTIFACT_VERIFIED
```

A `make` that returned once is not proof; module install and required
post-processing must also pass. Nothing advances until then.