# lab0xy0

A **build-once, reuse-many-times portable fuzzing laboratory** for the Arm Mali
GPU Kernel Driver (**Kbase**).

The primary deliverable is **validated, reusable environments** — not merely
documentation. The documentation exists to make those environments
**reproducible, auditable, and portable**.

## The goal

Build the required Linux kernel variants, the Kbase driver environment, a minimal
root filesystem, and the QEMU environment **once**; validate them; package them
as reusable portable artifacts; and hand them to fuzzers later **without
rebuilding the kernel or recreating the VM** for every campaign.

```text
Vendor source (r54p0 Kbase)
        ↓
Virtual-device patch set (6 Arm patches)
        ↓
Linux kernel profiles (baseline · kcov · kasan · debug)
        ↓
Kbase module
        ↓
Minimal rootfs
        ↓
QEMU/KVM environment
        ↓
Validated VM  →  portable artifact bundle
        ↓
   ┌──────────┴──────────┐
   ▼                     ▼
fuzzer A              fuzzer B        (same built target)
```

## Build-time is separate from fuzzing-time

This separation is the whole design:

```text
BUILD-TIME    compile once · validate · package · record checksums
FUZZING-TIME  unpack · boot · fuzz · repeat        (never rebuilds)
```

A fuzzing campaign must not trigger a Linux, Kbase, rootfs, or QEMU rebuild. If it
does, the artifact model in `artifacts/` has been bypassed.

## Current phase

This repository is in the **organisation + source-analysis + scope-evidence**
phase. **Nothing has been built, booted, loaded, or fuzzed.** No kernel version is
chosen, no `.config` is generated, and no artifact exists. Current state:
`NOT_STARTED` (`research/state.md`).

**The build is deliberately deferred to a separate build host.** This repository was
organised on a machine with ~3.8 GB free disk, ~1.6 GB available RAM, and no `bison`,
which is not a viable kernel build environment. What lives here instead is the
reproducible *machinery* to run the build elsewhere — a pinned fetcher, a
patch-preparation script, a shared `build.sh` with config verification, a build-host
preflight, and a Codespaces setup script. GitHub Codespaces can serve as that host;
see `kernel/BUILD-HOST.md` and `kernel/BUILD-PLAN.md`. There is deliberately no
`.devcontainer/`, so create the codespace from the default image and pick
**4 cores / 16 GB / 64 GB** yourself.

Quick start on the build host:

```bash
./kernel/scripts/codespace-setup.sh --yes  # machine spec, deps, git identity,
                                           # GitHub access, gh; then preflight.sh
./kernel/scripts/resolve-kernel-pin.sh     # pick latest LTS from kernel.org, pin it
#   commit the pin, so the kernel choice is reproducible
./kernel/scripts/fetch-kernel.sh
./kernel/scripts/apply-patches.sh
./kernel/scripts/build.sh --profile baseline
```

`build.sh` refuses to compile unless every `CONFIG_*` in the profile fragment
actually took effect in the merged `.config` — a kernel that quietly lacks Kbase is
worse than no kernel. Nothing here has been compiled yet: `research/state.md` is
`NOT_STARTED`.

What *is* established (see `analysis/` and `research/`):

- r54p0-01eac0 inventoried and verified (441 files, GPL-2.0); the six supplied
  virtual-device patches VERIFIED to apply to it (matrix in
  `analysis/virtual-device.md`).
- Arm program scope, configuration allowlist, and discovery-vs-validation rule
  captured in `research/program-scope.md`.
- Kernel-compatibility analysis and Arm's "latest stable/LTS" guidance recorded
  (`analysis/kernel-compatibility.md`); the exact kernel remains a build-phase
  decision.
- A verified build-system finding (r54p0 arbitration dangling reference) and two
  scope findings (F-8 harness surface, F-9 discovery-only configs) in
  `analysis/findings.md`.

## Layout

| Path | Contents |
|---|---|
| `vendor/arm/` | primary r54p0 archive, checksums, provenance |
| `patches/virtual-device/` | the six supplied Arm patches (byte-preserved) |
| `analysis/` | source inventory, version, kernel-compat, Kconfig deps, findings |
| `research/` | program scope, methodology, test matrix, state, Arm documents |
| `kernel/` | build plan, build-host requirements, config fragments, pin file, build scripts |
| `qemu/` | QEMU environment design (scripts + minimal rootfs) |
| `syzkaller/` | planned fuzzer integration (independent of the artifact) |
| `artifacts/` | portable artifact model and validation states |
| `tools/scripts/` | shared integrity / config-delta helpers |

## Evidence discipline

Every technical statement is labelled `VERIFIED`, `INFERRED`, `UNKNOWN`,
`NOT_TESTED`, `FAILED`, `PLANNED`, or `DISCOVERY-ONLY`. Source-level compatibility
is not proven build support; a version gate is not a support claim; a
virtual-device result is not a production-device result; a build-system defect is
not a security vulnerability; and an instrumented-harness crash is not an eligible
finding. See `research/methodology.md`.

## Scope

This project targets **Kbase only** (Intigriti Tier 3, $500–$10,000). The CSF
firmware (`CSFFW`, Tier 2) is not a target here because no firmware blob is
present. The authoritative, date-stamped program scope — including the kernel
configuration allowlist, the 64-bit requirement, and the excluded surfaces — is
`research/program-scope.md`; other documents reference it rather than restate it.

## Licence and vendor material

This project's own documentation and tooling are GPL-2.0 (`LICENSE`), matching the
GPL-2.0 Kbase source. Arm's archives, PDFs, and supplied patches are Arm's
copyright, preserved byte-for-byte, held for research/reference only, and not
redistributed outside this repository.