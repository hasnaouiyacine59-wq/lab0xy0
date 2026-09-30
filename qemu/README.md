# QEMU environment

Part of the **product** of this repository, not just a build tool. The goal is to
build the QEMU-side environment once, validate it, package it, and reuse it with
multiple fuzzers — never rebuild QEMU or recreate the VM per campaign.

```text
build QEMU-side environment once
        ↓
validate
        ↓
package  (→ artifacts/, portable bundle)
        ↓
reuse with multiple fuzzers
```

## Design principles

- **Profile-agnostic setup.** One QEMU launch wrapper serves `baseline`, `kcov`,
  `kasan`, and `debug` by selecting a prebuilt kernel image + module bundle, not by
  reconfiguring the VM. Each profile's kernel and Kbase modules come from
  `artifacts/`.
- **Repository-relative references.** No hard-coded host paths. The wrapper resolves
  artifacts relative to the repo (or an explicit artifact path passed on the
  command line), so an artifact bundle can be relocated and still run.
- **No rebuilds at fuzzing time.** QEMU itself, the rootfs, and the per-profile
  images are built once and reused. BUILD-TIME is separated from FUZZING-TIME
  (see `../README.md`).
- **KVM-aware but not KVM-dependent.** `/dev/kvm` exists on this host (VERIFIED),
  so hardware acceleration is available; the wrapper should still work (slowly)
  under TCG so a validated artifact remains usable on a host without KVM.

## Current status

```text
QEMU build:        NOT STARTED (qemu-system-x86_64 not installed — VERIFIED)
QEMU package:      none
boot validation:   NOT TESTED
```

Per the project spec, QEMU is **not** built or booted in this organisation phase.
This directory is the documented plan and layout only. No scripts here download
anything or assume a particular installed QEMU.

## Layout

| Path | Purpose |
|---|---|
| `README.md` | this file — goal and design |
| `scripts/` | future launch/verify wrappers (repo-relative, profile-agnostic) |
| `rootfs/` | minimal rootfs definition and packaging (see `rootfs/README.md`) |

## Future launch flow (PLANNED)

```bash
# select a prebuilt, packaged profile artifact and boot it
qemu/scripts/run.sh --artifact <path> --profile <baseline|kcov|kasan|debug>
```

The wrapper would, in order: resolve the artifact bundle; pick `bzImage` and
`System.map` for the profile; attach the profile's `modules/` (containing Kbase);
mount the packaged rootfs as the initramfs/disk; open a control channel (serial /
socat) for the fuzzer; and start with `-enable-kvm` when `/dev/kvm` is present.
No step in that flow rebuilds anything.

## Portability

The QEMU-side environment is portable only together with the rest of the
artifact. It is not considered validated until the full procedure in
`../artifacts/README.md` (portability validation) passes from a clean location
with the original build tree inaccessible.

## Not yet decided (UNKNOWN until build phase)

- Exact QEMU version to pin (must be recorded in the artifact manifest).
- Whether the rootfs is a cpio initramfs or a small disk image; the rootfs README
  sketches the tradeoff.
- Guest networking for the fuzzer control channel (serial vs virtio-net vs vsock).
- Memory/CPU sizing that fits the 7.4 GB host while leaving room for the host.