# Root filesystem

The future rootfs is **minimal** and is itself a **reusable artifact**. It is not
built in this organisation phase.

## Purpose

The rootfs exists only to enable the guest to do what fuzzing needs:

```text
boot
Kbase module load
device interaction with /dev/mali0
debugging (serial console, logs)
coverage consumption (KCOV)
fuzzer communication (control channel)
```

It is not a general-purpose userland. A full desktop or server distribution would
waste the disk and boot time this host cannot afford, and would add attack surface
irrelevant to the Kbase target.

## Contents (planned)

Only what the above requires:

- a tiny init (`/init` or equivalent) and a shell for interactive debugging;
- `/dev/mali0` handling and the ioctl surface Kbase exposes;
- tools to load the Kbase module and read dmesg/serial output;
- whatever the fuzzer needs on the control channel;
- CA certificates / static binaries only if the fuzzer requires them.

Everything else (package managers, compilers, desktop, docs) is deliberately
omitted.

## Reusability

One rootfs serves **all** kernel profiles. The rootfs does not depend on the
kernel configuration; only the kernel image and the Kbase module bundle change
per profile. So a single packaged rootfs is built once and reused by `baseline`,
`kcov`, `kasan`, and `debug`.

## Format (tradeoff, not yet decided)

| Option | Pros | Cons |
|---|---|---|
| cpio initramfs | simple, self-contained, no partition table | rebuilt if contents change; whole image in RAM |
| small disk image (ext4) | writable, standard tooling | needs image creation + loop mount; more disk |

Either is acceptable; the choice is a build-phase decision. Whichever is used,
the rootfs is packaged into the artifact and identified in its manifest.

## Not built here

Per the project spec, the rootfs is not created in this phase. No image, no
`cpio`, no loop devices are produced now. This file records intent and constraints.

## Portability

The rootfs ships inside the portable artifact (`../artifacts/`) and is part of what
must boot from a clean location before the artifact is marked
`PORTABLE_ARTIFACT_VERIFIED`.