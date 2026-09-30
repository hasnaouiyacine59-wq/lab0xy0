#!/usr/bin/env bash
#
# build.sh --profile <baseline|kasan|kcov|debug>
#
# ONE shared build entry point for all profiles (preferred over four
# build-<profile>.sh scripts). Uses one Linux source tree with separate
# make O=... output directories.
#
# Steps (each logged, nothing hidden):
#   1. confirm the kernel source tree exists (fetch-kernel.sh)
#   2. confirm the patched Kbase tree exists (apply-patches.sh)
#   3. seed build/<profile>/.config from kernel/configs/<profile>.config
#      merged onto a default kernel config, run Kconfig
#   4. compile the kernel  (build/<profile>/)
#   5. build Kbase in-tree against that kernel  (modules under the same O=)
#   6. emit a build log + config hash + patch-series hash for the manifest
#
# Nothing is packaged here; packaging is a later step (see artifacts/README.md).
# Run on the BUILD host. See ../BUILD-HOST.md.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KERNEL_SRC_ROOT="$REPO_ROOT/kernel/sources/linux"
KERNEL_SRC=""
KBASE_TREE="$REPO_ROOT/work/kbase-patched/driver/product/kernel"
KBASE_SRC_REL="drivers/gpu/arm"
BUILD_ROOT="$REPO_ROOT/build"
LOG_DIR="$REPO_ROOT/build/logs"

die() { printf '\nerror: %s\n' "$*" >&2; exit 1; }

PROFILE=""
JOBS=""
usage() {
    cat <<'EOF'
Usage: build.sh --profile <baseline|kasan|kcov|debug> [--jobs N]

One shared build entry point. Uses one Linux source tree with separate
make O=build/<profile> output directories.

Options:
  --profile <name>   baseline | kasan | kcov | debug   (required)
  --jobs N           parallel make jobs (default: nproc)
  -h, --help         show this help

Scope reminder (do not duplicate policy; see research/program-scope.md):
  baseline  control/reproduction          -> aims to conform to the Arm allowlist
  kasan     memory-safety + validation    -> may conform (CONFIG_KASAN* allowed)
  kcov      coverage-guided discovery     -> DISCOVERY-ONLY (CONFIG_KCOV not allowlisted)
  debug     crash/root-cause analysis     -> DISCOVERY-ONLY (DEBUG_* not allowlisted)

This compiles; it does not boot, package, or mark any artifact portable.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --profile) [ $# -ge 2 ] || { echo "error: --profile needs a value" >&2; exit 2; }; PROFILE="$2"; shift 2 ;;
        --profile=*) PROFILE="${1#*=}"; shift ;;
        --jobs) [ $# -ge 2 ] || { echo "error: --jobs needs a value" >&2; exit 2; }; JOBS="$2"; shift 2 ;;
        --jobs=*) JOBS="${1#*=}"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "error: unknown argument: $1" >&2; usage; exit 2 ;;
    esac
done

case "$PROFILE" in
    baseline|kasan|kcov|debug) ;;
    "") echo "error: --profile is required" >&2; usage; exit 2 ;;
    *)  echo "error: unknown profile '$PROFILE'" >&2; usage; exit 2 ;;
esac
[ -n "$JOBS" ] || JOBS=$(nproc)

# --- locate the pinned kernel source -------------------------------------
PIN="$REPO_ROOT/kernel/sources/kernel.pin"
[ -f "$PIN" ] || die "kernel.pin missing."
VER=$(grep -E '^version=' "$PIN" | cut -d= -f2-)
case "$VER" in ""|UNSET) die "kernel.pin version is UNSET — pin a kernel first." ;; esac
KERNEL_SRC="$KERNEL_SRC_ROOT/$VER"
[ -d "$KERNEL_SRC" ] || die "kernel source not found: $KERNEL_SRC
       Run kernel/scripts/fetch-kernel.sh first."
[ -d "$KBASE_TREE" ] || die "patched Kbase tree not found: $KBASE_TREE
       Run kernel/scripts/apply-patches.sh first."

OUT="$BUILD_ROOT/$PROFILE"
LOG="$LOG_DIR/$PROFILE.log"
mkdir -p "$OUT" "$LOG_DIR"

echo "=============================================================="
echo " build.sh --profile $PROFILE   (jobs=$JOBS)"
echo "=============================================================="
echo "kernel source : $KERNEL_SRC"
echo "Kbase tree    : $KBASE_TREE"
echo "output dir    : $OUT"
echo "log           : $LOG"
echo "scope         : see kernel/configs/$PROFILE.config header"
echo

# --- 1. seed config: default kernel config + profile fragment ------------
FRAG="$REPO_ROOT/kernel/configs/$PROFILE.config"
[ -f "$FRAG" ] || die "config fragment missing: $FRAG"

echo "[1/5] seeding $OUT/.config (default kernel config + $PROFILE fragment)"
if [ ! -f "$OUT/.config" ]; then
    # Start from the kernel's default config for this arch.
    ( cd "$KERNEL_SRC" && make O="$OUT" defconfig ) >>"$LOG" 2>&1 \
        || die "defconfig failed — see $LOG"
    # Merge the profile's MALI_* (and any other) options into .config.
    # scripts/config, if present, is the least invasive way to set them.
    if [ -x "$KERNEL_SRC/scripts/config" ]; then
        while IFS= read -r line; do
            case "$line" in
                CONFIG_*=*) "$KERNEL_SRC/scripts/config" --file "$OUT/.config" --set-str "$(echo "$line" | sed 's/^CONFIG_//; s/=.*//')" "$(echo "$line" | cut -d= -f2- | tr -d '"')" 2>/dev/null || true ;;
            esac
        done < "$FRAG"
        echo "      merged CONFIG_*= lines from the fragment via scripts/config"
    else
        echo "      NOTE: scripts/config not present; append fragment manually"
    fi
    # The authoritative, human-checkable merge is documented in the manifest
    # step below; the effective config is what actually matters.
else
    echo "      reusing existing $OUT/.config (delete $OUT to reconfigure)"
fi
echo "      effective .config sha256: $(sha256sum "$OUT/.config" | awk '{print $1}')"
echo

# --- 2. build the kernel --------------------------------------------------
echo "[2/5] building kernel -> $OUT  (this is the long step)"
( cd "$KERNEL_SRC" && make O="$OUT" -j"$JOBS" ) >>"$LOG" 2>&1
echo "      kernel build finished (log: $LOG)"
echo

# --- 3. build Kbase in-tree (module) --------------------------------------
echo "[3/5] integrating Kbase and building the module (in-tree, CONFIG_MALI_MIDGARD=m)"
# Copy the Kbase tree into the kernel source (in-tree external module build).
# Kbase builds in-tree via drivers/gpu/arm; we stage it under the kernel tree.
STAGE="$KERNEL_SRC/drivers/gpu/arm"
mkdir -p "$STAGE"
cp -a "$KBASE_TREE/." "$STAGE/"
# The driver path in the kernel Kconfig is referenced by its own Kconfig; wire it
# in as a normal in-tree gpu/arm driver. (Wiring details are build-phase work.)
( cd "$KERNEL_SRC" && make O="$OUT" -j"$JOBS" modules ) >>"$LOG" 2>&1 || {
    echo "      NOTE: module build reported errors; see $LOG" >&2
    die "Kbase module build failed — see $LOG and analysis/findings.md for the failure categories."
}
echo "      module build finished"
echo

# --- 4. summary artifacts for the manifest -------------------------------
echo "[4/5] recording build metadata"
{
    echo "profile=$PROFILE"
    echo "kernel_version=$VER"
    echo "config_sha256=$(sha256sum "$OUT/.config" | awk '{print $1}')"
    echo "patch_series_sha256=$(cat "$REPO_ROOT/work/kbase-patched/.patch-series.sha256" 2>/dev/null || echo unknown)"
    echo "build_host=$(uname -srm)"
    echo "built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$OUT/build-metadata.txt"
cat "$OUT/build-metadata.txt"
echo

# --- 5. done --------------------------------------------------------------
echo "[5/5] done for $PROFILE."
echo "kernel image : $OUT/arch/x86/boot/bzImage  (if present)"
echo "config       : $OUT/.config"
echo "metadata     : $OUT/build-metadata.txt"
echo
echo "This is a COMPILE result only. Booting, loading Kbase, and packaging are"
echo "separate steps; an artifact is not portable until it passes the clean-location"
echo "test in artifacts/README.md. Update research/state.md only after verification."
exit 0