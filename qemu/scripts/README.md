# QEMU scripts

Future launch and verification wrappers for the QEMU environment. **Empty in this
phase** — no scripts download, build, or boot anything yet, per the project spec's
no-premature-building rule.

## Planned scripts

| Script | Purpose | Status |
|---|---|---|
| `run.sh` | launch a prebuilt, packaged profile artifact (profile-agnostic) | PLANNED |
| `verify-boot.sh` | boot the artifact and assert Kbase loads + target interface responds | PLANNED |
| `build-env.sh` | build/package the QEMU-side environment once | PLANNED (build phase) |

None exist yet. The project spec deliberately does **not** ask for
`build-baseline.sh` / `build-kcov.sh` / `build-kasan.sh` / `build-debug.sh` here or
in `kernel/scripts/` until the actual build dependencies are established; a single
`build.sh --profile ...` design is preferred for the kernel side.

## Requirements for these scripts

- **Repository-relative paths only** — resolve the artifact bundle relative to the
  repo or an explicit `--artifact` path. Never hard-code a host path, so a packaged
  artifact can be relocated and still run.
- **No rebuild at fuzzing time.** These scripts consume prebuilt artifacts
  (`kernel/` images + `modules/` + `rootfs/`). They must not invoke a kernel build.
- **Profile-agnostic.** One launch path serves `baseline`, `kcov`, `kasan`, `debug`
  by selecting the right prebuilt components — not by reconfiguring the VM per
  profile.
- **KVM-aware, TCG-capable.** Prefer `-enable-kvm` when `/dev/kvm` is present
  (VERIFIED present here); fall back to TCG so a validated artifact still runs on
  a host without KVM.
- **Repo-relative fuzzer interface.** Expose a stable guest control channel
  (serial/socat is the current candidate) so the fuzzer side is independent of this
  repo's VM specifics.

## Control channel

The guest must expose a channel the fuzzer can drive (load module, trigger the
target interface, collect results). This is what lets a single VM artifact serve
multiple fuzzers. The exact transport (serial vs virtio-net vs vsock) is a
build-phase decision (`../README.md`, "Not yet decided").