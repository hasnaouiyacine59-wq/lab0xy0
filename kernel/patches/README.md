# Research-authored kernel patches

This directory is for patches **this project writes**. It is not for vendor
material.

```text
patches/virtual-device/   = the six supplied Arm virtual-device patches
                             (third-party; VERIFIED to apply to r54p0)

kernel/patches/            = future research-authored Linux-kernel patches
                             (ours; written and justified in this project)
```

Never mix the two. Vendor patches are preserved byte-for-byte and are never
edited, reformatted, or "cleaned up"; research patches live here and are
versioned with their own rationale.

## Current contents

Empty. No research patch has been written yet.

## The one patch this project already knows it will need

**Kbase-side KCOV instrumentation.** VERIFIED: `MALI_KCOV` exists only in
`midgard/Mconfig` (the Android/SCons path), not in `midgard/Kconfig`, and its
`-fsanitize-coverage=trace-cmp` flags live only in the SCons/Android `Makefile`
an in-tree build never reads. Consequence (INFERRED): an in-tree build yields a
Kbase module with no Kbase-side coverage instrumentation, regardless of
`CONFIG_MALI_KCOV`. See `../../analysis/findings.md` **F-2**.

The preferred fix is a `Kbuild` condition in this directory that appends
`-fsanitize-coverage=trace-cmp` for the coverage profile — it keeps the change in
the research-patch category and leaves vendor source untouched. Writing this
patch is a build-phase task, and its effect must be confirmed by observing actual
coverage from Kbase code (state `KCOV_VERIFIED`), not assumed from the diff.

## Requirements for any patch added here

Each research patch must be accompanied by, or reference:

- the problem it solves, and the `VERIFIED` evidence for that problem;
- the target kernel version(s) it was validated against;
- whether it changes the Arm configuration-allowlist status of a profile
  (`../../research/program-scope.md` §5);
- a recorded application order relative to `patches/virtual-device/`;
- its own SHA-256 entry, so the applied patch-set is identifiable.

A patch that only makes a build succeed is still valuable, but it must be
labelled as a build fix, not a behaviour change.