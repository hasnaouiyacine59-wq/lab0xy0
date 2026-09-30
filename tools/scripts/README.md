# Project tools

Small, dependency-light helpers this repository uses across phases (checksum
verification, config-delta classification, manifest generation). **Empty in this
phase** — no helper scripts are written yet; each is justified only once there is a
real build or packaging step to support.

## Planned helpers (none written yet)

| Helper | Purpose | Justification |
|---|---|---|
| `verify-artifact.sh` | check an artifact's `SHA256SUMS` and manifest integrity | needed before any artifact is trusted |
| `config-delta.sh` | run `savedefconfig` and classify every delta vs. the baseline (`NO-OP` / `ALLOWLISTED` / `REQUIRED INTERNAL DEPENDENCY` / `NON-CONFORMING` / `UNKNOWN`) | the mandatory config-compliance check (project spec §18) |
| `gen-manifest.py` | emit `metadata/manifest.json` for an artifact | packaging step |

## Requirements for any helper added here

- Repo-relative paths; no hard-coded host locations.
- Deterministic and idempotent — safe to re-run; re-running must not mutate a
  validated artifact.
- Fail loudly with a non-zero exit on any integrity or config-delta violation.
- Never modify vendor material under `vendor/`, `research/documents/`, or
  `patches/virtual-device/`.

## Why empty now

Per the project spec's no-premature-building rule, these helpers are deferred to
the build phase. Writing a script before there is a concrete input/output to
validate against would be speculative tooling; the checks these will perform are
already specified in `../research/methodology.md` and `../artifacts/README.md`.