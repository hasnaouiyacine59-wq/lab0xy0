# Supplied Arm documents

Vendor-supplied reference material for the Arm Bug Bounty Program. Held here for
research/reference use. **These files are not modified** — see *Provenance rules*.

## Inventory

| # | Filename | SHA-256 | Version | Provenance | Status |
|---|---|---|---|---|---|
| 1 | `arm_gpu_bug_bounty_device_configuration_guidelines.pdf` | `0056c0dc02cc8daebc275b80a957af37f08c950a9a44e71b606487e35f356c6e` | `20250623-1.0` | Intigriti program attachment (`/programs/arm/arm/detail`), uploaded 6/23/2025 | VERIFIED |
| 2 | `arm_gpu_bug_bounty_faq.pdf` | `fc6bd67ab5cef838b9d1c25196bb094bada4f7c2fd2317d5a86c5b709bd10985` | not stated | Intigriti FAQ attachment, uploaded 6/23/2025 | VERIFIED |
| 3 | `arm_gpu_bug_bounty_how_to_guide.pdf` | `4a6e4d419f4ee357e246c555a480578bf88a0246824148b0a6e428422167ce2a` | not stated | Intigriti FAQ attachment, uploaded 6/23/2025 | VERIFIED |
| 4 | `arm_gpu_virtual_platform_how_to_guide.pdf` | `e567a2abb3277391c9baeb900e80238fc15874b28e8b14bfd3acf5ce5268c9cf` | not stated | Intigriti FAQ attachment, uploaded 6/23/2025 | VERIFIED |
| 5 | `patches_for_virtual_device.zip` | `992f92f1bfe455f541f5e1021e49162f96a458327ef38f927e8c8b0078172b60` | not stated | Intigriti FAQ attachment, uploaded 3/13/2025 | VERIFIED |

Verify with:

```bash
( cd research/documents && sha256sum -c SHA256SUMS )
```

`SHA256SUMS` holds the five hashes above; it is generated from the bytes on disk
and passes.

## Copy provenance

Documents 1–4 were originally staged in a working directory alongside
`patches_for_virtual_device.zip` and moved here unmodified; a `cmp` against the
originals was clean at move time.

For document 1 specifically, **three copies were inspected and all were
byte-identical** (SHA-256 above):

```text
research/documents/…guidelines.pdf                    (repository copy)
~/Downloads/arm_gpu_bug_bounty_device_configuration_guidelines.pdf
~/Downloads/arm_gpu_bug_bounty_device_configuration_guidelines (1).pdf
```

The repository copy arrived as `…guidelines (2).pdf`; the duplicate `(2)` suffix
was stripped from the **filename only** — PDF contents untouched (`cmp` clean).

Documents 2–4 were inspected from a single copy each; no duplicate-copy
comparison was established for them, so none is claimed.

Document 5 is the upstream container for the six virtual-device patches. Its
contents were extracted byte-identically to `patches/virtual-device/`; the zip is
retained as provenance. Checksums of the extracted patches are in
`patches/virtual-device/SHA256SUMS`.

## Document roles

| Document | What it establishes for this repository |
|---|---|
| 1 — device configuration guidelines | The **kernel-config allowlist**, the **64-bit-only** rule, and the **latest ACK / latest stable-LTS** kernel guidance. Authoritative for §10–§14 of the project spec. |
| 2 — FAQ | In-scope config guidance (`CONFIG_MALI_CSF_SUPPORT`), JM vs CSF GPU families. |
| 3 — how-to guide | General testing/PoC workflow. |
| 4 — virtual platform guide | The x86 **Simulated Platform Device** configuration (`CONFIG_MALI_MIDGARD=m`, `MALI_NO_MALI=y`, `MALI_PLATFORM_NAME="vexpress"`, …) and the correspondence to `patches/virtual-device/`. |
| 5 — patch zip | The six supplied Arm patches. Already extracted to `patches/virtual-device/`. |

Document 4 is the origin of the kernel options recorded in `kernel/configs/`.
Its `CONFIG_MALI_*` options are **Kbase module** options and are distinct from the
**kernel** `CONFIG_*` allowlist in document 1.

## Provenance rules

- Do not modify, reformat, or re-encode these PDFs or the zip.
- Do not redistribute them outside this repository. Each is separately
  copyrighted by Arm; document 1 additionally carries a proprietary-notice and
  export-control notice on its pages 3–4.
- Policy derived from these documents is recorded in
  `../program-scope.md`, not duplicated into the analysis documents.

## Machine-readable note

Document 1's text layer uses a subsetted font with no `/ToUnicode` CMap, so
naive text extraction returns empty strings. Glyph codes are a constant `+0x1D`
offset from ASCII, with ligature codes at `0x0CE1` (`fi`), `0x0CF2` (`ff`),
`0x0CFB` (`ffi`), `0x0CFC` (`ffl`). Any future re-extraction must account for this
or it will silently produce nothing.