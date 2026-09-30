# kernel/ scripts

Build machinery for the portable lab. These scripts run on the **build host**
(not the machine that organised the repo).

## Execution status — read this before trusting anything

| Script | Syntax-checked here | Fully executed here |
|---|---|---|
| `preflight.sh` | yes | yes, read-only (correctly reported `NOT READY`) |
| `bootstrap.sh` | yes | yes, `--check` mode only (read-only) |
| `codespace-setup.sh` | yes | yes, all modes, against an **isolated repo copy with a fake `HOME`** and stubbed `apt-get`/`sudo`, so the git-identity / SSH / gh logic was exercised without installing anything or touching this host's keys |
| `resolve-kernel-pin.sh` | yes | **no** — needs network; the pin is still `UNSET` |
| `fetch-kernel.sh` | yes | **no** — refuses while the pin is `UNSET`, before any network call |
| `apply-patches.sh` | yes | **no** — patches were applied during analysis, but not via this script |
| `build.sh` | yes | **control flow only**, against a stubbed kernel tree — never a real kernel |

`build.sh`'s verification logic (step 5/8) was exercised for all three of its
outcomes — all symbols set, a symbol absent from the Kconfig, and a value clobbered
after the merge — and correctly refused to build in the latter two. That is *not*
the same as having compiled Kbase; no real kernel has been built anywhere.

## Scripts (run in this order)

| # | Script | What it does | Network? |
|---|---|---|---|
| 0a | `codespace-setup.sh [--check] [--yes] [--https]` | **Start here on a fresh clone/Codespace.** Checks the machine spec against `BUILD-HOST.md`, installs the toolchain via `bootstrap.sh`, sets a git identity, arranges GitHub access (SSH key or HTTPS), installs `gh`, then runs `preflight.sh`. `--check` reports only. | apt |
| 0b | `bootstrap.sh [--check] [--yes]` | installs the build dependencies (`../BUILD-HOST.md` package list), then runs `preflight.sh`. `codespace-setup.sh` calls this, so invoke it directly only if you want just the packages. | apt |
| 0c | `resolve-kernel-pin.sh [--dry-run] [--force]` | picks the newest kernel.org release marked `longterm` (**that set is the LTS series**), takes its SHA-256 from kernel.org's own `sha256sums.asc`, and writes `kernel/sources/kernel.pin`. Implements Arm's "latest ACK or latest stable/longterm" guidance literally. | yes |
| 1 | `preflight.sh` | read-only host check (arch, disk, RAM, tools, headers, checksums, pin). Exits non-zero if the host cannot build. | no |
| 2 | `fetch-kernel.sh` | reads `kernel.pin`, downloads the exact tarball, **verifies SHA-256 (fatal on mismatch)**, extracts to `kernel/sources/linux/<version>/`. No floating "latest". | yes |
| 3 | `apply-patches.sh` | extracts pristine r54p0 to `work/kbase-pristine/` (never patched in place), copies to `work/kbase-patched/`, applies the six Arm patches in order with `patch -p1`, writes the patch-series hash. | no |
| 4 | `build.sh --profile <p>` | stages Kbase into the kernel tree, kbuild-ifies it, wires `drivers/gpu`, seeds and **verifies** `.config`, compiles the kernel, builds the module, emits metadata. | no |

There is deliberately **one** `build.sh --profile …`, not four
`build-<profile>.sh` scripts.

## What `codespace-setup.sh` exists to solve

A fresh Codespace fails in ways that have nothing to do with kernel building, and
each failure lands at a confusing moment:

| Problem | Consequence if unhandled |
|---|---|
| 2-core/8 GB machine | `preflight.sh` fails on disk/RAM only after you start a build |
| no git identity | `git commit` of the kernel pin fails — and the pin is what makes the kernel reproducible |
| no SSH key, but the remote is `git@github.com:` | the clone itself fails |
| no `gh` | cannot push the resolved pin back without extra manual auth |

It generates an SSH key **and tells you to add the public key** (it cannot add it
for you), or `--https` to switch the remote instead. It writes git identity
repo-locally so nothing leaks into unrelated repositories on a shared host.

## Two things that are easy to get wrong, and are handled here

**1. kbuild prefers `Makefile` over `Kbuild`.** Every directory Kbase owns ships
*both*, and the `Makefile` is the Android/out-of-tree one (it expects `KDIR` and
errors otherwise). A plain copy therefore never reaches
`obj-$(CONFIG_MALI_MIDGARD) += midgard/`. `build.sh` step 2 sets the Android
`Makefile` aside as `Makefile.android-orig` and installs `Kbuild` in its place.
This happens only inside the disposable fetched tree — `vendor/arm/` is never
touched. To reset: `rm -rf kernel/sources/linux/<version>` and re-fetch.

**2. The payload root is the kernel tree root.** `driver/product/kernel/` contains
`drivers/`, `include/` and `Documentation/`, so staging merges it into the kernel
*source root*, not into `drivers/gpu/arm/`.

Step 5/8 then re-reads the merged `.config` and checks that **every** `CONFIG_*` in
the profile fragment actually took effect — detecting symbols dropped as unknown
(values silently clobbered back to defaults is the dangerous case). If any symbol
did not take, it prints a table and exits non-zero *before* compiling, because a
kernel that quietly lacks Kbase is worse than no kernel.

## Design rules these scripts follow

- **Repository-relative paths.** No hard-coded host paths, so a clone runs anywhere.
- **Pinned and verified inputs.** The kernel comes from `kernel.pin` with a
  mandatory checksum. A cached tarball that does not match the pin is a hard
  error, never silently overwritten.
- **Fail loudly.** Bad arguments exit non-zero; checksum mismatch is fatal; the
  host preflight refuses an inadequate machine; a fragment symbol that did not take
  stops the build.
- **Nothing hidden.** Each build writes a log under `build/logs/` and a
  `build-metadata.txt` (config hash, patch-series hash, payload fingerprint,
  compiler, host, timestamp).
- **Non-destructive.** The pristine Kbase tree is never patched in place; the
  patched tree is rebuilt from pristine each run.

## What these scripts do NOT do

- They do **not** boot QEMU, package an artifact, or mark anything portable
  (separate steps; see `../../artifacts/README.md`).
- They do **not** build a rootfs or install syzkaller — `qemu/rootfs/` and
  `syzkaller/` are documentation placeholders, so those states are not reachable
  from this repository alone.
- They do **not** advance `research/state.md`; state advances only after
  human/tool verification, per `../BUILD-PLAN.md`.
- They do **not** duplicate program scope policy — see
  `../../research/program-scope.md`.

## Order of operations

```bash
bash kernel/scripts/bootstrap.sh --yes
bash kernel/scripts/resolve-kernel-pin.sh --dry-run   # inspect the choice first
bash kernel/scripts/resolve-kernel-pin.sh
bash kernel/scripts/preflight.sh                      # expect READY
# COMMIT the pin, so the kernel choice is reproducible rather than local.
bash kernel/scripts/fetch-kernel.sh
bash kernel/scripts/apply-patches.sh
bash kernel/scripts/build.sh --profile baseline
```

Then follow `../BUILD-PLAN.md` for baseline validation, the instrumented
profiles, rootfs/QEMU, packaging, and the clean-location portability test.