# Syzkaller configs

Future syzkaller **manager / target** configuration files. **Empty in this phase.**

These will point at a **packaged artifact** (`artifacts/`), not at a build tree:

```ini
# shape this will take (PLANNED, not written yet)
[target.x86_64]
    kernel_src = <artifact>/kernel/vmlinux          # packaged, not a build dir
    kernel_obj = <artifact>/kernel/bzImage
    image       = <artifact>/rootfs/...
    ssh         = ...
    # Kbase module load + /dev/mali0 fuzzing target
```

## Requirements

- **Consume the packaged artifact.** The `kernel_obj` / `image` paths must resolve
  inside a portable artifact bundle, so the same target config works from any host
  that has unpacked the artifact.
- **Per-profile targets.** One config per kernel profile (`baseline`, `kcov`,
  `kasan`, `debug`), each referencing its packaged kernel + Kbase module bundle.
- **No build coupling.** Nothing here invokes a kernel or Kbase build; those
  produce the artifact beforehand.

No `.cfg` files exist yet. See `../README.md` for the overall relationship.