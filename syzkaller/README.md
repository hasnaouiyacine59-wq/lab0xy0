# syzkaller integration (planned)

Syzkaller is a **planned consumer** of this repository's portable artifact — not
the definition of the environment. The VM artifact must stay as independent as
reasonably possible from any one fuzzer.

```text
portable VM artifact  (artifacts/)
        ↓
     syzkaller
        ↓
reuse the SAME kernel / rootfs / QEMU environment
```

## Principle

The artifact (kernel + Kbase module + rootfs + QEMU launch) is built and validated
**once**. Syzkaller (and any other fuzzer) then reuses that packaged artifact
without rebuilding Linux or Kbase. If syzkaller were allowed to dictate the
environment, the environment would stop being portable and reusable — which is
the opposite of this repository's goal.

## Current status

```text
syzkaller configured:    NOT STARTED
syzkaller built:         NOT STARTED
target (Kbase) manager:  NOT STARTED
```

Per the project spec, a fully working syzkaller target is **not** built in this
organisation phase. The Kbase interfaces and kernel must be validated first.

## Future relationship

1. A portable artifact is built and marked `PORTABLE_ARTIFACT_VERIFIED`
   (`../artifacts/README.md`).
2. A syzkaller **manager/target config** in `configs/` points at the packaged
   artifact — specifically the QEMU launch command, kernel, and rootfs — rather
   than at a build tree.
3. A syzkaller **description set** for the Kbase ioctl surface (the `/dev/mali0`
   ioctls) drives fuzzing over the already-running guest.
4. Coverage (from the `kcov` profile artifact) and results flow back through the
   guest control channel.

## Layout

| Path | Purpose | Status |
|---|---|---|
| `README.md` | this file — role and relationship | VERIFIED (as design) |
| `configs/` | future syzkaller manager/target `.cfg` files | empty |
| `scripts/` | future helper scripts to wire syzkaller to an artifact | empty |

## Note on Kbase as a syzkaller target

Fuzzing Kbase means fuzzing the `/dev/mali0` ioctl surface (the in-scope,
reportable path per `../research/program-scope.md`), not the debugfs or TEST-config
surfaces, which the program excludes. The future description set should target
`/dev/mali0`. This is a design note; no description set exists yet.

## Independence from this fuzzer

Because the artifact packages kernel + module + rootfs + launch independently of
the fuzzer, a second fuzzer (a different libFuzzer/AFL harness, say) can reuse the
identical environment. Keep fuzzer-specific logic in the fuzzer's own repo/branch,
not baked into the artifact.