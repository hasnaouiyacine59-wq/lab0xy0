# Syzkaller scripts

Future helper scripts that wire syzkaller to a **packaged artifact**. **Empty in
this phase** — nothing here builds the kernel/Kbase or boots QEMU; those are done
before, when the artifact is produced.

## Planned helpers

| Script | Purpose | Status |
|---|---|---|
| `fetch-artifact.sh` | resolve/validate a portable artifact bundle (checks `SHA256SUMS`) | PLANNED |
| `run-target.sh` | launch syzkaller against a chosen profile's packaged target | PLANNED |

None exist yet.

## Requirements

- Repo-relative / artifact-relative resolution; no hard-coded host paths, so an
  unpacked artifact runs from any location.
- Verify the artifact's `SHA256SUMS` before use — syzkaller must fuzz a validated
  bundle, not an arbitrary tree.
- Never trigger a kernel/Kbase build; the artifact is the input.