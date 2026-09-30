# Kernel — PLANNED, nothing built

**No Linux kernel has been selected, downloaded, extracted, configured, or built.**
The build is **deferred to a separate build host** (see `BUILD-HOST.md`); this
directory holds the reproducible *machinery* and the build *plan*, not build
products.

## Status

```text
Kernel version selected:      UNKNOWN (pin file present, set to UNSET)
Kernel source in repo:        none (fetched on the build host, git-ignored)
Build directory:              none
.config in repo:              none (configs/ holds provisional fragments)
Build log:                    none
Any of the above reproduced:  NOT TESTED
```

## Contents

| Path | Purpose | Status |
|---|---|---|
| `BUILD-HOST.md` | what the build machine needs; why this repo's host isn't one | VERIFIED (measurements) |
| `BUILD-PLAN.md` | the deferred phase-2 build plan, step by step | PLANNED |
| `configs/` | four provisional kernel config fragments | PLANNED |
| `scripts/` | preflight / fetch-kernel / apply-patches / build (see `scripts/README.md`) | written, not executed |
| `sources/kernel.pin` | the single place a kernel version + checksum is named | UNSET |
| `patches/` | research-authored patches (not vendor patches) | empty (one known need, see `patches/README.md`) |
| `README.md` | this file | VERIFIED (as a description) |

Vendor-supplied patches are **not** stored here — they live in
`../patches/virtual-device/` because they are third-party contributions to Arm's
source, not our own research patches. Keep that separation.

## The four profiles

`build-once / reuse-many`: one kernel source tree, four configurations, four
output directories, four independently packagable images.

| Profile | Config | Kernel side | Kbase side | Purpose | Scope |
|---|---|---|---|---|---|
| `baseline` | `configs/baseline.config` | default kernel config | `MALI_NO_MALI`, GPU `tDRx` | control / reproduction / perf reference | **INVESTIGATION-ONLY** in x86; defines the intended conforming shape for real HW |
| `kasan` | `configs/kasan.config` | `CONFIG_KASAN*` | `MALI_DEBUG=n` | memory-safety discovery **and validation** | potentially conforming (on real HW) |
| `kcov` | `configs/kcov.config` | `CONFIG_KCOV*` | unresolved (F-2) | coverage-guided discovery (primary for triage) | **DISCOVERY-ONLY** |
| `debug` | `configs/debug.config` | `DEBUG_KERNEL`/`DEBUG_INFO` | `MALI_DEBUG=y` | crash / root-cause analysis | **DISCOVERY-ONLY** |

Scope classes are from `../research/program-scope.md` (authoritative; not
restated here). The combined `kasan+kcov` profile is **deliberately excluded** —
KASAN and KCOV interact poorly, so they stay separable.

Two constraints now bound every profile:

- **`CONFIG_MALI_DEBUG=n` is mandatory** (§8.3) and `MALI_DEBUG` is *not* a
  changeable option. `debug` deliberately violates this; `kasan` no longer sets it.
- **The whole x86 `MALI_NO_MALI` harness is INVESTIGATION/DISCOVERY-ONLY**
  (DECISION-1, §8.5), because it needs `MALI_PLATFORM_NAME="vexpress"` and a GPU
  target, neither of which is on the §8.3 allowlist. No build in it is a validation
  environment.

### The `kcov` profile blocker

The `kcov` profile is primary, and it is **not currently satisfiable** from vendor
source alone. `MALI_KCOV` does not exist in `midgard/Kconfig`, and the flags it
controls live only in the SCons/Android `Makefile` that an in-tree build never
reads. An in-tree build will very likely produce a module with no Kbase-side
coverage instrumentation. See `../analysis/findings.md` **F-2**.

Resolution is a research patch in `patches/`, written and validated during the
build phase. Until then this profile is PLANNED and INFERRED, not VERIFIED.

## About `configs/*.config`

These are **provisional fragments, not valid `.config` files.** They are not the
output of `make defconfig` or `make savedefconfig` from any kernel, and they have
never been fed to a build. Two distinct kinds of content appear in them, and the
header of each file says which is which:

1. **Kbase `CONFIG_MALI_*` options** — reproduced verbatim from Arm's supplied
   `arm_gpu_virtual_platform_how_to_guide.pdf`. Source-verified in
   `../analysis/kconfig-dependencies.md`.
2. **Upstream Linux `CONFIG_*` options** — named from general mainline knowledge
   only. They are **NOT verified against any kernel**, because no kernel has been
   chosen. Verify each against the selected kernel before relying on it.

Each fragment also carries the required metadata header: `Profile`, `Kbase`,
`Kernel`, `Patch set`, `Scope class`, `Generated from`, `Validation status`,
`Config hash`.

The files deliberately omit `CONFIG_MALI_KCOV` and state why, rather than writing a
symbol that would be silently ignored.

## Kernel pinning — `sources/kernel.pin`

The kernel is pinned in exactly one place: `sources/kernel.pin` (`version`, `url`,
`sha256`). `scripts/fetch-kernel.sh` refuses to download without a checksum, uses
no floating "latest", and treats a checksum mismatch as fatal. The version itself
is still **UNSET** — it is chosen on the build host per Arm guidance (latest
suitable stable/LTS) and recorded in `../analysis/kernel-compatibility.md` once
decided. Do not hard-code a guess here.

## Reproducibility rules for the build phase — PLANNED

1. Pin the kernel by version **and** SHA-256 of the tarball (`sources/kernel.pin`).
2. Record the exact baseline `defconfig`; never hand-edit it silently.
3. Apply the six vendor patches from `../patches/virtual-device/` plus any
   research patches in `patches/`; record the patch-series hash.
4. Save the generated `.config` per profile and the full build log.
5. Run the mandatory `savedefconfig` diff and classify every delta
   (`NO-OP` / `ALLOWLISTED` / `KCONFIG-AUTO-DEPENDENCY` / `REQUIRED` /
   `NON-CONFORMING` / `UNKNOWN`) — see `BUILD-PLAN.md`.
6. Package each image, record its SHA-256, then delete the build tree — the build
   host is disk-constrained (`BUILD-HOST.md`; `../analysis/findings.md` F-6).

See `BUILD-PLAN.md` for the full ordered procedure and `scripts/README.md` for the
tooling.