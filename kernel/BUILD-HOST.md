# Build host requirements

The build happens **somewhere other than the machine that organised this repo.**
This file states what that machine must have, and records why the organising host
was ruled out. Read it before starting a build.

## The organising host is NOT a build host — VERIFIED measurements

Measured on the host that produced this repository. Do not build here.

| Resource | Measured | Verdict |
|---|---|---|
| Free disk | **3.8 GB** of 88 GB (96 % used) | **BLOCKER** — a kernel source tree + build output does not fit |
| RAM | 7.4 GB total, **1.6 GB available** at measurement time | insufficient for a parallel kernel build |
| Swap | 5.7 GB (mostly unused) | present, but not a substitute for RAM |
| vCPU | 4 | adequate |
| `bison` | **MISSING** | hard kernel-build requirement |
| `libelf` headers (`libelf.h`, `gelf.h`) | **MISSING** | needed for some kernel features |
| `qemu-system-x86_64` | **MISSING** | needed for boot validation |
| gcc / binutils / make / flex / bc / cpio / xz / zstd / openssl / pahole | present | adequate |
| `/dev/kvm` | present | KVM available if the build host has it |

Consequence: this repository is organised and cloned to a build machine; the
build, QEMU boot, and artifact packaging all happen there.

## Minimum requirements for the build host

### Disk (the real constraint)

Plan generously; a Linux source tree plus one build output is not small.

| Item | Approximate size |
|---|---|
| Linux source tarball (`.tar.xz`) | ~150 MB |
| Extracted Linux source | ~1.3–1.5 GB |
| One `O=` build output (baseline) | ~1–2 GB |
| Kbase pristine + patched extracts | ~10 MB |
| Packaged artifact per profile (compressed) | ~100–300 MB |

**Target: 25 GB free to be comfortable, 40 GB+ preferred** for building multiple
profiles before pruning. Build one profile, package it, record checksums, then
delete the build tree (§ low-disk strategy in `../README.md` and
`../artifacts/README.md`).

### RAM

**8 GB minimum, 16 GB preferred.** A `make -j` kernel build wants ~1 GB per job;
on 8 GB use `-j$(nproc)` cautiously or `-j4`, on 16 GB use `-j$(nproc)`.

### Toolchain (Debian/Ubuntu package names)

```bash
sudo apt-get update
sudo apt-get install -y \
    build-essential gcc make flex bison bc libelf-dev libssl-dev \
    libncurses-dev xz-utils cpio kmod rsync zstd git curl ca-certificates \
    python3 dwarves
```

- `bison`, `libelf-dev`, `libssl-dev`, `libncurses-dev`, `flex`, `bc`, `cpio`,
  `xz-utils` are **required** to build the kernel.
- `dwarves` (`pahole`) is required only if `CONFIG_DEBUG_INFO` with BTF is enabled.
- `qemu-system-x86` plus `qemu-utils` are required for boot validation.
- `libguestfs`/`debootstrap`/`busybox-static` (see rootfs plan) for the rootfs.

### Kernel modules

```bash
sudo modprobe kvm        # optional; without it QEMU falls back to TCG (slow)
```

## What must NOT be assumed

- The Linux version is **not** pinned in this repository yet; it is chosen on the
  build host per Arm guidance (latest suitable stable/LTS) and recorded in
  `kernel/sources/kernel.pin`. Do not hard-code a guess.
- The config fragments in `kernel/configs/` are **provisional**; the real baseline
  `.config` is produced on the build host from a default kernel config plus the
  minimum Kbase requirements.
- Nothing here has been compiled or booted; `research/state.md` is `NOT_STARTED`.

## Scope reminder

A discovery-only instrumented environment (kcov/debug) is not a compliant
validation environment under Arm's rules. See `../research/program-scope.md`; do
not duplicate that policy here.