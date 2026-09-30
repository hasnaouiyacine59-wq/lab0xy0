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

`scripts/bootstrap.sh` installs exactly this list; it is repeated here so the
document and the machine cannot drift apart.

```bash
sudo apt-get update
sudo apt-get install -y \
    build-essential gcc make flex bison bc libelf-dev libssl-dev \
    libncurses-dev xz-utils cpio kmod rsync zstd git curl ca-certificates \
    python3
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

- The Linux version is **not** pinned in this repository yet. Resolve it on the
  build host with `scripts/resolve-kernel-pin.sh`, which implements Arm's "latest
  stable/longterm" guidance from kernel.org's own metadata, and then **commit the
  pin** so the choice is reproducible rather than local to one machine.
- The config fragments in `kernel/configs/` are **provisional**; the real baseline
  `.config` is produced on the build host from a default kernel config plus the
  minimum Kbase requirements.
- Nothing here has been compiled or booted; `research/state.md` is `NOT_STARTED`.

## GitHub Codespaces as the build host

Codespaces is a workable build host and `.devcontainer/devcontainer.json` is set
up for it, but four things will bite if they are not handled first.

| Issue | What happens | What to do |
|---|---|---|
| **Machine spec** | The 2-core/8 GB spec fails `preflight.sh` (needs ≥25 GB disk, 8–16 GB RAM) | Pick **4 cores / 16 GB / 64 GB**. `hostRequirements` in the devcontainer asks Codespaces to auto-select it. |
| **No `/dev/kvm`** | `preflight.sh` warns; QEMU falls back to TCG | Expected. Compilation is unaffected. KASAN+KCOV fuzzing will be slow — accept it, or move fuzzing to a dedicated host. |
| **Auto-stop** | An idle Codespace stops, killing a `make -j` mid-build | Raise/disable the idle timeout before starting a long build, or run under `nohup` and poll. |
| **SSH remote** | The remote is `git@github.com:...`, so `git clone` needs a key | Add a Codespaces SSH key to the GitHub account, or clone over HTTPS: `https://github.com/hasnaouiyacine59-wq/lab0xy0.git` |

`scripts/codespace-setup.sh` handles all four. It is the **first** command to run
in a fresh Codespace; it installs the toolchain through `bootstrap.sh`, then fixes
the things that are *not* apt packages and that otherwise fail confusingly:

- **machine spec**, checked before you start a build rather than after;
- **git identity**, because the step that makes the kernel reproducible
  (`git commit` of the pin) is the first thing that needs it;
- **GitHub access** — generates an SSH key and prints the public key for you to
  add, or `--https` to switch the remote instead;
- **`gh`**, for pushing the pin back.

The devcontainer runs `bootstrap.sh` in `onCreateCommand` and
`codespace-setup.sh` in `postCreateCommand`, so a correctly-sized Codespace is
ready before you type anything.

```bash
bash kernel/scripts/codespace-setup.sh              # start here
bash kernel/scripts/codespace-setup.sh --check      # report only, change nothing
bash kernel/scripts/codespace-setup.sh --https      # prefer HTTPS over SSH
bash kernel/scripts/resolve-kernel-pin.sh --dry-run
bash kernel/scripts/resolve-kernel-pin.sh
bash kernel/scripts/preflight.sh                    # expect READY
git commit -am "pin kernel <version>" && git push
bash kernel/scripts/fetch-kernel.sh
bash kernel/scripts/apply-patches.sh
bash kernel/scripts/build.sh --profile baseline
```

`codespace-setup.sh` deliberately does **not** fetch a kernel, build anything, or
write the pin. Those stay separate, deliberate steps.

Disk note: one extracted Linux tree plus one `O=` output is ~3 GB. Building several
profiles at once needs 40 GB+; `build.sh` keeps one shared source tree precisely so
you can build profiles one at a time and prune between them.

## Scope reminder

A discovery-only instrumented environment (kcov/debug) is not a compliant
validation environment under Arm's rules. See `../research/program-scope.md`; do
not duplicate that policy here.