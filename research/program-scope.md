# Arm Bug Bounty Program — scope policy

**This file is the single source of truth for mutable Arm program scope.**

Do not duplicate this policy in `analysis/findings.md` or anywhere else. Findings
reference this file; findings do not restate it. When scope changes, this file is
updated and dated, and referencing documents are pointed back here.

```text
Scope assessment date: 2026-09-30
Assessed by:           lab0xy0 organisation phase
Policy version:        1.1
```

### Change log

| Version | Date | Change |
|---|---|---|
| 1.0 | 2026-09-30 | Initial capture of the Intigriti program page and the four supplied PDFs. |
| 1.1 | 2026-09-30 | Added the **Kbase build/dynamic configuration allowlist** (§8) verbatim from the program's in-scope statement, the **in-scope version rule**, the explicit **EL0-only** exploitability rule, the two Arm download URLs, and the **DECISION-1** investigation-only status of the x86_64 virtual harness (§8.4). |

## Evidence sources for this assessment

| Source | Identity | Date |
|---|---|---|
| Intigriti program page `https://app.intigriti.com/programs/arm/arm/detail` | program scope, tiers, exclusions | retrieved 2026-09-30 |
| `arm_gpu_bug_bounty_device_configuration_guidelines.pdf` | version `20250623-1.0` | 2025-06-23 |
| `arm_gpu_bug_bounty_faq.pdf` | — | 2025-06-23 |
| `arm_gpu_bug_bounty_how_to_guide.pdf` | — | 2025-06-23 |
| `arm_gpu_virtual_platform_how_to_guide.pdf` | — | 2025-06-23 |

Checksums in `documents/README.md`. This assessment is **VERIFIED** with respect to
the above sources as retrieved on the assessment date. It is not legal advice and
does not bind Arm; Arm may alter program terms at any time.

## 1. In-scope assets and this project's target

| Asset | Tier | Range | Reachable from this repo? |
|---|---|---|---|
| Firmware: Mali CSF Firmware (`CSFFW`) | Tier 2 | $1,000 – $20,000 | **NO** — no firmware blob present |
| Software: Mali GPU Kernel Driver (`Kbase`) | Tier 3 | $500 – $10,000 | **yes — the target** |

```text
DOCUMENTED PROGRAM TARGET FOR THIS PROJECT:  Kbase only (Tier 3, $500–$10,000)
```

`CSFFW` is not a target here because the required firmware binary is absent. No
firmware target is fabricated. Kbase is the lower-tier asset; the tier ceiling for
any finding in this project is **$10,000**.

## 2. Attack model

| Requirement | Value | Status |
|---|---|---|
| Locality | local | VERIFIED |
| Privilege | unprivileged | VERIFIED |
| Userspace | yes | VERIFIED |
| Arm exception level | EL0 | VERIFIED |

**Consequence for this project (INFERRED):** an x86_64 virtual platform device has
no EL0/EL1/EL2 split and no secure world, so EL0 semantics cannot be reproduced
locally. Findings must be re-confirmed on conforming real hardware before
submission — consistent with the program's own statement that PoCs must run in
Arm's internal test environments.

## 3. Reproducibility requirements

| Requirement | Value | Status |
|---|---|---|
| PoC required | yes, must demonstrate impact | VERIFIED |
| Reproducible with **unmodified** driver | yes | VERIFIED |
| Reproducible with **unmodified** `CSFFW` | yes | VERIFIED (not applicable here — no CSFFW) |
| Codepath delays permitted | yes | VERIFIED |
| Config changes **listed in scope** permitted | yes | VERIFIED |
| Reproduction device must conform to configuration guidelines | yes | VERIFIED |

Reproducible on a device conforming to the configuration guidelines
(`arm_gpu_bug_bounty_device_configuration_guidelines.pdf`). This is the hinge on
which §5 and §6 turn.

## 4. Eligible device / OS guidance

| Guidance | Value | Status |
|---|---|---|
| New virtual environment → kernel choice | latest Android Common Kernel, or latest Linux Kernel stable or longterm release | VERIFIED ARM GUIDANCE |
| Hardware device | OEM-supported, fully updated | VERIFIED ARM GUIDANCE |
| Missing backports / vendor customizations | **not in scope** — report to OEM | VERIFIED |
| Kernel bitness | **64-bit only**; no 32-bit kernels or 32-bit kernel config, other than `CONFIG_COMPAT` | VERIFIED |

**64-bit only** fixes the intended guest architecture for this project as `x86_64`.
A 32-bit test kernel must not be constructed.

## 5. Kernel configuration allowlist

Where possible the **default kernel configuration** must be used. Only the
following kernel Kconfig options may be changed, provided the result is still a
valid configuration and the options are compatible with each other:

```text
CONFIG_COMPAT

one of:
    CONFIG_ARM64_4K_PAGES
    CONFIG_ARM64_16K_PAGES
    (the other set to n)

any  CONFIG_KASAN*      except  CONFIG_KASAN_*_TEST  must be n
any  CONFIG_UBSAN*      except  CONFIG_TEST_UBSAN    must be n
```

Status: **VERIFIED**. Status: do not silently expand this allowlist.

Note the list is kernel-build options. Kbase's own `CONFIG_MALI_*` module options
are governed separately (§8).

## 6. Discovery environment vs validation environment

The research harness may be instrumented for **discovery**. The **validation**
environment must conform to §5. These are distinct environments with distinct
claims, and a finding's eligibility is determined by the validation environment.

```text
DISCOVERY ENVIRONMENT
    instrumentation permitted as needed to find or reproduce behaviour
    findings recorded as DISCOVERY-ONLY where the configuration violates §5

VALIDATION ENVIRONMENT
    configuration conforms to §5
    the PoC is re-run here
```

Consequences, stated explicitly:

- The usefulness of KCOV for discovery does **not** make a non-conforming KCOV
  kernel an eligible validation environment.
- A finding is **not** eligible merely because it crashes under an instrumented
  harness.
- If behaviour occurs **only because of instrumentation**, that must be recorded
  explicitly, and the finding is not eligible.
- A finding is eligible only if it reproduces on a conforming configuration.

## 7. Scope classes used across this repository

| Class | Meaning |
|---|---|
| `IN SCOPE` | reportable subject to §3 reproducibility on a conforming device |
| `DISCOVERY-ONLY` | reachable in a non-conforming harness; must be re-confirmed per §6 |
| `EXCLUDED` | named in program exclusions (§9) |
| `UNKNOWN` | not yet assessable; do not assume |

These classes are used in `research/test-matrix.md` and, by reference, in
`analysis/findings.md`.

## 8. Kbase build & dynamic configuration policy

**This section is distinct from the kernel allowlist in §5.** §5 governs *kernel*
Kconfig options; this section governs the *Kbase module's* own configuration, both
at build time and at `insmod` time. The text in §8.1–§8.3 is the program's in-scope
configuration statement, captured verbatim in meaning.

### 8.1 In-scope Kbase versions

```text
The latest Arm Bifrost, Valhall, or 5th Gen GPU Kernel driver versions, as found on
    https://developer.arm.com/downloads/-/mali-drivers/
or
Arm Bifrost, Valhall, or 5th Gen GPU Kernel driver versions r49p1 and above that are
running on devices supported by the OEM and have the latest available security
patches applied.
```

Status: **VERIFIED**. Consequence for this project: `r54p0-01eac0` satisfies the
`r49p1 and above` branch. Whether it is also the *latest* on the downloads page is
**UNKNOWN** and deliberately not resolved here: DECISION-3 keeps r54p0 primary
because the supplied patch series is an r54p0 series (see §8.5).

### 8.2 Exploitability requirement

> Only vulnerabilities that are exploitable through syscalls available to
> unprivileged userspace attackers (in EL0) are in scope.

Status: **VERIFIED**. This is consistent with §2 and sharpens it: the entry point
must be an unprivileged syscall, not merely an unprivileged process.

### 8.3 Kbase build configuration

```text
Mali Kbase Default KConfig Build Options are used.

The following must specifically be set:
    CONFIG_MALI_DEBUG=n

Additionally, the following options may be changed:
    CONFIG_MALI_CSF_SUPPORT=y or n   (see FAQ for which setting must be used)
    CONFIG_MALI_EXPERT=y or n
    CONFIG_LARGE_PAGE_SUPPORT=y or n
    CONFIG_MALI_TRACE_POWER_GPU_WORK_PERIOD=y or n
    CONFIG_MALI_NO_MALI, either:
        =n (default)
        =y (excludes vulnerabilities in the "dummy model" code itself)
```

Status: **VERIFIED**. This is a *strict* allowlist. Anything outside it — plus the
five options above — is out of scope except during investigation.

Source reconciliation against r54p0 `drivers/gpu/arm/midgard/Kconfig` (VERIFIED):

| Program symbol | r54p0 symbol | r54p0 default | Note |
|---|---|---|---|
| `CONFIG_MALI_DEBUG` | `MALI_DEBUG` | **n** (`Kconfig:197`) | must be explicitly `n` |
| `CONFIG_MALI_CSF_SUPPORT` | `MALI_CSF_SUPPORT` | n (`Kconfig:83`) | CSF GPUs set `y`; JM set `n` |
| `CONFIG_MALI_EXPERT` | `MALI_EXPERT` | **n** (`Kconfig:156`) | required before `MALI_NO_MALI`/`LARGE_PAGE_SUPPORT` are selectable |
| `CONFIG_LARGE_PAGE_SUPPORT` | `LARGE_PAGE_SUPPORT` | y (`Kconfig:166`) | note: **no** `MALI_` prefix |
| `CONFIG_MALI_TRACE_POWER_GPU_WORK_PERIOD` | `MALI_TRACE_POWER_GPU_WORK_PERIOD` | y (`Kconfig:333`) | |
| `CONFIG_MALI_NO_MALI` | `MALI_NO_MALI` | choice alternative to `MALI_REAL_HW` | dummy-model bugs excluded |

**JM vs CSF** (from the FAQ): early Valhall GPUs are Job Manager (JM); later
Valhall are Command Stream Frontend (CSF). Packages vary in which they support and
the version string does not say which, so the program advises using the

```text
https://developer.arm.com/downloads/-/Mali 5th Gen GPU Architecture
```

packages for CSF GPUs, **targeting the latest GPU when compiling** (the
`CONFIG_MALI_NO_MALI=y` case is given as the example).

### 8.4 Dynamic (insmod) configuration

```text
The default module parameter settings must be used.

Additionally, the following option(s) may be changed (chosen at 'insmod' time):
    kbase_page_migration_enabled  ...
```

Status: **VERIFIED in part** — the supplied list is **truncated** after
`kbase_page_migration_enabled`; the complete set is **UNKNOWN**. Consequence: we do
**not** rely on the `no_mali_gpu` module parameter as an in-scope override. The
virtual discovery build sets the GPU target at *compile* time instead (§8.4.1).

#### 8.4.1 DECISION-2 — GPU target set at compile time

Because `no_mali_gpu` is not a permitted `insmod` override, the GPU target is chosen
by `CONFIG_MALI_NO_MALI_DEFAULT_GPU` at build time. "Targeting the latest GPU when
compiling" was applied literally against r54p0's own GPU table, whose newest entry is
**`tDRx`** (arch 14.8.5) — newer than the `tKRx` named in Arm's virtual-platform
guide. Status: source-level **VERIFIED**, runtime **NOT_TESTED**. Full evidence,
including why `tDRx` is genuinely supported and not a stale string, is in
`../analysis/kconfig-dependencies.md`; the reconciliation history is finding F-4 in
`../analysis/findings.md`.

### 8.5 DECISION-1 — the x86_64 virtual environment is INVESTIGATION-ONLY

```text
DECISION-1 (2026-09-30):
    Declare the x86_64 + CONFIG_MALI_NO_MALI + MALI_PLATFORM_NAME="vexpress"
    virtual environment INVESTIGATION / DISCOVERY-ONLY.
    Do NOT force the virtual harness into Arm's strict production-validation
    Kbase KConfig allowlist. Findings reached here must be re-confirmed on a
    conforming real-hardware environment before submission.
```

Rationale (VERIFIED): the x86 Simulated Platform Device **requires**
`MALI_PLATFORM_NAME="vexpress"` (`research/documents/…virtual_platform…pdf`), and a
GPU target via `MALI_NO_MALI_DEFAULT_GPU`, neither of which appears in the §8.3
allowlist. Rather than distort the harness to pretend it is a validation
environment, this project classifies the whole x86 NO_MALI path as
**DISCOVERY-ONLY** per §6. A conforming validation config is defined as: default
KConfig + `CONFIG_MALI_DEBUG=n` + at most the five §8.3 options on real hardware.

DECISION-2 (GPU target) and DECISION-3 (package base) are recorded in
`../analysis/kconfig-dependencies.md` and `../analysis/kbase-version.md`
respectively.

Virtualized testing of Kbase is explicitly contemplated; the program states it is
possible to conduct some testing of Kbase using a virtualized environment, with
guidance in the FAQ. See `../analysis/virtual-device.md` for the x86 Simulated
Platform Device configuration.

## 9. Out of scope — exclusions bearing on this project

From the program page, as of the assessment date:

**General**

- undefined-behaviour violations without proof of an exploitable vulnerability
- local temporary DoS resolved by reboot
- privacy/fingerprinting lowering; covert channels; side channels; TZMP bypass
- already known to Arm (duplicates)
- theoretical issues with no realistic exploit scenario or attack surface
- spam, social engineering, physical intrusion; DDoS; brute force
- software/devices no longer receiving security updates
- physical access, MITM, or compromised accounts
- zero-days found within 14 days of a public patch/mitigation (reportable, usually
  not bounty-eligible)
- "out of date / vulnerable" claims without a PoC

**Kbase-specific (all VERIFIED as stated by the program)**

| Exclusion | Bears on this project how |
|---|---|
| Only exposed through **debugfs**, even if world-readable/writable | the harness has debugfs at `/sys/kernel/debug/mali0`; such findings are excluded |
| Only exposed through **privileged** sysfs/procfs files | not reportable via privileged-only interfaces |
| Only exposed through **TEST config options** | e.g. `MALI_KUTF` paths — excluded |
| **"dummy model" code** | the `MALI_NO_MALI` harness model — see `analysis/findings.md` F-8 |
| Non-mali modules, or Mali drivers other than Kbase (Lima, Panfrost, Panthor) | out of target |
| **The Linux kernel** | Linux-side bugs are excluded |
| **The supplied virtual-device patches** | `patches/virtual-device/` is out of scope as a vulnerability location |
| Code not intended for production, e.g. exposure of performance counters or instrumentation to untrusted users | our own KCOV work |
| Vendor/platform-specific code | report to the relevant OEM |

**Discretionary bonus** (submit but not bounty): functional bugs and security
issues not meeting bounty criteria, e.g. Kbase `WARN*` kernel warnings producing a
call trace, crashes killing the caller or requiring reboot, undefined-behaviour
violations. A NULL-pointer dereference causing a crash may not be in-scope.

## 10. Severity examples

| Severity | Examples given |
|---|---|
| High | gain root; unauthorized code execution (e.g. ROP) on GPU firmware. Root not required to be demonstrated, only that the modified area is sensitive enough that it could happen. |
| Medium | control of other userspace processes; expose sensitive data normally inaccessible to the attacker's EL0 process, direct serious impact. Control need not be demonstrated, only that the area is sensitive enough. |
| Low | expose sensitive data or metadata normally inaccessible to the attacker's EL0 process. |

Rewards are at Arm's discretion; the usual basis is demonstrated impact and
severity. Full ranges in §1.

## 11. Program conduct and practical constraints

| Item | Value |
|---|---|
| Eligibility | must not be resident in / submit from an embargoed or sanctioned country; not an Arm employee or one who left within 12 months; not an immediate family member of such; 18+ |
| Conduct | Community Code of Conduct; Intigriti T&C; respect scope |
| Disclosure | may not disclose without prior written consent from Arm PSIRT (incl. PoCs on YouTube/Vimeo) |
| Jurisdiction | law of England & Wales; courts of London |
| Safe harbour | applied; Arm will not pursue action for consistent good-faith activity, but cannot grant authority over third-party software |
| Response time | avg first response / decide / triage all ~3+ weeks (as displayed on the program page) |
| Platform note | submissions require a valid Intigriti account |

## 12. AI-assisted submissions

Arm welcomes AI tooling for vulnerability discovery but states that submissions
which merely copy LLM-generated findings without validating accuracy,
reproducibility, and security impact will not be rewarded — reports that simply
reproduce tool output are likely to reproduce information Arm already has.
Submissions must go beyond identifying a potential bug and demonstrate a
meaningful security impact via a clear reproducible PoC runnable in Arm's internal
test environments. Reports lacking sufficient evidence are closed but may be
resubmitted once validated.

This repository produces evidence and harnesses, not submission text. Any finding
must independently clear the reproducibility bar in §3 and §6 before drafting.

## 13. Scope gaps — things the program does not clearly settle

- The interaction between the §5 kernel allowlist and discovery instrumentation is
  not stated explicitly by the program; §6 of this document is this project's
  interpretation (INFERRED), not Arm's wording.
- Whether a bug reproducible only under a *conforming* KASAN/UBSAN configuration
  but not under default config is eligible is not spelled out; treated here as
  eligible, since §5 explicitly permits those options (INFERRED).
- Exact kernel versions paired with each Kbase release are not publicly
  documented by Arm and "will change over time"; only the latest-ACK/latest-LTS
  guidance is given (VERIFIED as guidance, UNKNOWN as a specific version).
- Whether an x86_64 virtual-platform finding is eligible without device
  confirmation is not addressed; treated here as NOT eligible until confirmed
  (§2, §3).
- The complete list of permitted dynamic (insmod) module parameters is not fully
  available — the supplied text is truncated after `kbase_page_migration_enabled`
  (UNKNOWN; see §8.4).
- Whether `MALI_PLATFORM_NAME` and `MALI_NO_MALI_DEFAULT_GPU` count as part of the
  permitted `MALI_NO_MALI` configuration is not stated. DECISION-1 (§8.5) resolves
  this by classifying the whole x86 virtual harness as investigation-only rather
  than claiming either reading (INFERRED, project decision).

## Change control

Update this file — never a copy — when the program terms change. Bump `Policy
version`, re-date `Scope assessment date`, list new evidence sources in the table
in the header, and note what changed. Downstream documents reference this file and
need no policy edit, only re-dating of their own assessment stamps.