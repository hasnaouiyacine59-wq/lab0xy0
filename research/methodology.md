# Methodology

How this project investigates, records, and (later) validates. The governing
principle is that the repository's value is auditability: a future reader must be
able to re-run every claim and get the same answer.

## Evidence labels

Every technical statement carries one label. Labels are not decorative — they are
what lets a reader tell a reproduced result from a plan.

| Label | Means |
|---|---|
| `VERIFIED` | directly observed and reproducible; the command is recorded |
| `INFERRED` | follows from verified facts by reasoning; the reasoning is stated |
| `UNKNOWN` | not established; no default assumption applied |
| `NOT_TESTED` | plausible or asserted by a source, never executed here |
| `FAILED` | attempted and did not work; what was tried is recorded |
| `PLANNED` | intended for a later phase |
| `DISCOVERY-ONLY` | usable for finding behaviour, but not eligible as validation evidence |

## Forbidden inferences

These are the specific conversions this project refuses to make:

- Source-level compatibility → proven build support.
- A `KERNEL_VERSION` gate → a supported-kernel claim.
- A virtual-device result → a production-device result.
- A build-system defect → a security vulnerability.
- Instrumented-harness behaviour → an eligible finding.

The last one is why `research/program-scope.md` exists and why findings reference
it instead of restating it.

## How claims are recorded

For anything load-bearing:

1. State the claim.
2. Give the exact command or file:line that establishes it.
3. Label it.
4. If it fails or is ambiguous, say so and record what was tried.

Reproductions in this phase (all read-only against extracted sources in `/tmp`,
never in the repo) used, for example:

```bash
git apply --check -p1 <patch>          # run from the driver/ directory
grep -Rho "KERNEL_VERSION([0-9]\+, *[0-9]\+, *[0-9]\+)" <tree> | sort -u
sha256sum <file>
```

## Building (future)

- One Linux source tree; four `make O=build/<profile>` outputs. Never duplicate
  the tree.
- Start each profile from the Arm/default configuration, then apply the profile
  fragment.
- After configuring, run `make savedefconfig` and diff the minimal result against
  the approved baseline. Classify every delta: `NO-OP`, `ALLOWLISTED`,
  `REQUIRED INTERNAL DEPENDENCY`, `NON-CONFORMING`, `UNKNOWN`.
- A Kconfig symbol that auto-enables another (via `select`) is not the same as a
  user-requested policy change; classify it `REQUIRED INTERNAL DEPENDENCY`.
- Record the full build log and the config hash per profile.
- Build one profile at a time on this host, package, checksum, then delete the
  build tree (see resource note below).

## Discovery vs validation

Instrumented kernels (kcov, debug) are for **finding** behaviour. Validation must
occur on a configuration conforming to the allowlist in
`research/program-scope.md`. Every experiment in `research/test-matrix.md` is
stamped with a scope class at the time it runs; the authoritative policy stays in
`research/program-scope.md`.

## Portability validation

An artifact is not "portable" merely because it archives. The bar:

```text
build → package → copy to clean location
      → make original build tree inaccessible
      → boot packaged kernel → load Kbase → exercise target interface
      → validate fuzzer-facing interface
      → only then PORTABLE_ARTIFACT_VERIFIED
```

## Resource discipline

Host: x86_64, 4 vCPU, 7.4 GB RAM, ~3.9 GB free disk. Arm's baseline: ~16 GB RAM,
256 GB disk. Disk is the binding constraint. Prefer incremental rebuilds, minimal
userspace, and deleting build trees after packaging. Do not sacrifice required
correctness for size.

## Vendor material

Never modify Arm archives, PDFs, or the supplied patches. Preserve byte identity
and verify with `sha256sum` / `cmp`. Vendor material is read-only input to this
project; everything this project authors lives in `analysis/`, `research/`,
`kernel/`, `qemu/`, `syzkaller/`, `artifacts/`, and `tools/`.