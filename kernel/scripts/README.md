# kernel/ scripts

Build machinery for the portable lab. These scripts run on the **build host**
(not the machine that organised the repo). They are written and syntax-checked
here but **have not been executed**, because this repository's organising host is
not a build host — see `../BUILD-HOST.md`.

## Scripts (run in this order)

| # | Script | What it does | Executed here? |
|---|---|---|---|
| 1 | `preflight.sh` | read-only host check (arch, disk, RAM, tools, checksums, pin). Exits non-zero if the host cannot build. | **yes** — ran read-only, correctly reported NOT READY |
| 2 | `fetch-kernel.sh` | reads `kernel/sources/kernel.pin`, downloads the exact tarball, **verifies SHA-256 (fatal on mismatch)**, extracts to `kernel/sources/linux/<version>/`. No floating "latest". | **no** — pin is `UNSET`; it refuses before any network call |
| 3 | `apply-patches.sh` | extracts pristine r54p0 to `work/kbase-pristine/` (never patched in place), copies to `work/kbase-patched/`, applies the six Arm patches in order with `patch -p1`, writes the patch-series hash. | **no** |
| 4 | `build.sh --profile <p>` | one shared build entry: seed `.config` from kernel default + profile fragment, compile kernel with `make O=build/<profile>`, build Kbase in-tree, emit metadata. | **no** |

There is deliberately **one** `build.sh --profile …`, not four
`build-<profile>.sh` scripts.

## Design rules these scripts follow

- **Repository-relative paths.** No hard-coded host paths, so a clone runs anywhere.
- **Pinned and verified inputs.** The kernel comes from `kernel.pin` with a
  mandatory checksum. A cached tarball that does not match the pin is a hard
  error, never silently overwritten.
- **Fail loudly.** Bad arguments exit non-zero; checksum mismatch is fatal; the
  host preflight refuses an inadequate machine.
- **Nothing hidden.** Each build writes a log under `build/logs/` and a
  `build-metadata.txt` (config hash, patch-series hash, host, timestamp).
- **Non-destructive.** The pristine Kbase tree is never patched in place; the
  patched tree is rebuilt from pristine each run.

## What these scripts do NOT do

- They do **not** boot QEMU, package an artifact, or mark anything portable
  (separate steps; see `../../artifacts/README.md`).
- They do **not** advance `research/state.md`; state advances only after
  human/tool verification, per `../../kernel/BUILD-PLAN.md`.
- They do **not** duplicate program scope policy — see
  `../../research/program-scope.md`.

## Manual order of operations

```bash
./kernel/scripts/preflight.sh
#   (fill kernel/sources/kernel.pin with an exact version + checksum)
./kernel/scripts/fetch-kernel.sh
./kernel/scripts/apply-patches.sh
./kernel/scripts/build.sh --profile baseline
```

Then follow `../BUILD-PLAN.md` for baseline validation, the instrumented
profiles, rootfs/QEMU, packaging, and the clean-location portability test.